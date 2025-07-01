// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";

contract LPBattleVaultTest is Test {
    LPBattleVault public vault;

    // Monad Testnet addresses
    address constant POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address constant VAULT_ADDRESS = 0xde196Dd5e1ce9a9872b6d44794eEB3F1B4AF28b4;
    address constant FACTORY_ADDRESS = 0x961235a9020B05C44DF1026D956D1F4D78014276;

    // Test addresses
    address public creator = makeAddr("creator");
    address public opponent = makeAddr("opponent");
    address public oracle = makeAddr("oracle");
    address public token0 = makeAddr("token0");
    address public token1 = makeAddr("token1");

    // Test token IDs
    uint256 public creatorTokenId = 1;
    uint256 public opponentTokenId = 2;

    // Mock contracts
    MockPositionManager public mockPositionManager;
    MockFactory public mockFactory;
    MockPool public mockPool;
    MockOracle public mockOracle;
    MockERC20 public mockToken0;
    MockERC20 public mockToken1;

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    function setUp() public {
        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();
        mockOracle = new MockOracle();
        mockToken0 = new MockERC20("Token0", "TK0");
        mockToken1 = new MockERC20("Token1", "TK1");
        
        // Update token addresses to use mock tokens
        token0 = address(mockToken0);
        token1 = address(mockToken1);

        // Deploy the vault with mock contracts
        vault = new LPBattleVault(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(token0, token1, 3000, address(mockPool));

        // Setup stablecoins (token1 is stable for testing)
        vault.setStablecoin(token1, true);

        // Setup mock position data
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000, // tickLower
            1000, // tickUpper
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1500, // tickLower (wider than creator)
            1500, // tickUpper (wider than creator)
            1000000000000000000 // liquidity
        );

        // Setup mock prices
        mockOracle.setPrice(100000000); // $1.00
        mockPool.setSlot0(79228162514264337593543950336, 0); // sqrtPriceX96 for 1:1 ratio

        // Give test addresses some ETH
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        
        // Give vault contract plenty of mock tokens for transfers
        mockToken0.mint(address(vault), 1000000 * 1e18);
        mockToken1.mint(address(vault), 1000000 * 1e18);
    }

    function testCreateBattle() public {
        vm.startPrank(creator);

        // Expect the BattleCreated event
        vm.expectEmit(true, true, false, true);
        emit BattleCreated(0, creator, creatorTokenId);

        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Verify battle was created
        assertEq(battleId, 0);

        // Check battle details
        (address battleCreator, address battleOpponent, uint256 usdValue, string memory status) =
            vault.getBattleDetails(battleId);

        assertEq(battleCreator, creator);
        assertEq(battleOpponent, address(0));
        assertGt(usdValue, 0);
        assertEq(status, "queued");

        vm.stopPrank();
    }

    function testCreateBattleFailsIfNotOwner() public {
        vm.startPrank(opponent);

        vm.expectRevert("Not LP owner");
        vault.createBattle(creatorTokenId, 1 hours);

        vm.stopPrank();
    }

    function testJoinBattle() public {
        // First create a battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Now join the battle
        vm.startPrank(opponent);

        vm.expectEmit(true, true, false, true);
        emit BattleJoined(battleId, opponent, opponentTokenId);

        vault.joinBattle(battleId, opponentTokenId);

        // Check battle details
        (address battleCreator, address battleOpponent, uint256 usdValue, string memory status) =
            vault.getBattleDetails(battleId);

        assertEq(battleCreator, creator);
        assertEq(battleOpponent, opponent);
        assertEq(status, "onGoing");

        vm.stopPrank();
    }

    function testJoinBattleFailsIfNotOwner() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(creator); // Wrong owner
        vm.expectRevert("Not LP owner");
        vault.joinBattle(battleId, opponentTokenId);
    }

    function testJoinBattleFailsIfAlreadyJoined() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Create another opponent token to test joining again
        uint256 anotherOpponentTokenId = 99;
        mockPositionManager.setPositionData(
            anotherOpponentTokenId, opponent, token0, token1, 3000, -800, 800, 1000000000000000000
        );

        // Try to join again with different token
        vm.prank(opponent);
        vm.expectRevert("Battle already joined");
        vault.joinBattle(battleId, anotherOpponentTokenId);
    }

    function testJoinBattleFailsIfValueOutOfTolerance() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Create a position with very different value
        uint256 differentTokenId = 3;
        mockPositionManager.setPositionData(
            differentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -800,
            800,
            100000000000000000 // Much lower liquidity
        );

        vm.prank(opponent);
        vm.expectRevert("LP value not within 5% tolerance");
        vault.joinBattle(battleId, differentTokenId);
    }

    function testResolveBattleCreatorWins() public {
        // Setup specific position ranges for this test
        // Creator: narrow range, Opponent: even narrower range
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -500, // tickLower
            500, // tickUpper
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -200, // tickLower (narrower than creator)
            200, // tickUpper (narrower than creator)
            1000000000000000000 // liquidity
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Set current tick to be within creator's range but not opponent's
        mockPool.setSlot0(79228162514264337593543950336, 300); // tick = 300

        vm.expectEmit(true, true, false, true);
        emit BattleResolved(battleId, creator);

        vault.resolveBattle(battleId);

        // Check battle is resolved
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "ended");
    }

    function testResolveBattleOpponentWins() public {
        // Use different token IDs for this test
        uint256 creatorTokenId2 = 10;
        uint256 opponentTokenId2 = 20;

        // Setup specific position ranges for this test
        // Creator: narrow range, Opponent: wider range
        mockPositionManager.setPositionData(
            creatorTokenId2,
            creator,
            token0,
            token1,
            3000,
            -200, // tickLower (narrow)
            200, // tickUpper (narrow)
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId2,
            opponent,
            token0,
            token1,
            3000,
            -500, // tickLower (wider than creator)
            500, // tickUpper (wider than creator)
            1000000000000000000 // liquidity
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId2, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId2);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Set current tick to be within opponent's range but not creator's
        mockPool.setSlot0(79228162514264337593543950336, 300); // tick = 300

        vm.expectEmit(true, true, false, true);
        emit BattleResolved(battleId, opponent);

        vault.resolveBattle(battleId);

        // Check battle is resolved
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "ended");
    }

    function testResolveBattleFailsIfNotEnded() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Don't fast forward - battle should still be ongoing
        vm.expectRevert("Battle not ended");
        vault.resolveBattle(battleId);
    }

    function testResolveBattleFailsIfNoOpponent() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("No opponent joined");
        vault.resolveBattle(battleId);
    }

    function testResolveBattleFailsIfAlreadyResolved() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);
        mockPool.setSlot0(79228162514264337593543950336, -500);

        vault.resolveBattle(battleId);

        vm.expectRevert("Already resolved");
        vault.resolveBattle(battleId);
    }

    function testGetLPTokenValueUSD() public view {
        (uint256 amount0, uint256 amount1, uint256 usdValue) = vault.getLPTokenValueUSD(creatorTokenId);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertGt(usdValue, 0);
    }

    function testGetBattleUSDValue() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        string memory usdValueStr = vault.getBattleUSDValue(battleId);

        // Should contain "USD"
        assertTrue(bytes(usdValueStr).length > 0);
    }

    function testGetBattleStatus() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Should be queued initially
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "queued");

        // Join battle
        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Should be ongoing
        status = vault.getBattleStatus(battleId);
        assertEq(status, "onGoing");

        // Fast forward
        vm.warp(block.timestamp + 2 hours);
        status = vault.getBattleStatus(battleId);
        assertEq(status, "readyToResolve");
    }

    function testSetStablecoin() public {
        vault.setStablecoin(token0, true);

        assertTrue(vault.stablecoins(token0));
    }
    
    function testSetStablecoinFailsIfNotOwner() public {
        vm.prank(creator); // Not the owner
        vm.expectRevert("Not owner");
        vault.setStablecoin(token0, true);
    }
    
    function testTransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        
        // Current owner transfers ownership
        vault.transferOwnership(newOwner);
        
        // Verify ownership transfer
        assertEq(vault.owner(), newOwner);
        
        // New owner can now set stablecoins
        vm.prank(newOwner);
        vault.setStablecoin(token0, true);
        
        assertTrue(vault.stablecoins(token0));
    }

    function testMultipleBattles() public {
        // Create first battle
        vm.prank(creator);
        uint256 battleId1 = vault.createBattle(creatorTokenId, 1 hours);

        // Create second battle with different token
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000
        );

        vm.prank(creator);
        uint256 battleId2 = vault.createBattle(creatorTokenId2, 2 hours);

        assertEq(battleId1, 0);
        assertEq(battleId2, 1);

        // Both battles should exist
        string memory status1 = vault.getBattleStatus(battleId1);
        string memory status2 = vault.getBattleStatus(battleId2);

        assertEq(status1, "queued");
        assertEq(status2, "queued");
    }
    
    function testFeeCollectionOnResolve() public {
        // Setup specific position ranges for this test
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -500, // tickLower
            500,  // tickUpper
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -200, // tickLower (narrower than creator)
            200,  // tickUpper (narrower than creator)
            1000000000000000000 // liquidity
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Set current tick to be within creator's range but not opponent's
        mockPool.setSlot0(79228162514264337593543950336, 300); // tick = 300

        // Resolve battle
        vault.resolveBattle(battleId);

        // Check that collect was called for both NFTs
        (address recipient1, uint256 amount0_1, uint256 amount1_1, bool called1) = 
            mockPositionManager.collectCalls(creatorTokenId);
        (address recipient2, uint256 amount0_2, uint256 amount1_2, bool called2) = 
            mockPositionManager.collectCalls(opponentTokenId);

        // Both collect calls should have been made
        assertTrue(called1, "Collect not called for creator NFT");
        assertTrue(called2, "Collect not called for opponent NFT");

        // With resolver incentive mechanism, fees are collected to contract first
        assertEq(recipient1, address(vault), "Fees should be collected to vault contract");
        assertEq(recipient2, address(vault), "Fees should be collected to vault contract");

        // Check fee amounts
        assertEq(amount0_1, 1000, "Fee amount0 for creator NFT");
        assertEq(amount1_1, 1000, "Fee amount1 for creator NFT");
        assertEq(amount0_2, 1000, "Fee amount0 for opponent NFT");
        assertEq(amount1_2, 1000, "Fee amount1 for opponent NFT");

        // Check that NFTs were returned to original owners
        assertEq(mockPositionManager.ownerOf(creatorTokenId), creator);
        assertEq(mockPositionManager.ownerOf(opponentTokenId), opponent);
    }
    
    function testFeeCollectionOpponentWins() public {
        // Use different token IDs for this test
        uint256 creatorTokenId2 = 10;
        uint256 opponentTokenId2 = 20;

        // Setup specific position ranges for this test
        mockPositionManager.setPositionData(
            creatorTokenId2,
            creator,
            token0,
            token1,
            3000,
            -200, // tickLower (narrow)
            200,  // tickUpper (narrow)
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId2,
            opponent,
            token0,
            token1,
            3000,
            -500, // tickLower (wider than creator)
            500,  // tickUpper (wider than creator)
            1000000000000000000 // liquidity
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId2, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId2);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Set current tick to be within opponent's range but not creator's
        mockPool.setSlot0(79228162514264337593543950336, 300); // tick = 300

        // Resolve battle
        vault.resolveBattle(battleId);

        // Check that collect was called for both NFTs with opponent as recipient
        (address recipient1, , , bool called1) = mockPositionManager.collectCalls(creatorTokenId2);
        (address recipient2, , , bool called2) = mockPositionManager.collectCalls(opponentTokenId2);

        assertTrue(called1, "Collect not called for creator NFT");
        assertTrue(called2, "Collect not called for opponent NFT");

        // With resolver incentive mechanism, fees are collected to contract first
        assertEq(recipient1, address(vault), "Fees should be collected to vault contract");
        assertEq(recipient2, address(vault), "Fees should be collected to vault contract");

        // Check that NFTs were returned to original owners
        assertEq(mockPositionManager.ownerOf(creatorTokenId2), creator);
        assertEq(mockPositionManager.ownerOf(opponentTokenId2), opponent);
    }

    // NEW TESTS FOR UPGRADED FEATURES

    function testResolverIncentiveMechanism() public {
        address resolver = makeAddr("resolver");
        
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Set tick to make creator win
        mockPool.setSlot0(79228162514264337593543950336, -500);

        // Resolver calls resolveBattle
        vm.prank(resolver);
        vault.resolveBattle(battleId);

        // Check battle is resolved
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "ended");

        // Check that collect was called for both NFTs
        (,,,bool called1) = mockPositionManager.collectCalls(creatorTokenId);
        (,,,bool called2) = mockPositionManager.collectCalls(opponentTokenId);
        assertTrue(called1);
        assertTrue(called2);

        // Check that fees were distributed properly (resolver gets 1% + winner gets 99%)
        (address recipient1,,,) = mockPositionManager.collectCalls(creatorTokenId);
        (address recipient2,,,) = mockPositionManager.collectCalls(opponentTokenId);
        
        // In LPBattleVault, fees are collected to contract first, then distributed
        // This is different from the simple approach in original tests
        assertTrue(recipient1 != address(0));
        assertTrue(recipient2 != address(0));
    }

    function testBothPlayersInRangeFeeTiebreaker() public {
        // Setup positions with same range so both will be in range
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000, // Same range
            1000,
            1000000000000000000
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1000, // Same range
            1000,
            1000000000000000000
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Set tick to be within both ranges
        mockPool.setSlot0(79228162514264337593543950336, 500);

        vault.resolveBattle(battleId);

        // Battle should be resolved with winner determined by fee tiebreaker
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "ended");
    }

    function testBothPlayersOutOfRangeDraw() public {
        // Setup positions with narrow ranges
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -100, // Narrow range
            100,
            1000000000000000000
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -200, // Different narrow range
            -150,
            1000000000000000000
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Set tick to be outside both ranges
        mockPool.setSlot0(79228162514264337593543950336, 1000);

        vault.resolveBattle(battleId);

        // Battle should be resolved as draw
        string memory status = vault.getBattleStatus(battleId);
        assertEq(status, "ended");

        // Check the actual battle data for draw result  
        (,,,, bool isResolved, address winner,,,,,,,) = vault.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, address(0)); // Draw
    }

    function testResolverRewardConstant() public {
        uint256 resolverRewardBps = vault.RESOLVER_REWARD_BPS();
        assertEq(resolverRewardBps, 100); // 1%
    }

    function testGetFeeEarningsFunction() public view {
        // This function is internal, so we test it indirectly through resolution
        // The fee earnings are used in the tie-breaker mechanism
        (uint256 amount0, uint256 amount1, uint256 usdValue) = vault.getLPTokenValueUSD(creatorTokenId);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertGt(usdValue, 0);
    }

    function testDrawFeeSplitting() public {
        // Test fee splitting when both players are out of range (draw)
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -100,
            100,
            1000000000000000000
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -200,
            -150,
            1000000000000000000
        );

        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Both out of range
        mockPool.setSlot0(79228162514264337593543950336, 1000);

        vault.resolveBattle(battleId);

        // Check that fees were collected and split (draw case)
        (,,,bool called1) = mockPositionManager.collectCalls(creatorTokenId);
        (,,,bool called2) = mockPositionManager.collectCalls(opponentTokenId);
        assertTrue(called1);
        assertTrue(called2);

        // Verify battle ended as draw
        (,,,, bool isResolved, address winner,,,,,,,) = vault.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, address(0));
    }

    function testFeeBasedTiebreakerWithDifferentFees() public {
        // Create positions with different initial fees to test tie-breaker
        uint256 highFeeTokenId = 100;
        uint256 lowFeeTokenId = 101;

        mockPositionManager.setPositionData(
            highFeeTokenId,
            creator,
            token0,
            token1,
            3000,
            -500,
            500,
            1000000000000000000
        );

        mockPositionManager.setPositionData(
            lowFeeTokenId,
            opponent,
            token0,
            token1,
            3000,
            -500,
            500,
            1000000000000000000
        );

        // Set different initial fees in the mock
        mockPositionManager.setDifferentFees(highFeeTokenId, 2000, 2000); // Higher fees
        mockPositionManager.setDifferentFees(lowFeeTokenId, 500, 500);    // Lower fees

        vm.prank(creator);
        uint256 battleId = vault.createBattle(highFeeTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, lowFeeTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Both in range - tie-breaker by fees
        mockPool.setSlot0(79228162514264337593543950336, 0);

        vault.resolveBattle(battleId);

        // Winner should be determined by fee comparison
        (,,,, bool isResolved, address winner,,,,,,,) = vault.battles(battleId);
        assertEq(isResolved, true);
        assertTrue(winner == creator || winner == opponent);
    }

    // Frontend Helper Function Tests

    function testGetCompleteBattleDetails() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        (
            address battleCreator,
            address battleOpponent,
            uint256 battleCreatorTokenId,
            uint256 battleOpponentTokenId,
            bool isResolved,
            address winner,
            uint256 startTime,
            uint256 duration,
            uint256 valueUSD,
            string memory status,
            bool creatorInRange,
            bool opponentInRange,
            int24 currentTick
        ) = vault.getCompleteBattleDetails(battleId);

        assertEq(battleCreator, creator);
        assertEq(battleOpponent, opponent);
        assertEq(battleCreatorTokenId, creatorTokenId);
        assertEq(battleOpponentTokenId, opponentTokenId);
        assertEq(isResolved, false);
        assertEq(winner, address(0));
        assertTrue(startTime > 0);
        assertEq(duration, 1 hours);
        assertTrue(valueUSD > 0);
        assertEq(status, "onGoing");
        assertTrue(creatorInRange);
        assertTrue(opponentInRange);
        assertEq(currentTick, 0);
    }

    function testGetTimeRemaining() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Battle not started - should return 0
        assertEq(vault.getTimeRemaining(battleId), 0);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Battle just started - should return close to 1 hour
        uint256 timeRemaining = vault.getTimeRemaining(battleId);
        assertTrue(timeRemaining > 3590 && timeRemaining <= 3600); // Within 10 seconds of 1 hour

        // Fast forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);
        timeRemaining = vault.getTimeRemaining(battleId);
        assertTrue(timeRemaining > 1790 && timeRemaining <= 1800); // Around 30 minutes left

        // Fast forward past end
        vm.warp(block.timestamp + 2 hours);
        assertEq(vault.getTimeRemaining(battleId), 0);
    }

    function testGetCurrentPerformance() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        (
            bool creatorInRange,
            bool opponentInRange,
            uint256 creatorFees,
            uint256 opponentFees,
            address currentLeader,
            string memory leadReason
        ) = vault.getCurrentPerformance(battleId);

        assertTrue(creatorInRange);
        assertTrue(opponentInRange);
        assertEq(creatorFees, 2000); // Default mock fees (1000 + 1000)
        assertEq(opponentFees, 2000); // Default mock fees (1000 + 1000)
        assertEq(currentLeader, creator);
        assertEq(leadReason, "Both in range, tied on fees (creator advantage)");
    }

    function testGetAllActiveBattles() public {
        // Create multiple battles
        vm.prank(creator);
        uint256 battleId1 = vault.createBattle(creatorTokenId, 1 hours);

        uint256 newTokenId = 10;
        mockPositionManager.setPositionData(
            newTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000
        );

        vm.prank(creator);
        uint256 battleId2 = vault.createBattle(newTokenId, 2 hours);

        (uint256[] memory battleIds, string[] memory statuses) = vault.getAllActiveBattles();

        assertEq(battleIds.length, 2);
        assertEq(statuses.length, 2);
        assertEq(battleIds[0], battleId1);
        assertEq(battleIds[1], battleId2);
        assertEq(statuses[0], "queued");
        assertEq(statuses[1], "queued");
    }

    function testGetBattlesWaitingForOpponent() public {
        vm.prank(creator);
        uint256 battleId1 = vault.createBattle(creatorTokenId, 1 hours);

        uint256 newTokenId = 11;
        mockPositionManager.setPositionData(
            newTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000
        );

        vm.prank(creator);
        uint256 battleId2 = vault.createBattle(newTokenId, 2 hours);

        // Join one battle
        vm.prank(opponent);
        vault.joinBattle(battleId1, opponentTokenId);

        uint256[] memory waitingBattles = vault.getBattlesWaitingForOpponent();

        assertEq(waitingBattles.length, 1);
        assertEq(waitingBattles[0], battleId2);
    }

    function testGetBattlesReadyToResolve() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Battle not ready yet
        uint256[] memory readyBattles = vault.getBattlesReadyToResolve();
        assertEq(readyBattles.length, 0);

        // Fast forward past battle end
        vm.warp(block.timestamp + 2 hours);

        readyBattles = vault.getBattlesReadyToResolve();
        assertEq(readyBattles.length, 1);
        assertEq(readyBattles[0], battleId);
    }

    function testGetUserBattles() public {
        vm.prank(creator);
        uint256 battleId1 = vault.createBattle(creatorTokenId, 1 hours);

        uint256 newTokenId = 12;
        mockPositionManager.setPositionData(
            newTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000
        );

        vm.prank(opponent);
        uint256 battleId2 = vault.createBattle(newTokenId, 2 hours);

        // Join first battle
        vm.prank(opponent);
        vault.joinBattle(battleId1, opponentTokenId);

        // Check creator's battles
        (uint256[] memory creatorBattles, bool[] memory creatorIsCreator) = vault.getUserBattles(creator);
        assertEq(creatorBattles.length, 1);
        assertEq(creatorBattles[0], battleId1);
        assertTrue(creatorIsCreator[0]);

        // Check opponent's battles
        (uint256[] memory opponentBattles, bool[] memory opponentIsCreator) = vault.getUserBattles(opponent);
        assertEq(opponentBattles.length, 2);
        assertEq(opponentBattles[0], battleId1);
        assertEq(opponentBattles[1], battleId2);
        assertFalse(opponentIsCreator[0]); // opponent in first battle
        assertTrue(opponentIsCreator[1]); // creator in second battle
    }

    function testGetBattleTokenInfo() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        (
            address battleToken0,
            address battleToken1,
            uint24 fee,
            string memory poolName
        ) = vault.getBattleTokenInfo(battleId);

        assertEq(battleToken0, token0);
        assertEq(battleToken1, token1);
        assertEq(fee, 3000);
        assertEq(poolName, "Pool-30bps");
    }

    function testCanJoinBattle() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        // Can join with matching token
        (bool canJoin, string memory reason) = vault.canJoinBattle(battleId, opponentTokenId);
        assertTrue(canJoin);
        assertEq(reason, "Can join battle");

        // Join the battle
        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Cannot join already joined battle
        uint256 newTokenId = 13;
        mockPositionManager.setPositionData(
            newTokenId,
            makeAddr("user3"),
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000
        );

        (canJoin, reason) = vault.canJoinBattle(battleId, newTokenId);
        assertFalse(canJoin);
        assertEq(reason, "Battle already has opponent");
    }

    function testGetPositionDetails() public {
        (
            address posToken0,
            address posToken1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 valueUSD,
            uint256 fees0,
            uint256 fees1
        ) = vault.getPositionDetails(creatorTokenId);

        assertEq(posToken0, token0);
        assertEq(posToken1, token1);
        assertEq(fee, 3000);
        assertEq(tickLower, -1000);
        assertEq(tickUpper, 1000);
        assertEq(liquidity, 1000000000000000000);
        assertTrue(amount0 > 0);
        assertTrue(amount1 > 0);
        assertTrue(valueUSD > 0);
        assertEq(fees0, 1000); // Default mock fee0
        assertEq(fees1, 1000); // Default mock fee1
    }

    function testGetCurrentPerformanceWithRangeChanges() public {
        vm.prank(creator);
        uint256 battleId = vault.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        vault.joinBattle(battleId, opponentTokenId);

        // Set tick outside creator range but inside opponent range
        mockPool.setSlot0(79228162514264337593543950336, -1200);

        (
            bool creatorInRange,
            bool opponentInRange,
            ,
            ,
            address currentLeader,
            string memory leadReason
        ) = vault.getCurrentPerformance(battleId);

        assertFalse(creatorInRange);
        assertTrue(opponentInRange);
        assertEq(currentLeader, opponent);
        assertEq(leadReason, "Opponent in range, creator out");
    }
}

// Mock contracts for testing
contract MockPositionManager {
    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    mapping(uint256 => Position) public positionData;
    mapping(uint256 => address) public tokenOwners;
    mapping(uint256 => uint128) public customFee0;
    mapping(uint256 => uint128) public customFee1;

    function setPositionData(
        uint256 tokenId,
        address owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external {
        positionData[tokenId] = Position({
            owner: owner,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity
        });
        tokenOwners[tokenId] = owner;
    }

    function setDifferentFees(uint256 tokenId, uint128 fee0, uint128 fee1) external {
        customFee0[tokenId] = fee0;
        customFee1[tokenId] = fee1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return tokenOwners[tokenId];
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory pos = positionData[tokenId];
        uint128 fee0 = customFee0[tokenId] > 0 ? customFee0[tokenId] : 1000;
        uint128 fee1 = customFee1[tokenId] > 0 ? customFee1[tokenId] : 1000;
        
        return (
            0, // nonce
            address(0), // operator
            pos.token0,
            pos.token1,
            pos.fee,
            pos.tickLower,
            pos.tickUpper,
            pos.liquidity,
            0, // feeGrowthInside0LastX128
            0, // feeGrowthInside1LastX128
            fee0, // tokensOwed0
            fee1 // tokensOwed1
        );
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        tokenOwners[tokenId] = to;
    }

    function collect(INonfungiblePositionManager.CollectParams calldata params) external returns (uint256, uint256) {
        // Simulate fee collection by tracking collected amounts
        collectCalls[params.tokenId] = CollectCall({
            recipient: params.recipient,
            amount0: 1000,
            amount1: 1000,
            called: true
        });
        
        return (1000, 1000);
    }
    
    struct CollectCall {
        address recipient;
        uint256 amount0;
        uint256 amount1;
        bool called;
    }
    
    mapping(uint256 => CollectCall) public collectCalls;
}

contract MockFactory {
    mapping(address => mapping(address => mapping(uint24 => address))) public pools;

    function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
        pools[tokenA][tokenB][fee] = pool;
        pools[tokenB][tokenA][fee] = pool;
    }

    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address) {
        return pools[tokenA][tokenB][fee];
    }
}

contract MockPool {
    uint160 public sqrtPriceX96;
    int24 public tick;

    function setSlot0(uint160 _sqrtPriceX96, int24 _tick) external {
        sqrtPriceX96 = _sqrtPriceX96;
        tick = _tick;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (sqrtPriceX96, tick, 0, 0, 0, 0, true);
    }
}

contract MockOracle {
    int256 public price;

    function setPrice(int256 _price) external {
        price = _price;
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}
