// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/interfaces/IShared.sol";

/**
 * @title LiquidArena Edge Case Test Suite
 * @notice Tests for edge cases, boundary conditions, and gas optimization scenarios
 * @dev Comprehensive testing of unusual scenarios and potential attack vectors
 */
contract LiquidArenaEdgeCaseTests is Test {
    // Contracts
    LPBattleVault public rangeVault;
    LPFeeBattle public feeBattle;
    MockPositionManager public mockPositionManager;
    MockFactory public mockFactory;
    MockPool public mockPool;

    // Test accounts
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Test tokens
    MockERC20 public weth;
    MockERC20 public usdc;
    address public WETH;
    address public USDC;

    // Test constants
    uint256 public constant TEST_DURATION = 1 hours;
    uint256 public constant MIN_BATTLE_DURATION = 1 hours;
    uint256 public constant MAX_BATTLE_DURATION = 7 days;
    uint24 public constant POOL_FEE = 3000;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        WETH = address(weth);
        USDC = address(usdc);

        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();

        // Deploy main contracts
        rangeVault = new LPBattleVault(address(mockPositionManager), address(mockFactory));
        feeBattle = new LPFeeBattle(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(WETH, USDC, POOL_FEE, address(mockPool));
        mockPool.setSlot0(1000000000000000000, 0);

        // Setup price feeds (required for battle creation)
        MockPriceFeed ethPriceFeed = new MockPriceFeed(8, 2000e8); // $2000 ETH
        MockPriceFeed usdcPriceFeed = new MockPriceFeed(8, 1e8); // $1 USDC

        rangeVault.setPriceFeed(WETH, address(ethPriceFeed));
        rangeVault.setPriceFeed(USDC, address(usdcPriceFeed));
        feeBattle.setPriceFeed(WETH, address(ethPriceFeed));
        feeBattle.setPriceFeed(USDC, address(usdcPriceFeed));

        // Set stablecoins
        rangeVault.setStablecoin(USDC, true);
        feeBattle.setStablecoin(USDC, true);

        vm.stopPrank();
    }

    // ============ BOUNDARY CONDITION TESTS ============

    function testMinimumBattleDuration() public {
        uint256 tokenId = 1001;
        setupPosition(tokenId, alice);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(tokenId, MIN_BATTLE_DURATION);
        assertEq(battleId, 0);
    }

    function testMaximumBattleDuration() public {
        uint256 tokenId = 1001;
        setupPosition(tokenId, alice);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(tokenId, MAX_BATTLE_DURATION);
        assertEq(battleId, 0);
    }

    function testBattleDurationBoundaries() public {
        uint256 tokenId = 1001;
        setupPosition(tokenId, alice);

        vm.startPrank(alice);

        // Just below minimum should fail
        vm.expectRevert(abi.encodeWithSelector(BattleDurationTooShort.selector, MIN_BATTLE_DURATION - 1, MIN_BATTLE_DURATION));
        rangeVault.createBattle(tokenId, MIN_BATTLE_DURATION - 1);

        // Just above maximum should fail
        vm.expectRevert(abi.encodeWithSelector(BattleDurationTooLong.selector, MAX_BATTLE_DURATION + 1, MAX_BATTLE_DURATION));
        rangeVault.createBattle(tokenId, MAX_BATTLE_DURATION + 1);

        vm.stopPrank();
    }

    // ============ LP VALUE TOLERANCE TESTS ============

    function testLPValueToleranceExactBoundaries() public {
        uint256 aliceTokenId = 1001;
        uint256 bobTokenId = 1002;

        // Alice's position worth 1000 USD
        setupPositionWithValue(aliceTokenId, alice, 1000e8);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(aliceTokenId, TEST_DURATION);

        // Bob's position worth exactly 5% less (950 USD) - should work
        setupPositionWithValue(bobTokenId, bob, 950e8);
        vm.prank(bob);
        rangeVault.joinBattle(battleId, bobTokenId);
    }

    function testLPValueToleranceJustOutsideBoundaries() public {
        uint256 aliceTokenId = 1001;
        uint256 bobTokenId = 1002;
        uint256 charlieTokenId = 1003;

        // Alice's position worth 1000 USD
        setupPositionWithValue(aliceTokenId, alice, 1000e8);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(aliceTokenId, TEST_DURATION);

        // Bob's position worth just over 5% less (949 USD) - should fail
        setupPositionWithValue(bobTokenId, bob, 949e8);
        vm.prank(bob);
        vm.expectRevert(LPValueNotWithinTolerance.selector);
        rangeVault.joinBattle(battleId, bobTokenId);

        // Charlie's position worth just over 5% more (1051 USD) - should fail
        setupPositionWithValue(charlieTokenId, charlie, 1051e8);
        vm.prank(charlie);
        vm.expectRevert(LPValueNotWithinTolerance.selector);
        rangeVault.joinBattle(battleId, charlieTokenId);
    }

    // ============ BATTLE STATE EDGE CASES ============

    function testCannotJoinAlreadyJoinedBattle() public {
        uint256 aliceTokenId = 1001;
        uint256 bobTokenId = 1002;
        uint256 charlieTokenId = 1003;

        setupPosition(aliceTokenId, alice);
        setupPosition(bobTokenId, bob);
        setupPosition(charlieTokenId, charlie);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(aliceTokenId, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, bobTokenId);

        // Charlie tries to join already joined battle
        vm.prank(charlie);
        vm.expectRevert(BattleAlreadyJoined.selector);
        rangeVault.joinBattle(battleId, charlieTokenId);
    }

    function testCannotResolveUnstartedBattle() public {
        uint256 tokenId = 1001;
        setupPosition(tokenId, alice);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(tokenId, TEST_DURATION);

        // Try to resolve battle without opponent
        vm.expectRevert(NoOpponentJoined.selector);
        rangeVault.resolveBattle(battleId);
    }

    function testCannotResolveBeforeBattleEnds() public {
        uint256 aliceTokenId = 1001;
        uint256 bobTokenId = 1002;

        setupPosition(aliceTokenId, alice);
        setupPosition(bobTokenId, bob);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(aliceTokenId, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, bobTokenId);

        // Try to resolve before battle ends
        vm.expectRevert(BattleNotEnded.selector);
        rangeVault.resolveBattle(battleId);
    }

    function testCannotResolveAlreadyResolvedBattle() public {
        uint256 aliceTokenId = 1001;
        uint256 bobTokenId = 1002;

        setupPosition(aliceTokenId, alice);
        setupPosition(bobTokenId, bob);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(aliceTokenId, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, bobTokenId);

        // Fast forward and resolve
        vm.warp(block.timestamp + TEST_DURATION + 1);
        rangeVault.resolveBattle(battleId);

        // Try to resolve again
        vm.expectRevert(AlreadyResolved.selector);
        rangeVault.resolveBattle(battleId);
    }

    // ============ EXTREME VALUE TESTS ============

    function testVeryLargeBattleDuration() public {
        uint256 tokenId = 1001;
        setupPosition(tokenId, alice);

        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(tokenId, MAX_BATTLE_DURATION);

        // Use getCompleteBattleDetails for more detailed info
        (,,,,,, uint256 startTime, uint256 duration,,,,,) = rangeVault.getCompleteBattleDetails(battleId);
        assertEq(duration, MAX_BATTLE_DURATION);
    }

    function testZeroLiquidityPosition() public {
        uint256 tokenId = 1001;

        // Setup position with zero liquidity
        mockPositionManager.setPositionData(
            tokenId,
            alice,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            0, // Zero liquidity
            0,
            0
        );

        vm.prank(alice);
        // Should still work with zero liquidity (edge case)
        uint256 battleId = rangeVault.createBattle(tokenId, TEST_DURATION);
        assertEq(battleId, 0);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function testBatchBattleCreation() public {
        uint256[] memory tokenIds = new uint256[](5);
        address[] memory creators = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = 1001 + i;
            creators[i] = makeAddr(string(abi.encodePacked("creator", i)));
            setupPosition(tokenIds[i], creators[i]);
        }

        uint256 gasStart = gasleft();

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(creators[i]);
            rangeVault.createBattle(tokenIds[i], TEST_DURATION);
        }

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for 5 battle creations:", gasUsed);

        // Verify all battles were created
        for (uint256 i = 0; i < 5; i++) {
            string memory status = rangeVault.getBattleStatus(i);
            assertEq(status, "queued");
        }
    }

    function testLargeScaleBattleResolution() public {
        // Create multiple battles and resolve them
        uint256 numBattles = 3;
        uint256[] memory battleIds = new uint256[](numBattles);

        for (uint256 i = 0; i < numBattles; i++) {
            uint256 creatorTokenId = 1001 + (i * 2);
            uint256 opponentTokenId = 1002 + (i * 2);
            address creator = makeAddr(string(abi.encodePacked("creator", i)));
            address opponent = makeAddr(string(abi.encodePacked("opponent", i)));

            setupPosition(creatorTokenId, creator);
            setupPosition(opponentTokenId, opponent);

            vm.prank(creator);
            battleIds[i] = rangeVault.createBattle(creatorTokenId, TEST_DURATION);

            vm.prank(opponent);
            rangeVault.joinBattle(battleIds[i], opponentTokenId);
        }

        // Fast forward time
        vm.warp(block.timestamp + TEST_DURATION + 1);

        uint256 gasStart = gasleft();

        // Resolve all battles
        for (uint256 i = 0; i < numBattles; i++) {
            rangeVault.resolveBattle(battleIds[i]);
        }

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for", numBattles, "battle resolutions:", gasUsed);

        // Verify all battles were resolved
        for (uint256 i = 0; i < numBattles; i++) {
            string memory status = rangeVault.getBattleStatus(battleIds[i]);
            assertEq(status, "ended");
        }
    }

    // ============ HELPER FUNCTIONS ============

    function setupPosition(uint256 tokenId, address positionOwner) internal {
        mockPositionManager.setPositionData(
            tokenId,
            positionOwner,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            1000000000000000000,
            500,
            1000
        );
    }

    function setupPositionWithValue(uint256 tokenId, address positionOwner, uint256 usdValue) internal {
        // Mock the USD value calculation by setting appropriate liquidity
        mockPositionManager.setPositionData(
            tokenId,
            positionOwner,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            uint128(usdValue / 1e8), // Simplified liquidity calculation
            500,
            1000
        );
    }
}

// Reuse mock contracts from SecurityTests
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}

contract MockPositionManager {
    mapping(uint256 => address) public owners;
    mapping(uint256 => PositionData) public positionData;

    struct PositionData {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

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
        owners[tokenId] = owner;
        positionData[tokenId] = PositionData({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1
        });
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return owners[tokenId];
    }

    function positions(uint256 tokenId) external view returns (
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
    ) {
        PositionData memory pos = positionData[tokenId];
        // Ensure we have valid data
        require(pos.token0 != address(0), "Position does not exist");
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
            pos.tokensOwed0,
            pos.tokensOwed1
        );
    }

    function safeTransferFrom(address, address, uint256) external pure {}

    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        return (params.amount0Max / 2, params.amount1Max / 2);
    }
}

contract MockFactory {
    mapping(bytes32 => address) public pools;

    function setPool(address token0, address token1, uint24 fee, address pool) external {
        bytes32 key = keccak256(abi.encodePacked(token0, token1, fee));
        pools[key] = pool;
    }

    function getPool(address token0, address token1, uint24 fee) external view returns (address) {
        bytes32 key = keccak256(abi.encodePacked(token0, token1, fee));
        return pools[key];
    }
}

contract MockPool {
    uint160 public sqrtPriceX96;
    int24 public tick;

    function setSlot0(uint160 _sqrtPriceX96, int24 _tick) external {
        sqrtPriceX96 = _sqrtPriceX96;
        tick = _tick;
    }

    function slot0() external view returns (
        uint160,
        int24,
        uint16,
        uint16,
        uint16,
        uint8,
        bool
    ) {
        return (sqrtPriceX96, tick, 0, 0, 0, 0, true);
    }
}

contract MockPriceFeed {
    uint8 public decimals;
    int256 public price;
    uint256 public updatedAt;

    constructor(uint8 _decimals, int256 _price) {
        decimals = _decimals;
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, updatedAt, 1);
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }
}
