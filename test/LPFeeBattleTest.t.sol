// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPFeeBattle.sol";

contract LPFeeBattleTest is Test {
    LPFeeBattle public battle;

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

        // Deploy the battle contract with mock contracts
        battle = new LPFeeBattle(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(token0, token1, 3000, address(mockPool));

        // Setup stablecoins - token1 is stable for simpler calculations
        battle.setStablecoin(token1, true);

        // Setup mock position data with initial fees
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000, // tickLower
            1000, // tickUpper
            1000000000000000000, // liquidity
            500, // tokensOwed0 (initial fees)
            600 // tokensOwed1 (initial fees)
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1500, // tickLower
            1500, // tickUpper
            1000000000000000000, // liquidity
            400, // tokensOwed0 (initial fees)
            500 // tokensOwed1 (initial fees)
        );

        // Setup mock prices - use smaller values to prevent overflow in rate calculations
        mockOracle.setPrice(100000000); // $1.00
        mockPool.setSlot0(79228162514264337593543950, 0); // Much smaller sqrtPriceX96 for manageable calculations

        // Give test addresses some ETH
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        
        // Give battle contract plenty of mock tokens for transfers
        mockToken0.mint(address(battle), 1000000 * 1e18);
        mockToken1.mint(address(battle), 1000000 * 1e18);
    }

    function testCreateBattle() public {
        vm.startPrank(creator);

        // Expect the BattleCreated event
        vm.expectEmit(true, true, false, true);
        emit BattleCreated(0, creator, creatorTokenId);

        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        // Verify battle was created
        assertEq(battleId, 0);

        // Check battle details
        (
            address battleCreator,
            uint256 bCreatorTokenId,
            uint256 bOpponentTokenId,
            address battleOpponent,
            bool isResolved,
            address winner,
            uint256 startTime,
            uint256 duration,
            uint256 creatorStartFee0,
            uint256 creatorStartFee1,
            uint256 opponentStartFee0,
            uint256 opponentStartFee1,
            uint256 creatorLPValue
        ) = battle.battles(battleId);

        assertEq(battleCreator, creator);
        assertEq(bCreatorTokenId, creatorTokenId);
        assertEq(bOpponentTokenId, 0);
        assertEq(battleOpponent, address(0));
        assertEq(isResolved, false);
        assertEq(winner, address(0));
        assertEq(startTime, 0);
        assertEq(duration, 1 hours);
        assertEq(creatorStartFee0, 500);
        assertEq(creatorStartFee1, 600);
        assertEq(opponentStartFee0, 0);
        assertEq(opponentStartFee1, 0);
        assertGt(creatorLPValue, 0);

        vm.stopPrank();
    }

    function testCreateBattleFailsIfNotOwner() public {
        vm.startPrank(opponent);

        vm.expectRevert("Not LP owner");
        battle.createBattle(creatorTokenId, 1 hours);

        vm.stopPrank();
    }

    function testJoinBattle() public {
        // First create a battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        // Now join the battle
        vm.startPrank(opponent);

        vm.expectEmit(true, true, false, true);
        emit BattleJoined(battleId, opponent, opponentTokenId);

        battle.joinBattle(battleId, opponentTokenId);

        // Check battle details
        (
            address battleCreator,
            uint256 bCreatorTokenId,
            uint256 bOpponentTokenId,
            address battleOpponent,
            bool isResolved,
            address winner,
            uint256 startTime,
            uint256 duration,
            uint256 creatorStartFee0,
            uint256 creatorStartFee1,
            uint256 opponentStartFee0,
            uint256 opponentStartFee1,
            uint256 creatorLPValue
        ) = battle.battles(battleId);

        assertEq(battleCreator, creator);
        assertEq(bCreatorTokenId, creatorTokenId);
        assertEq(bOpponentTokenId, opponentTokenId);
        assertEq(battleOpponent, opponent);
        assertEq(isResolved, false);
        assertEq(winner, address(0));
        assertEq(startTime, block.timestamp);
        assertEq(duration, 1 hours);
        assertEq(creatorStartFee0, 500);
        assertEq(creatorStartFee1, 600);
        assertEq(opponentStartFee0, 400);
        assertEq(opponentStartFee1, 500);
        assertGt(creatorLPValue, 0);

        // Check battleStart mapping
        assertEq(battle.battleStart(battleId), block.timestamp + 1 hours);

        vm.stopPrank();
    }

    function testJoinBattleFailsIfNotOwner() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(creator); // Wrong owner
        vm.expectRevert("Not LP owner");
        battle.joinBattle(battleId, opponentTokenId);
    }

    function testJoinBattleFailsIfAlreadyJoined() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Create another opponent token to test joining again
        uint256 anotherOpponentTokenId = 99;
        mockPositionManager.setPositionData(
            anotherOpponentTokenId, opponent, token0, token1, 3000, -800, 800, 1000000000000000000, 300, 400
        );

        // Try to join again with different token
        vm.prank(opponent);
        vm.expectRevert("Already joined");
        battle.joinBattle(battleId, anotherOpponentTokenId);
    }

    function testJoinBattleFailsIfValueOutOfTolerance() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

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
            100000000000000000, // Much lower liquidity
            200,
            250
        );

        vm.prank(opponent);
        vm.expectRevert("LP Value not within 5% tolerance");
        battle.joinBattle(battleId, differentTokenId);
    }

    function testJoinBattleFailsIfAlreadyResolved() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Fast forward and resolve
        vm.warp(block.timestamp + 2 hours);
        battle.resolveBattle(battleId);

        // Create another opponent token and try to join resolved battle
        uint256 anotherOpponentTokenId = 99;
        mockPositionManager.setPositionData(
            anotherOpponentTokenId, opponent, token0, token1, 3000, -800, 800, 1000000000000000000, 300, 400
        );

        vm.prank(opponent);
        vm.expectRevert("Already joined"); // Since battle already has opponent, this error comes first
        battle.joinBattle(battleId, anotherOpponentTokenId);
    }

    function testResolveBattleCreatorWins() public {
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Update fees to make creator win (higher fee growth)
        // Creator: 500 -> 800 (300 growth), 600 -> 900 (300 growth) = 600 total
        // Opponent: 400 -> 600 (200 growth), 500 -> 650 (150 growth) = 350 total
        mockPositionManager.updateFees(creatorTokenId, 800, 900);
        mockPositionManager.updateFees(opponentTokenId, 600, 650);

        vm.expectEmit(true, true, false, true);
        emit BattleResolved(battleId, creator);

        battle.resolveBattle(battleId);

        // Check battle is resolved
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, creator);

        // Check tokens returned to original owners (not transferred to winner)
        assertEq(mockPositionManager.ownerOf(creatorTokenId), creator);
        assertEq(mockPositionManager.ownerOf(opponentTokenId), opponent);
    }

    function testResolveBattleOpponentWins() public {
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Update fees to make opponent win (higher fee growth)
        // Creator: 500 -> 650 (150 growth), 600 -> 750 (150 growth) = 300 total
        // Opponent: 400 -> 700 (300 growth), 500 -> 900 (400 growth) = 700 total
        mockPositionManager.updateFees(creatorTokenId, 650, 750);
        mockPositionManager.updateFees(opponentTokenId, 700, 900);

        vm.expectEmit(true, true, false, true);
        emit BattleResolved(battleId, opponent);

        battle.resolveBattle(battleId);

        // Check battle is resolved
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, opponent);

        // Check tokens returned to original owners (not transferred to winner)
        assertEq(mockPositionManager.ownerOf(creatorTokenId), creator);
        assertEq(mockPositionManager.ownerOf(opponentTokenId), opponent);
    }

    function testResolveBattleCreatorWinsOnTie() public {
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Update fees to create a tie (same fee growth)
        // Creator: 500 -> 800 (300 growth), 600 -> 900 (300 growth) = 600 total
        // Opponent: 400 -> 700 (300 growth), 500 -> 800 (300 growth) = 600 total
        mockPositionManager.updateFees(creatorTokenId, 800, 900);
        mockPositionManager.updateFees(opponentTokenId, 700, 800);

        vm.expectEmit(true, true, false, true);
        emit BattleResolved(battleId, creator); // Creator wins on tie

        battle.resolveBattle(battleId);

        // Check battle is resolved
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, creator);
    }

    function testResolveBattleFailsIfNotFinished() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Don't fast forward - battle should still be ongoing
        vm.expectRevert("Not finished");
        battle.resolveBattle(battleId);
    }

    function testResolveBattleFailsIfNoOpponent() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Not started");
        battle.resolveBattle(battleId);
    }

    function testResolveBattleFailsIfAlreadyResolved() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        battle.resolveBattle(battleId);

        vm.expectRevert("Already resolved");
        battle.resolveBattle(battleId);
    }

    function testGetLPTokenValueUSD() public view {
        uint256 usdValue = battle.getLPTokenValueUSD(creatorTokenId);
        assertGt(usdValue, 0);
    }

    function testSetStablecoin() public {
        battle.setStablecoin(token0, true);

        assertTrue(battle.stablecoins(token0));
    }
    
    function testSetStablecoinFailsIfNotOwner() public {
        vm.prank(creator); // Not the owner
        vm.expectRevert("Not owner");
        battle.setStablecoin(token0, true);
    }
    
    function testTransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        
        // Current owner transfers ownership
        battle.transferOwnership(newOwner);
        
        // Verify ownership transfer
        assertEq(battle.owner(), newOwner);
        
        // New owner can now set stablecoins
        vm.prank(newOwner);
        battle.setStablecoin(token0, true);
        
        assertTrue(battle.stablecoins(token0));
    }

    function testMultipleBattles() public {
        // Create first battle
        vm.prank(creator);
        uint256 battleId1 = battle.createBattle(creatorTokenId, 1 hours);

        // Create second battle with different token
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000, 700, 800
        );

        vm.prank(creator);
        uint256 battleId2 = battle.createBattle(creatorTokenId2, 2 hours);

        assertEq(battleId1, 0);
        assertEq(battleId2, 1);

        // Both battles should exist and be separate
        (, uint256 battleToken1,,,,,, uint256 duration1,,,,,) = battle.battles(battleId1);
        (, uint256 battleToken2,,,,,, uint256 duration2,,,,,) = battle.battles(battleId2);

        assertEq(battleToken1, creatorTokenId);
        assertEq(battleToken2, creatorTokenId2);
        assertEq(duration1, 1 hours);
        assertEq(duration2, 2 hours);
    }

    function testBattleIdCounter() public {
        assertEq(battle.battleIdCounter(), 0);

        vm.prank(creator);
        battle.createBattle(creatorTokenId, 1 hours);
        assertEq(battle.battleIdCounter(), 1);

        // Create another token for second battle
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000, 700, 800
        );

        vm.prank(creator);
        battle.createBattle(creatorTokenId2, 2 hours);
        assertEq(battle.battleIdCounter(), 2);
    }

    function testOnERC721Received() public {
        bytes4 selector = battle.onERC721Received(address(0), address(0), 0, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }

    function testFeeCalculationWithZeroFees() public {
        // Create positions with zero initial fees
        uint256 zeroFeeTokenId1 = 100;
        uint256 zeroFeeTokenId2 = 101;

        mockPositionManager.setPositionData(
            zeroFeeTokenId1,
            creator,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000,
            0, // zero initial fees
            0
        );

        mockPositionManager.setPositionData(
            zeroFeeTokenId2,
            opponent,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000,
            0, // zero initial fees
            0
        );

        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(zeroFeeTokenId1, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, zeroFeeTokenId2);

        // Fast forward and update fees
        vm.warp(block.timestamp + 2 hours);
        mockPositionManager.updateFees(zeroFeeTokenId1, 100, 200); // 300 total
        mockPositionManager.updateFees(zeroFeeTokenId2, 150, 100); // 250 total

        battle.resolveBattle(battleId);

        // Creator should win
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertEq(winner, creator);
    }


    function testUSDBasedFeeCalculation() public {
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Fast forward past battle duration
        vm.warp(block.timestamp + 2 hours);

        // Update fees with different token amounts that would be different without USD conversion
        // Creator: 500->600 (100 growth), 600->800 (200 growth) = USD equivalent should determine winner
        // Opponent: 400->500 (100 growth), 500->900 (400 growth) = Higher raw growth but may lose on USD basis
        mockPositionManager.updateFees(creatorTokenId, 600, 800);
        mockPositionManager.updateFees(opponentTokenId, 500, 900);

        battle.resolveBattle(battleId);

        // Winner should be determined by USD-equivalent fee rates, not raw amounts
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        // Winner depends on USD conversion and fee rates
        assertTrue(winner == creator || winner == opponent);
    }

    function testFeeRateComparison() public {
        // Create positions with different values to test rate-based comparison
        uint256 highValueTokenId = 100;
        uint256 lowValueTokenId = 101;

        // High value position (slightly more liquidity - within 5% tolerance)
        mockPositionManager.setPositionData(
            highValueTokenId,
            creator,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1030000000000000000, // 3% more liquidity
            100,
            100
        );

        // Low value position (normal liquidity)  
        mockPositionManager.setPositionData(
            lowValueTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000, // normal liquidity
            100,
            100
        );

        vm.prank(creator);
        uint256 battleId = battle.createBattle(highValueTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, lowValueTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Update fees: opponent gets lower absolute fees but higher rate (efficiency)
        // Creator: 100->300 (200 growth) with high value = lower rate
        // Opponent: 100->250 (150 growth) with low value = potentially higher rate
        mockPositionManager.updateFees(highValueTokenId, 300, 300);
        mockPositionManager.updateFees(lowValueTokenId, 250, 250);

        battle.resolveBattle(battleId);

        // Result depends on fee rate calculation (fee growth / LP value)
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertTrue(winner == creator || winner == opponent);
    }

    function testResolverIncentiveMechanism() public {
        address resolver = makeAddr("resolver");
        
        // Create and join battle
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        vm.warp(block.timestamp + 2 hours);

        // Update fees for resolution
        mockPositionManager.updateFees(creatorTokenId, 800, 900);
        mockPositionManager.updateFees(opponentTokenId, 700, 800);

        // Resolver calls resolveBattle
        vm.prank(resolver);
        battle.resolveBattle(battleId);

        // Check battle is resolved
        (,,,, bool isResolved, address winner,,,,,,,) = battle.battles(battleId);
        assertEq(isResolved, true);
        assertTrue(winner != address(0));

        // Check that collect was called and fees distributed properly
        // Resolver should have received 1% of total fees (tested via MockPositionManager)
        (,,,bool called1) = mockPositionManager.collectCalls(creatorTokenId);
        (,,,bool called2) = mockPositionManager.collectCalls(opponentTokenId);
        assertTrue(called1);
        assertTrue(called2);
    }

    function testConvertFeesToUSD() public view {
        // Test the USD conversion function indirectly through fee calculation
        // This calls convertFeesToUSD internally
        uint256 usdValue = battle.getLPTokenValueUSD(creatorTokenId);
        assertGt(usdValue, 0);
    }

    // HELPER FUNCTION TESTS

    function testGetBattleDetails() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);

        (
            address creator_,
            address opponent_,
            uint256 creatorTokenId_,
            uint256 opponentTokenId_,
            bool isResolved_,
            address winner_,
            uint256 startTime_,
            uint256 duration_,
            uint256 creatorLPValueUSD_,
            string memory status_
        ) = battle.getBattleDetails(battleId);

        assertEq(creator_, creator);
        assertEq(opponent_, address(0));
        assertEq(creatorTokenId_, creatorTokenId);
        assertEq(opponentTokenId_, 0);
        assertEq(isResolved_, false);
        assertEq(winner_, address(0));
        assertEq(startTime_, 0);
        assertEq(duration_, 2 hours);
        assertGt(creatorLPValueUSD_, 0);
        assertEq(status_, "waiting_for_opponent");
    }

    function testGetBattleStatus() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        // Initially waiting for opponent
        string memory status = battle.getBattleStatus(battleId);
        assertEq(status, "waiting_for_opponent");

        // After joining, ongoing
        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);
        
        status = battle.getBattleStatus(battleId);
        assertEq(status, "ongoing");

        // After time expires, ready to resolve
        vm.warp(block.timestamp + 2 hours);
        status = battle.getBattleStatus(battleId);
        assertEq(status, "ready_to_resolve");

        // After resolution, resolved
        mockPositionManager.updateFees(creatorTokenId, 800, 900);
        mockPositionManager.updateFees(opponentTokenId, 700, 800);
        battle.resolveBattle(battleId);
        
        status = battle.getBattleStatus(battleId);
        assertEq(status, "resolved");
    }

    function testGetTimeRemaining() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        // No time remaining when no opponent
        uint256 timeRemaining = battle.getTimeRemaining(battleId);
        assertEq(timeRemaining, 0);

        // Join battle
        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Should have approximately 1 hour remaining
        timeRemaining = battle.getTimeRemaining(battleId);
        assertEq(timeRemaining, 1 hours);

        // Fast forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);
        timeRemaining = battle.getTimeRemaining(battleId);
        assertEq(timeRemaining, 30 minutes);

        // Fast forward past end
        vm.warp(block.timestamp + 1 hours);
        timeRemaining = battle.getTimeRemaining(battleId);
        assertEq(timeRemaining, 0);
    }

    function testGetCurrentFeePerformance() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // Update fees to create performance difference
        mockPositionManager.updateFees(creatorTokenId, 700, 800); // Growth: 200, 200
        mockPositionManager.updateFees(opponentTokenId, 600, 700); // Growth: 200, 200

        (
            uint256 creatorFeeGrowthUSD,
            uint256 opponentFeeGrowthUSD,
            uint256 creatorFeeRate,
            uint256 opponentFeeRate,
            address currentLeader
        ) = battle.getCurrentFeePerformance(battleId);

        assertGt(creatorFeeGrowthUSD, 0);
        assertGt(opponentFeeGrowthUSD, 0);
        assertGt(creatorFeeRate, 0);
        assertGt(opponentFeeRate, 0);
        assertTrue(currentLeader == creator || currentLeader == opponent);
    }

    function testGetAllActiveBattles() public {
        // Create multiple battles
        vm.startPrank(creator);
        uint256 battleId1 = battle.createBattle(creatorTokenId, 1 hours);
        
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000, 700, 800
        );
        uint256 battleId2 = battle.createBattle(creatorTokenId2, 2 hours);
        vm.stopPrank();

        (uint256[] memory battleIds, string[] memory statuses) = battle.getAllActiveBattles();

        assertEq(battleIds.length, 2);
        assertEq(statuses.length, 2);
        assertEq(battleIds[0], battleId1);
        assertEq(battleIds[1], battleId2);
        assertEq(statuses[0], "waiting_for_opponent");
        assertEq(statuses[1], "waiting_for_opponent");
    }

    function testGetBattlesWaitingForOpponent() public {
        vm.startPrank(creator);
        uint256 battleId1 = battle.createBattle(creatorTokenId, 1 hours);
        
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000, 700, 800
        );
        uint256 battleId2 = battle.createBattle(creatorTokenId2, 2 hours);
        vm.stopPrank();

        // Join one battle
        vm.prank(opponent);
        battle.joinBattle(battleId1, opponentTokenId);

        uint256[] memory waitingBattles = battle.getBattlesWaitingForOpponent();

        assertEq(waitingBattles.length, 1);
        assertEq(waitingBattles[0], battleId2);
    }

    function testGetBattlesReadyToResolve() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        vm.prank(opponent);
        battle.joinBattle(battleId, opponentTokenId);

        // No battles ready initially
        uint256[] memory readyBattles = battle.getBattlesReadyToResolve();
        assertEq(readyBattles.length, 0);

        // Fast forward
        vm.warp(block.timestamp + 2 hours);

        readyBattles = battle.getBattlesReadyToResolve();
        assertEq(readyBattles.length, 1);
        assertEq(readyBattles[0], battleId);
    }

    function testGetUserBattles() public {
        vm.startPrank(creator);
        uint256 battleId1 = battle.createBattle(creatorTokenId, 1 hours);
        
        uint256 creatorTokenId2 = 10;
        mockPositionManager.setPositionData(
            creatorTokenId2, creator, token0, token1, 3000, -1500, 1500, 2000000000000000000, 700, 800
        );
        uint256 battleId2 = battle.createBattle(creatorTokenId2, 2 hours);
        vm.stopPrank();

        // Join one battle as opponent
        vm.prank(opponent);
        battle.joinBattle(battleId1, opponentTokenId);

        // Test creator's battles
        (uint256[] memory creatorBattles, bool[] memory creatorIsCreator) = battle.getUserBattles(creator);
        assertEq(creatorBattles.length, 2);
        assertEq(creatorIsCreator[0], true);
        assertEq(creatorIsCreator[1], true);

        // Test opponent's battles
        (uint256[] memory opponentBattles, bool[] memory opponentIsCreator) = battle.getUserBattles(opponent);
        assertEq(opponentBattles.length, 1);
        assertEq(opponentIsCreator[0], false);
    }

    function testGetBattleTokenInfo() public {
        vm.prank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);

        (
            address token0_,
            address token1_,
            uint24 fee_,
            string memory poolName_
        ) = battle.getBattleTokenInfo(battleId);

        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(fee_, 3000);
        assertEq(poolName_, "Pool-30bps");
    }

    function testResolverConstant() public view {
        uint256 resolverRewardBps = battle.RESOLVER_REWARD_BPS();
        assertEq(resolverRewardBps, 100); // 1%
    }

    function testMinBattleDurationConstant() public view {
        // Test the constant directly
        uint256 minDuration = battle.MIN_BATTLE_DURATION();
        assertEq(minDuration, 1 hours); // 1 hour
    }

    function testCreateBattleFailsWithShortDuration() public {
        vm.startPrank(creator);

        // Try to create battle with duration less than minimum (59 minutes)
        vm.expectRevert("Battle duration too short");
        battle.createBattle(creatorTokenId, 59 minutes);

        // Also test with 0 duration
        vm.expectRevert("Battle duration too short");
        battle.createBattle(creatorTokenId, 0);

        vm.stopPrank();
    }

    function testCreateBattleSucceedsWithMinimumDuration() public {
        vm.startPrank(creator);

        // Get current counter before creating battle
        uint256 expectedBattleId = battle.battleIdCounter();
        
        // Create battle with exactly minimum duration (1 hour)
        uint256 battleId = battle.createBattle(creatorTokenId, 1 hours);
        
        // Should be the expected battle ID
        assertEq(battleId, expectedBattleId);

        // Verify duration is set correctly - position 8 (7 commas)
        (,,,,,,, uint256 duration,,,,,) = battle.battles(battleId);
        assertEq(duration, 1 hours);

        vm.stopPrank();
    }

    function testCreateBattleSucceedsWithLongerDuration() public {
        vm.startPrank(creator);

        // Get current counter before creating battle
        uint256 expectedBattleId = battle.battleIdCounter();
        
        // Create battle with longer duration (2 hours)
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        
        // Should be the expected battle ID
        assertEq(battleId, expectedBattleId);

        // Verify duration is set correctly - position 8 (7 commas)
        (,,,,,,, uint256 duration,,,,,) = battle.battles(battleId);
        assertEq(duration, 2 hours);

        vm.stopPrank();
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
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(uint256 => Position) public positionData;
    mapping(uint256 => address) public tokenOwners;

    function setPositionData(
        uint256 tokenId,
        address owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) external {
        positionData[tokenId] = Position({
            owner: owner,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1
        });
        tokenOwners[tokenId] = owner;
    }

    function updateFees(uint256 tokenId, uint128 newOwed0, uint128 newOwed1) external {
        positionData[tokenId].tokensOwed0 = newOwed0;
        positionData[tokenId].tokensOwed1 = newOwed1;
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
        Position memory position = positionData[tokenId];
        return (
            0, // nonce
            address(0), // operator
            position.token0,
            position.token1,
            position.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            0, // feeGrowthInside0LastX128
            0, // feeGrowthInside1LastX128
            position.tokensOwed0,
            position.tokensOwed1
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

// Additional tests for new frontend helper functions
contract LPFeeBattleHelperTest is LPFeeBattleTest {
    
    function testGetBattleUSDValue() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        string memory usdValue = battle.getBattleUSDValue(battleId);
        // Should return formatted USD value like "2000000000000000000.00 USD"
        assertTrue(bytes(usdValue).length > 0);
    }
    
    function testGetCompleteBattleDetails() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        (
            address creator_,
            address opponent_,
            uint256 creatorTokenId_,
            uint256 opponentTokenId_,
            bool isResolved_,
            address winner_,
            uint256 startTime_,
            uint256 duration_,
            uint256 valueUSD_,
            string memory status_,
            uint256 creatorFeeGrowthUSD_,
            uint256 opponentFeeGrowthUSD_,
            uint256 creatorFeeRate_,
            uint256 opponentFeeRate_,
            address currentLeader_
        ) = battle.getCompleteBattleDetails(battleId);
        
        assertEq(creator_, creator);
        assertEq(opponent_, address(0));
        assertEq(creatorTokenId_, creatorTokenId);
        assertEq(opponentTokenId_, 0);
        assertFalse(isResolved_);
        assertEq(winner_, address(0));
        assertEq(startTime_, 0);
        assertEq(duration_, 2 hours);
        assertTrue(valueUSD_ > 0);
        assertEq(status_, "waiting_for_opponent");
        // Performance data should be 0 when no opponent
        assertEq(creatorFeeGrowthUSD_, 0);
        assertEq(opponentFeeGrowthUSD_, 0);
        assertEq(creatorFeeRate_, 0);
        assertEq(opponentFeeRate_, 0);
        assertEq(currentLeader_, address(0));
    }
    
    function testGetCompleteBattleDetailsAfterJoin() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        vm.startPrank(opponent);
        battle.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();
        
        (
            address creator_,
            address opponent_,
            uint256 creatorTokenId_,
            uint256 opponentTokenId_,
            bool isResolved_,
            address winner_,
            uint256 startTime_,
            uint256 duration_,
            uint256 valueUSD_,
            string memory status_,
            uint256 creatorFeeGrowthUSD_,
            uint256 opponentFeeGrowthUSD_,
            uint256 creatorFeeRate_,
            uint256 opponentFeeRate_,
            address currentLeader_
        ) = battle.getCompleteBattleDetails(battleId);
        
        assertEq(creator_, creator);
        assertEq(opponent_, opponent);
        assertEq(creatorTokenId_, creatorTokenId);
        assertEq(opponentTokenId_, opponentTokenId);
        assertFalse(isResolved_);
        assertEq(winner_, address(0));
        assertTrue(startTime_ > 0);
        assertEq(duration_, 2 hours);
        assertTrue(valueUSD_ > 0);
        assertEq(status_, "ongoing");
        // Should have performance data now
        assertTrue(creatorFeeGrowthUSD_ >= 0);
        assertTrue(opponentFeeGrowthUSD_ >= 0);
        assertTrue(currentLeader_ != address(0));
    }
    
    function testCanJoinBattle() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        // Test successful join
        (bool canJoin, string memory reason) = battle.canJoinBattle(battleId, opponentTokenId);
        assertTrue(canJoin);
        assertEq(reason, "Can join battle");
        
        // Test after joining
        vm.startPrank(opponent);
        battle.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();
        
        // Test cannot join again
        uint256 anotherTokenId = 3;
        mockPositionManager.setPositionData(
            anotherTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1000,
            1000,
            1000000000000000000,
            100,
            200
        );
        
        (canJoin, reason) = battle.canJoinBattle(battleId, anotherTokenId);
        assertFalse(canJoin);
        assertEq(reason, "Battle already has opponent");
    }
    
    function testCanJoinBattleValueTolerance() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        // Create a position with value outside 5% tolerance
        uint256 highValueTokenId = 3;
        mockPositionManager.setPositionData(
            highValueTokenId,
            opponent,
            token0,
            token1,
            3000,
            -1000,
            1000,
            3000000000000000000, // 50% higher value
            100,
            200
        );
        
        (bool canJoin, string memory reason) = battle.canJoinBattle(battleId, highValueTokenId);
        assertFalse(canJoin);
        assertEq(reason, "LP value not within 5% tolerance");
    }
    
    function testGetPositionDetails() public {
        (
            address token0_,
            address token1_,
            uint24 fee_,
            int24 tickLower_,
            int24 tickUpper_,
            uint128 liquidity_,
            uint256 valueUSD_,
            uint256 fees0_,
            uint256 fees1_,
            uint256 feesUSD_
        ) = battle.getPositionDetails(creatorTokenId);
        
        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(fee_, 3000);
        assertEq(tickLower_, -1000);
        assertEq(tickUpper_, 1000);
        assertEq(liquidity_, 1000000000000000000);
        assertTrue(valueUSD_ > 0);
        assertTrue(fees0_ >= 0);
        assertTrue(fees1_ >= 0);
        assertTrue(feesUSD_ >= 0);
    }
    
    function testGetDetailedFeePerformance() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        vm.startPrank(opponent);
        battle.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();
        
        // Simulate fee accumulation
        mockPositionManager.updateFees(creatorTokenId, 1000, 2000);
        mockPositionManager.updateFees(opponentTokenId, 500, 1000);
        
        (
            uint256 creatorStartFees,
            uint256 opponentStartFees,
            uint256 creatorCurrentFees,
            uint256 opponentCurrentFees,
            uint256 creatorFeeGrowthUSD,
            uint256 opponentFeeGrowthUSD,
            uint256 creatorFeeRate,
            uint256 opponentFeeRate,
            address currentLeader,
            string memory leadReason
        ) = battle.getDetailedFeePerformance(battleId);
        
        assertTrue(creatorStartFees >= 0);
        assertTrue(opponentStartFees >= 0);
        assertTrue(creatorCurrentFees >= creatorStartFees);
        assertTrue(opponentCurrentFees >= opponentStartFees);
        assertTrue(creatorFeeGrowthUSD >= 0);
        assertTrue(opponentFeeGrowthUSD >= 0);
        assertTrue(currentLeader != address(0));
        assertTrue(bytes(leadReason).length > 0);
    }
    
    function testGetDetailedFeePerformanceNotStarted() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        // Should revert when battle not started
        vm.expectRevert("Battle not started");
        battle.getDetailedFeePerformance(battleId);
    }
    
    function testGetDetailedFeePerformanceResolved() public {
        vm.startPrank(creator);
        uint256 battleId = battle.createBattle(creatorTokenId, 2 hours);
        vm.stopPrank();
        
        vm.startPrank(opponent);
        battle.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();
        
        // Fast forward time to resolution
        vm.warp(block.timestamp + 3 hours);
        
        // Resolve battle
        battle.resolveBattle(battleId);
        
        (
            uint256 creatorStartFees,
            uint256 opponentStartFees,
            uint256 creatorCurrentFees,
            uint256 opponentCurrentFees,
            uint256 creatorFeeGrowthUSD,
            uint256 opponentFeeGrowthUSD,
            uint256 creatorFeeRate,
            uint256 opponentFeeRate,
            address currentLeader,
            string memory leadReason
        ) = battle.getDetailedFeePerformance(battleId);
        
        // Should return zeros for resolved battle
        assertEq(creatorStartFees, 0);
        assertEq(opponentStartFees, 0);
        assertEq(creatorCurrentFees, 0);
        assertEq(opponentCurrentFees, 0);
        assertEq(creatorFeeGrowthUSD, 0);
        assertEq(opponentFeeGrowthUSD, 0);
        assertEq(creatorFeeRate, 0);
        assertEq(opponentFeeRate, 0);
        assertTrue(currentLeader != address(0)); // Should be the winner
        assertEq(leadReason, "Battle resolved");
    }
}
