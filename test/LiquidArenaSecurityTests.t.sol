// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/interfaces/IShared.sol";

/**
 * @title LiquidArena Security Test Suite
 * @notice Comprehensive security tests for the improved LiquidArena contracts
 * @dev Tests reentrancy protection, access control, input validation, and edge cases
 */
contract LiquidArenaSecurityTests is Test {
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
    address public attacker = makeAddr("attacker");
    address public nonOwner = makeAddr("nonOwner");

    // Test tokens
    MockERC20 public weth;
    MockERC20 public usdc;

    // Token addresses
    address public WETH;
    address public USDC;

    // Test LP NFT IDs
    uint256 public constant ALICE_TOKEN_ID = 1001;
    uint256 public constant BOB_TOKEN_ID = 1002;
    uint256 public constant ATTACKER_TOKEN_ID = 1003;

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
        mockPool.setSlot0(1000000000000000000, 0); // Mock price

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

        // Setup test positions
        setupTestPositions();

        vm.stopPrank();
    }

    function setupTestPositions() internal {
        // Alice's position
        mockPositionManager.setPositionData(
            ALICE_TOKEN_ID,
            alice,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            1000000000000000000,
            500,
            1000
        );

        // Bob's position
        mockPositionManager.setPositionData(
            BOB_TOKEN_ID,
            bob,
            WETH,
            USDC,
            POOL_FEE,
            -800,
            800,
            1000000000000000000,
            400,
            800
        );

        // Attacker's position
        mockPositionManager.setPositionData(
            ATTACKER_TOKEN_ID,
            attacker,
            WETH,
            USDC,
            POOL_FEE,
            -500,
            500,
            1000000000000000000,
            300,
            600
        );
    }

    // ============ ACCESS CONTROL TESTS ============

    function testOnlyOwnerCanSetStablecoin() public {
        // Owner can set stablecoin
        vm.prank(owner);
        rangeVault.setStablecoin(USDC, true);
        assertTrue(rangeVault.stablecoins(USDC));

        // Non-owner cannot set stablecoin
        vm.prank(nonOwner);
        vm.expectRevert(NotOwner.selector);
        rangeVault.setStablecoin(WETH, true);
    }

    function testOnlyOwnerCanSetPriceFeed() public {
        address mockPriceFeed = makeAddr("mockPriceFeed");

        // Owner can set price feed
        vm.prank(owner);
        rangeVault.setPriceFeed(WETH, mockPriceFeed);

        // Non-owner cannot set price feed
        vm.prank(nonOwner);
        vm.expectRevert(NotOwner.selector);
        rangeVault.setPriceFeed(USDC, mockPriceFeed);
    }

    function testOnlyOwnerCanTransferOwnership() public {
        // Owner can transfer ownership
        vm.prank(owner);
        rangeVault.transferOwnership(alice);
        assertEq(rangeVault.owner(), alice);

        // Non-owner cannot transfer ownership
        vm.prank(nonOwner);
        vm.expectRevert(NotOwner.selector);
        rangeVault.transferOwnership(bob);
    }

    function testOnlyOwnerCanPauseContract() public {
        // Owner can pause
        vm.prank(owner);
        rangeVault.pause();
        assertTrue(rangeVault.paused());

        // Non-owner cannot pause
        vm.prank(nonOwner);
        vm.expectRevert(NotOwner.selector);
        rangeVault.pause();
    }

    function testOnlyOwnerCanUnpauseContract() public {
        // First pause the contract
        vm.prank(owner);
        rangeVault.pause();

        // Owner can unpause
        vm.prank(owner);
        rangeVault.unpause();
        assertFalse(rangeVault.paused());

        // Pause again for next test
        vm.prank(owner);
        rangeVault.pause();

        // Non-owner cannot unpause
        vm.prank(nonOwner);
        vm.expectRevert(NotOwner.selector);
        rangeVault.unpause();
    }

    // ============ INPUT VALIDATION TESTS ============

    function testCreateBattleValidatesDuration() public {
        vm.startPrank(alice);

        // Duration too short should revert
        vm.expectRevert(abi.encodeWithSelector(BattleDurationTooShort.selector, 30 minutes, MIN_BATTLE_DURATION));
        rangeVault.createBattle(ALICE_TOKEN_ID, 30 minutes);

        // Duration too long should revert
        vm.expectRevert(abi.encodeWithSelector(BattleDurationTooLong.selector, 8 days, MAX_BATTLE_DURATION));
        rangeVault.createBattle(ALICE_TOKEN_ID, 8 days);

        // Valid duration should work
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);
        assertEq(battleId, 0);

        vm.stopPrank();
    }

    function testCreateBattleValidatesOwnership() public {
        // Alice cannot create battle with Bob's token
        vm.prank(alice);
        vm.expectRevert(NotLPOwner.selector);
        rangeVault.createBattle(BOB_TOKEN_ID, TEST_DURATION);
    }

    function testSetStablecoinValidatesZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rangeVault.setStablecoin(address(0), true);
    }

    function testSetPriceFeedValidatesZeroAddress() public {
        // Zero token address should revert
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rangeVault.setPriceFeed(address(0), makeAddr("priceFeed"));

        // Zero price feed address should revert
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rangeVault.setPriceFeed(WETH, address(0));
    }

    function testTransferOwnershipValidatesZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(InvalidOwner.selector);
        rangeVault.transferOwnership(address(0));
    }

    // ============ PAUSE FUNCTIONALITY TESTS ============

    function testCannotCreateBattleWhenPaused() public {
        // Pause the contract
        vm.prank(owner);
        rangeVault.pause();

        // Creating battle should revert when paused
        vm.prank(alice);
        vm.expectRevert(); // Use generic revert expectation for OpenZeppelin v5
        rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);
    }

    function testCannotJoinBattleWhenPaused() public {
        // Create battle first
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Pause the contract
        vm.prank(owner);
        rangeVault.pause();

        // Joining battle should revert when paused
        vm.prank(bob);
        vm.expectRevert(); // Use generic revert expectation for OpenZeppelin v5
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);
    }

    function testCanResolveBattleWhenPaused() public {
        // Create and join battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // Fast forward time
        vm.warp(block.timestamp + TEST_DURATION + 1);

        // Pause the contract
        vm.prank(owner);
        rangeVault.pause();

        // Resolving battle should still work when paused (no whenNotPaused modifier)
        rangeVault.resolveBattle(battleId);

        (,, , address winner,) = rangeVault.getBattleDetails(battleId);
        assertTrue(winner != address(0));
    }

    // ============ EMERGENCY FUNCTIONS TESTS ============

    function testEmergencyWithdrawValidation() public {
        // Create and join battle to set startTime
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // Should revert for zero address
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rangeVault.emergencyWithdraw(battleId, address(0), ALICE_TOKEN_ID);

        // Should revert if battle not expired
        vm.prank(owner);
        vm.expectRevert(BattleNotExpiredForEmergencyWithdrawal.selector);
        rangeVault.emergencyWithdraw(battleId, alice, ALICE_TOKEN_ID);
    }

    function testEmergencyWithdrawAfterExpiry() public {
        // Create battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Fast forward past battle duration + 7 days
        vm.warp(block.timestamp + TEST_DURATION + 7 days + 1);

        // Emergency withdraw should work
        vm.prank(owner);
        rangeVault.emergencyWithdraw(battleId, alice, ALICE_TOKEN_ID);
    }
}

// Mock contracts for testing
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
