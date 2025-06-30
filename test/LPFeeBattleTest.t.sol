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

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    function setUp() public {
        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();
        mockOracle = new MockOracle();

        // Deploy the battle contract with mock contracts
        battle = new LPFeeBattle(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(token0, token1, 3000, address(mockPool));

        // Setup oracles
        battle.setOracle(token0, address(mockOracle));
        battle.setOracle(token1, address(mockOracle));

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

        // Check tokens transferred to winner
        assertEq(mockPositionManager.ownerOf(creatorTokenId), creator);
        assertEq(mockPositionManager.ownerOf(opponentTokenId), creator);
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

        // Check tokens transferred to winner
        assertEq(mockPositionManager.ownerOf(creatorTokenId), opponent);
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

    function testSetOracle() public {
        address newOracle = makeAddr("newOracle");
        battle.setOracle(token0, newOracle);

        assertEq(battle.usdOracles(token0), newOracle);
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
