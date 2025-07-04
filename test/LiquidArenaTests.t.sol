// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/interfaces/IShared.sol";

/**
 * @title LiquidArena Comprehensive Test Suite
 * @notice Tests for both LPBattleVault (Range Battles) and LPFeeBattle (Fee Battles)
 * @dev Uses mock contracts to simulate Uniswap V3 interactions
 */
contract LiquidArenaTests is Test {
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
    address public resolver = makeAddr("resolver");

    // Test tokens (will be deployed as mock ERC20s)
    MockERC20 public weth;
    MockERC20 public usdc;
    MockERC20 public wbtc;
    MockERC20 public usdt;

    // Token addresses for easy reference
    address public WETH;
    address public USDC;
    address public WBTC;
    address public USDT;

    // Test LP NFT IDs
    uint256 public constant ALICE_TOKEN_ID = 1001;
    uint256 public constant BOB_TOKEN_ID = 1002;
    uint256 public constant CHARLIE_TOKEN_ID = 1003;

    // Test constants
    uint256 public constant TEST_DURATION = 1 hours;
    uint256 public constant MIN_BATTLE_DURATION = 1 hours;
    uint24 public constant POOL_FEE = 3000; // 0.3%

    // Events to test
    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy mock ERC20 tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        usdt = new MockERC20("Tether USD", "USDT", 6);

        // Set addresses for easy reference
        WETH = address(weth);
        USDC = address(usdc);
        WBTC = address(wbtc);
        USDT = address(usdt);

        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();

        // Deploy main contracts
        rangeVault = new LPBattleVault(address(mockPositionManager), address(mockFactory));
        feeBattle = new LPFeeBattle(address(mockPositionManager), address(mockFactory));

        // Setup mock price feeds to avoid StalePrice errors
        setupMockPriceFeeds();

        // Setup mock pool in factory
        mockFactory.setPool(WETH, USDC, POOL_FEE, address(mockPool));

        // Setup test LP positions
        setupTestPositions();

        vm.stopPrank();
    }

    function setupTestPositions() internal {
        // Alice's position: WETH/USDC, in range
        mockPositionManager.setPositionData(
            ALICE_TOKEN_ID,
            alice,
            WETH,
            USDC,
            POOL_FEE,
            -1000, // tickLower
            1000,  // tickUpper
            1000000000000000000, // 1 ETH worth of liquidity
            500,   // fees0
            1000   // fees1
        );

        // Bob's position: WETH/USDC, similar value (within 5% tolerance)
        mockPositionManager.setPositionData(
            BOB_TOKEN_ID,
            bob,
            WETH,
            USDC,
            POOL_FEE,
            -800,  // tickLower
            800,   // tickUpper
            980000000000000000, // 0.98 ETH worth (within 5% tolerance: 2% difference)
            300,   // fees0
            800    // fees1
        );

        // Charlie's position: WETH/USDC, different value (outside tolerance)
        mockPositionManager.setPositionData(
            CHARLIE_TOKEN_ID,
            charlie,
            WETH,
            USDC,
            POOL_FEE,
            -1200, // tickLower
            1200,  // tickUpper
            1600000000000000000, // 1.6 ETH worth (outside 5% tolerance)
            200,   // fees0
            400    // fees1
        );

        // Set current pool price (tick = 0, price = 1:1)
        mockPool.setSlot0(79228162514264337593543950336, 0); // sqrtPriceX96 for 1:1 ratio
    }

    function setupMockPriceFeeds() internal {
        // Deploy mock price feeds
        MockPriceFeed ethFeed = new MockPriceFeed(2000 * 1e8); // $2000 ETH
        MockPriceFeed btcFeed = new MockPriceFeed(50000 * 1e8); // $50000 BTC
        MockPriceFeed usdcFeed = new MockPriceFeed(1 * 1e8); // $1 USDC
        MockPriceFeed usdtFeed = new MockPriceFeed(1 * 1e8); // $1 USDT

        // Set price feeds in both contracts (as owner)
        rangeVault.setPriceFeed(WETH, address(ethFeed));
        rangeVault.setPriceFeed(WBTC, address(btcFeed));
        rangeVault.setPriceFeed(USDC, address(usdcFeed));
        rangeVault.setPriceFeed(USDT, address(usdtFeed));

        feeBattle.setPriceFeed(WETH, address(ethFeed));
        feeBattle.setPriceFeed(WBTC, address(btcFeed));
        feeBattle.setPriceFeed(USDC, address(usdcFeed));
        feeBattle.setPriceFeed(USDT, address(usdtFeed));

        // Set stablecoins (as owner)
        rangeVault.setStablecoin(USDC, true);
        rangeVault.setStablecoin(USDT, true);
        feeBattle.setStablecoin(USDC, true);
        feeBattle.setStablecoin(USDT, true);

        // Mint tokens to battle contracts so they can transfer fees
        weth.mint(address(rangeVault), 1000 * 1e18);
        usdc.mint(address(rangeVault), 1000000 * 1e6);
        wbtc.mint(address(rangeVault), 10 * 1e8);
        usdt.mint(address(rangeVault), 1000000 * 1e6);

        weth.mint(address(feeBattle), 1000 * 1e18);
        usdc.mint(address(feeBattle), 1000000 * 1e6);
        wbtc.mint(address(feeBattle), 10 * 1e8);
        usdt.mint(address(feeBattle), 1000000 * 1e6);
    }

    // ============ RANGE BATTLE TESTS ============

    function testRangeBattle_CreateBattle() public {
        vm.startPrank(alice);

        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Verify battle was created
        assertEq(battleId, 0);

        // Check battle details using helper function
        (address creator, address opponent, uint256 usdValue, address winner, string memory status) =
            rangeVault.getBattleDetails(battleId);

        assertEq(creator, alice);
        assertEq(opponent, address(0));
        assertEq(winner, address(0));
        assertGt(usdValue, 0);
        assertEq(status, "queued");

        vm.stopPrank();
    }

    function testRangeBattle_JoinBattle() public {
        // Alice creates battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Bob joins battle
        vm.startPrank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // Check battle details after joining
        (address creator, address opponent, uint256 usdValue, address winner, string memory status) =
            rangeVault.getBattleDetails(battleId);

        assertEq(creator, alice);
        assertEq(opponent, bob);
        assertEq(winner, address(0));
        assertEq(status, "onGoing");

        vm.stopPrank();
    }

    function testRangeBattle_CannotJoinWithIncompatibleValue() public {
        // Alice creates battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Charlie tries to join with incompatible LP value
        vm.prank(charlie);
        vm.expectRevert(LPValueNotWithinTolerance.selector);
        rangeVault.joinBattle(battleId, CHARLIE_TOKEN_ID);
    }

    function testRangeBattle_CanJoinBattleHelper() public {
        // Alice creates battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Check if Bob can join (should be true)
        (bool canJoin, string memory reason) = rangeVault.canJoinBattle(battleId, BOB_TOKEN_ID);
        assertTrue(canJoin);
        assertTrue(bytes(reason).length > 0); // Just check that reason is provided

        // Check if Charlie can join (should be false)
        (bool canJoinCharlie, string memory reasonCharlie) = rangeVault.canJoinBattle(battleId, CHARLIE_TOKEN_ID);
        assertFalse(canJoinCharlie);
        assertTrue(bytes(reasonCharlie).length > 0); // Just check that reason is provided
    }

    function testRangeBattle_ResolveBattleWhenBothInRange() public {
        // Create and join battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // Fast forward past battle duration
        vm.warp(block.timestamp + TEST_DURATION + 1);

        // Both positions should be in range (current tick = 0, both ranges include 0)
        // Alice should win due to higher fees (500+1000=1500 vs 300+800=1100)
        vm.prank(resolver);
        rangeVault.resolveBattle(battleId);

        // Check final battle state
        (,, , address winner, string memory status) = rangeVault.getBattleDetails(battleId);
        assertEq(winner, alice);
        assertEq(status, "ended");
    }

    function testRangeBattle_ResolveBattleWhenOneOutOfRange() public {
        // Create and join battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // Move price outside Bob's range but inside Alice's range
        // Bob's range: [-800, 800], Alice's range: [-1000, 1000]
        // Set tick to 900 (outside Bob's range, inside Alice's range)
        mockPool.setSlot0(79228162514264337593543950336, 900);

        // Fast forward past battle duration
        vm.warp(block.timestamp + TEST_DURATION + 1);

        vm.prank(resolver);
        rangeVault.resolveBattle(battleId);

        // Alice should win because Bob is out of range
        (,, , address winner, string memory status) = rangeVault.getBattleDetails(battleId);
        assertEq(winner, alice);
        assertEq(status, "ended");
    }

    // ============ FEE BATTLE TESTS ============

    function testFeeBattle_CreateBattle() public {
        vm.startPrank(alice);
        uint256 battleId = feeBattle.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        assertEq(battleId, 0);

        // Check battle details
        (
            address creator,
            address opponent,
            uint256 creatorTokenId,
            uint256 opponentTokenId,
            bool isResolved,
            address winner,
            uint256 startTime,
            uint256 duration,
            uint256 creatorLPValueUSD,
            string memory status
        ) = feeBattle.getBattleDetails(battleId);

        assertEq(creator, alice);
        assertEq(opponent, address(0));
        assertEq(creatorTokenId, ALICE_TOKEN_ID);
        assertEq(opponentTokenId, 0);
        assertFalse(isResolved);
        assertEq(winner, address(0));
        assertEq(startTime, 0);
        assertEq(duration, TEST_DURATION);
        assertGt(creatorLPValueUSD, 0);
        assertEq(status, "waiting_for_opponent");

        vm.stopPrank();
    }

    function testFeeBattle_JoinBattle() public {
        // Alice creates battle
        vm.prank(alice);
        uint256 battleId = feeBattle.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Bob joins battle
        vm.startPrank(bob);
        feeBattle.joinBattle(battleId, BOB_TOKEN_ID);

        // Check battle details after joining
        (
            address creator,
            address opponent,
            ,
            uint256 opponentTokenId,
            bool isResolved,
            ,
            uint256 startTime,
            ,
            ,
            string memory status
        ) = feeBattle.getBattleDetails(battleId);

        assertEq(creator, alice);
        assertEq(opponent, bob);
        assertEq(opponentTokenId, BOB_TOKEN_ID);
        assertFalse(isResolved);
        assertGt(startTime, 0); // Battle should have started
        assertEq(status, "onGoing");

        vm.stopPrank();
    }

    function testFeeBattle_ResolveBattleBasedOnFeeRate() public {
        // Create and join battle
        vm.prank(alice);
        uint256 battleId = feeBattle.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        feeBattle.joinBattle(battleId, BOB_TOKEN_ID);

        // Simulate fee growth during battle
        // Alice: 500->800 (300 growth), 1000->1300 (300 growth) = 600 total growth
        // Bob: 300->600 (300 growth), 800->1000 (200 growth) = 500 total growth
        mockPositionManager.updateFees(ALICE_TOKEN_ID, 800, 1300);
        mockPositionManager.updateFees(BOB_TOKEN_ID, 600, 1000);

        // Update price feed timestamps to avoid StalePrice error
        vm.warp(block.timestamp + 30 minutes); // Move forward but not past battle end

        // Fast forward past battle duration
        vm.warp(block.timestamp + TEST_DURATION + 1);

        vm.prank(resolver);
        feeBattle.resolveBattle(battleId);

        // Alice should win due to higher fee rate
        (,,,,, address winner,,,, string memory status) = feeBattle.getBattleDetails(battleId);
        assertEq(winner, alice);
        assertEq(status, "resolved");
    }

    function testFeeBattle_CannotJoinTwice() public {
        vm.prank(alice);
        uint256 battleId = feeBattle.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        feeBattle.joinBattle(battleId, BOB_TOKEN_ID);

        // Charlie tries to join already joined battle
        vm.prank(charlie);
        vm.expectRevert(BattleAlreadyJoined.selector);
        feeBattle.joinBattle(battleId, CHARLIE_TOKEN_ID);
    }

    function testFeeBattle_CannotResolveBeforeTimeEnds() public {
        vm.prank(alice);
        uint256 battleId = feeBattle.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        feeBattle.joinBattle(battleId, BOB_TOKEN_ID);

        // Try to resolve immediately (should fail)
        vm.prank(resolver);
        vm.expectRevert(BattleNotEnded.selector);
        feeBattle.resolveBattle(battleId);
    }

    // ============ HELPER FUNCTION TESTS ============

    function testGetLPTokenValueUSD() public {
        // Test range vault
        (uint256 amount0, uint256 amount1, uint256 usdValue) = rangeVault.getLPTokenValueUSD(ALICE_TOKEN_ID);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertGt(usdValue, 0);

        // Test fee battle
        (uint256 amount0Fee, uint256 amount1Fee, uint256 usdValueFee) = feeBattle.getLPTokenValueUSD(ALICE_TOKEN_ID);
        assertGt(amount0Fee, 0);
        assertGt(amount1Fee, 0);
        assertGt(usdValueFee, 0);
    }

    function testGetBattleUSDValue() public {
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        string memory formattedValue = rangeVault.getBattleUSDValue(battleId);
        // Should return formatted string like "1,234.56 USD"
        assertTrue(bytes(formattedValue).length > 0);
    }

    function testGetTimeRemaining() public {
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        uint256 timeRemaining = rangeVault.getTimeRemaining(battleId);
        assertEq(timeRemaining, TEST_DURATION);

        // Fast forward half the duration
        vm.warp(block.timestamp + TEST_DURATION / 2);

        uint256 timeRemainingHalf = rangeVault.getTimeRemaining(battleId);
        assertEq(timeRemainingHalf, TEST_DURATION / 2);
    }

    // ============ EDGE CASE TESTS ============

    function testCannotCreateBattleWithoutOwnership() public {
        vm.prank(bob);
        vm.expectRevert();
        rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION); // Bob doesn't own Alice's token
    }

    function testCannotCreateFeeBattleWithShortDuration() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BattleDurationTooShort.selector, 30 minutes, MIN_BATTLE_DURATION));
        feeBattle.createBattle(ALICE_TOKEN_ID, 30 minutes); // Less than minimum 1 hour
    }

    function testCannotJoinNonexistentBattle() public {
        vm.prank(bob);
        vm.expectRevert();
        rangeVault.joinBattle(999, BOB_TOKEN_ID); // Battle 999 doesn't exist
    }

    function testCannotResolveNonexistentBattle() public {
        vm.prank(resolver);
        vm.expectRevert();
        rangeVault.resolveBattle(999); // Battle 999 doesn't exist
    }
}

// ============ MOCK CONTRACTS ============

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

    function updateFees(uint256 tokenId, uint128 newFee0, uint128 newFee1) external {
        positionData[tokenId].tokensOwed0 = newFee0;
        positionData[tokenId].tokensOwed1 = newFee1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return tokenOwners[tokenId];
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
            pos.tokensOwed0,
            pos.tokensOwed1
        );
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        tokenOwners[tokenId] = to;
    }

    function collect(INonfungiblePositionManager.CollectParams calldata params) external returns (uint256, uint256) {
        return (1000, 1000); // Return fixed amounts for testing
    }
}

contract MockFactory {
    mapping(bytes32 => address) public pools;

    function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
        bytes32 key = keccak256(abi.encodePacked(tokenA, tokenB, fee));
        pools[key] = pool;
    }

    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address) {
        bytes32 key = keccak256(abi.encodePacked(tokenA, tokenB, fee));
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
        uint160 sqrtPriceX96_,
        int24 tick_,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return (sqrtPriceX96, tick, 0, 0, 0, 0, true);
    }
}

contract MockPriceFeed {
    int256 public price;
    uint256 public updatedAt;

    constructor(int256 _price) {
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
        // Always return current timestamp to avoid StalePrice errors
        return (1, price, block.timestamp, block.timestamp, 1);
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}
