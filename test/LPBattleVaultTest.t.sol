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

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    function setUp() public {
        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();
        mockOracle = new MockOracle();

        // Deploy the vault with mock contracts
        vault = new LPBattleVault(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(token0, token1, 3000, address(mockPool));

        // Setup oracles
        vault.setOracle(token0, address(mockOracle));
        vault.setOracle(token1, address(mockOracle));

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

    function testSetOracle() public {
        address newOracle = makeAddr("newOracle");
        vault.setOracle(token0, newOracle);

        assertEq(vault.usdOracles(token0), newOracle);
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
            1000, // tokensOwed0
            1000 // tokensOwed1
        );
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        tokenOwners[tokenId] = to;
    }

    function collect(INonfungiblePositionManager.CollectParams calldata params) external returns (uint256, uint256) {
        return (1000, 1000);
    }
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
