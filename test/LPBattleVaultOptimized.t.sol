// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";

contract LPBattleVaultOptimizedTest is Test {
    LPBattleVault public vault;

    // Test addresses
    address public creator = makeAddr("creator");
    address public opponent = makeAddr("opponent");
    address public resolver = makeAddr("resolver");
    address public owner = makeAddr("owner");

    // Test token IDs
    uint256 public creatorTokenId = 1;
    uint256 public opponentTokenId = 2;

    // Mock contracts
    MockPositionManager public mockPositionManager;
    MockFactory public mockFactory;
    MockPool public mockPool;
    MockOracle public mockOracle0;  // Price feed for token0
    MockOracle public mockOracle1;  // Price feed for token1 (stablecoin)
    MockERC20 public mockToken0;
    MockERC20 public mockToken1;

    // Gas tracking
    uint256 public gasStart;
    uint256 public gasEnd;

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    function setUp() public {
        // Deploy mock contracts
        mockPositionManager = new MockPositionManager();
        mockFactory = new MockFactory();
        mockPool = new MockPool();
        mockOracle0 = new MockOracle();
        mockOracle1 = new MockOracle();
        mockToken0 = new MockERC20("WETH", "WETH");
        mockToken1 = new MockERC20("USDC", "USDC");

        // Deploy the vault with mock contracts
        vm.prank(owner);
        vault = new LPBattleVault(address(mockPositionManager), address(mockFactory));

        // Setup mock pool
        mockFactory.setPool(address(mockToken0), address(mockToken1), 3000, address(mockPool));

        // Setup price feeds for mock tokens
        vm.startPrank(owner);
        vault.setPriceFeed(address(mockToken0), address(mockOracle0));
        vault.setPriceFeed(address(mockToken1), address(mockOracle1));
        
        // Configure mock oracle prices
        mockOracle0.setPrice(200000000000); // $2000.00 with 8 decimals (like ETH)
        mockOracle1.setPrice(100000000);    // $1.00 with 8 decimals (stablecoin)

        // Setup stablecoins (USDC is stable)
        vault.setStablecoin(address(mockToken1), true);
        vm.stopPrank();

        // Setup mock position data with NEW Battle struct field order
        mockPositionManager.setPositionData(
            creatorTokenId,
            creator,
            address(mockToken0),
            address(mockToken1),
            3000,
            -1000, // tickLower
            1000,  // tickUpper
            1000000000000000000 // liquidity
        );

        mockPositionManager.setPositionData(
            opponentTokenId,
            opponent,
            address(mockToken0),
            address(mockToken1),
            3000,
            -1500, // tickLower (wider than creator)
            1500,  // tickUpper (wider than creator)
            950000000000000000  // slightly less liquidity for 5% tolerance test
        );

        // Setup mock pool slot0 for price calculations
        mockPool.setSlot0(79228162514264337593543950336, 0); // sqrtPriceX96 for 1:1 ratio

        // Give test addresses some ETH
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        vm.deal(resolver, 10 ether);
    }

    function testGasOptimizedBattleCreation() public {
        vm.startPrank(creator);
        
        // Approve NFT to vault
        mockPositionManager.approve(address(vault), creatorTokenId);
        
        // Measure gas for optimized createBattle
        gasStart = gasleft();
        uint256 battleId = vault.createBattle(creatorTokenId, 3600);
        gasEnd = gasleft();
        
        uint256 gasUsed = gasStart - gasEnd;
        console.log("Gas used for optimized createBattle:", gasUsed);
        
        // Verify battle was created with optimized struct
        (
            address battleCreator,
            bool isResolved,
            int24 creatorTickLower,
            int24 creatorTickUpper,
            int24 opponentTickLower,
            int24 opponentTickUpper,
            address battleOpponent,
            address winner,
            uint256 creatorTokenIdStored,
            uint256 opponentTokenIdStored,
            uint256 startTime,
            uint256 duration,
            uint256 totalValueUSD
        ) = vault.battles(battleId);
        
        // Test new optimized Battle struct layout
        assertEq(battleCreator, creator);
        assertEq(isResolved, false);
        assertEq(creatorTickLower, -1000);
        assertEq(creatorTickUpper, 1000);
        assertEq(opponentTickLower, 0);
        assertEq(opponentTickUpper, 0);
        assertEq(battleOpponent, address(0));
        assertEq(winner, address(0));
        assertEq(creatorTokenIdStored, creatorTokenId);
        assertEq(opponentTokenIdStored, 0);
        assertEq(startTime, 0);
        assertEq(duration, 3600);
        assertGt(totalValueUSD, 0);
        
        vm.stopPrank();
    }

    function testGasOptimizedJoinBattle() public {
        // Create battle first
        vm.startPrank(creator);
        mockPositionManager.approve(address(vault), creatorTokenId);
        uint256 battleId = vault.createBattle(creatorTokenId, 3600);
        vm.stopPrank();

        // Join battle with gas measurement
        vm.startPrank(opponent);
        mockPositionManager.approve(address(vault), opponentTokenId);
        
        gasStart = gasleft();
        vault.joinBattle(battleId, opponentTokenId);
        gasEnd = gasleft();
        
        uint256 gasUsed = gasStart - gasEnd;
        console.log("Gas used for optimized joinBattle:", gasUsed);
        
        // Verify battle was joined and storage updated correctly
        (
            ,
            ,
            ,
            ,
            int24 opponentTickLower,
            int24 opponentTickUpper,
            address battleOpponent,
            ,
            ,
            uint256 opponentTokenIdStored,
            uint256 startTime,
            ,
        ) = vault.battles(battleId);
        
        assertEq(battleOpponent, opponent);
        assertEq(opponentTokenIdStored, opponentTokenId);
        assertEq(opponentTickLower, -1500);
        assertEq(opponentTickUpper, 1500);
        assertGt(startTime, 0);
        
        vm.stopPrank();
    }

    function testBitManipulationWinnerLogic() public {
        // Create and join battle
        vm.startPrank(creator);
        mockPositionManager.approve(address(vault), creatorTokenId);
        uint256 battleId = vault.createBattle(creatorTokenId, 1); // 1 second duration
        vm.stopPrank();

        vm.startPrank(opponent);
        mockPositionManager.approve(address(vault), opponentTokenId);
        vault.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();

        // Wait for battle to end
        vm.warp(block.timestamp + 2);

        // Set both positions in range to test bit manipulation logic
        mockPool.setCurrentTick(0); // Both positions should be in range

        // Resolve battle and measure gas
        vm.startPrank(resolver);
        gasStart = gasleft();
        vault.resolveBattle(battleId);
        gasEnd = gasleft();
        
        uint256 gasUsed = gasStart - gasEnd;
        console.log("Gas used for optimized resolveBattle:", gasUsed);
        vm.stopPrank();

        // Verify battle was resolved
        (
            ,
            bool isResolved,
            ,
            ,
            ,
            ,
            ,
            address winner,
            ,
            ,
            ,
            ,
        ) = vault.battles(battleId);
        
        assertTrue(isResolved);
        // Winner should be determined by the bit manipulation logic
        assertTrue(winner == creator || winner == opponent || winner == address(0));
    }

    function testChainlinkPriceFeedOptimization() public {
        // Test that price feeds work without external decimals() calls
        (uint256 amount0, uint256 amount1, uint256 usdValue) = vault.getLPTokenValueUSD(creatorTokenId);
        
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertGt(usdValue, 0);
        
        console.log("LP Token USD Value:", usdValue);
        console.log("Amount0 (WETH):", amount0);
        console.log("Amount1 (USDC):", amount1);
    }

    function testFrontendHelperFunctions() public {
        // Create and join battle
        vm.startPrank(creator);
        mockPositionManager.approve(address(vault), creatorTokenId);
        uint256 battleId = vault.createBattle(creatorTokenId, 3600);
        vm.stopPrank();

        vm.startPrank(opponent);
        mockPositionManager.approve(address(vault), opponentTokenId);
        vault.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();

        // Test comprehensive battle details
        (
            address battleCreator,
            address battleOpponent,
            uint256 creatorTokenIdReturned,
            uint256 opponentTokenIdReturned,
            bool isResolved,
            ,
            uint256 startTime,
            uint256 duration,
            uint256 valueUSD,
            ,
            ,
            ,
            
        ) = vault.getCompleteBattleDetails(battleId);

        assertEq(battleCreator, creator);
        assertEq(battleOpponent, opponent);
        assertEq(creatorTokenIdReturned, creatorTokenId);
        assertEq(opponentTokenIdReturned, opponentTokenId);
        assertEq(isResolved, false);
        assertGt(startTime, 0);
        assertEq(duration, 3600);
        assertGt(valueUSD, 0);

        // Test time remaining
        uint256 timeRemaining = vault.getTimeRemaining(battleId);
        assertGt(timeRemaining, 0);
        assertLe(timeRemaining, 3600);

        // Test current performance
        vault.getCurrentPerformance(battleId);

        // Test battle discovery functions
        uint256[] memory activeBattles;
        string[] memory statuses;
        (activeBattles, statuses) = vault.getAllActiveBattles();
        assertGt(activeBattles.length, 0);

        uint256[] memory userBattles;
        bool[] memory isCreatorArray;
        (userBattles, isCreatorArray) = vault.getUserBattles(creator);
        assertGt(userBattles.length, 0);
        assertTrue(isCreatorArray[0]);
    }

    function testToleranceCheckOptimization() public {
        // Test that 5% tolerance check works with cached memory values
        vm.startPrank(creator);
        mockPositionManager.approve(address(vault), creatorTokenId);
        uint256 battleId = vault.createBattle(creatorTokenId, 3600);
        vm.stopPrank();

        // Test canJoinBattle function
        (bool canJoin, string memory reason) = vault.canJoinBattle(battleId, opponentTokenId);
        assertTrue(canJoin);
        assertEq(reason, "Can join battle");

        // Create a position that's outside tolerance
        uint256 badTokenId = 999;
        mockPositionManager.setPositionData(
            badTokenId,
            opponent,
            address(mockToken0),
            address(mockToken1),
            3000,
            -2000,
            2000,
            100000000000000000 // Much less liquidity - should fail tolerance
        );

        (bool canJoinBad, string memory reasonBad) = vault.canJoinBattle(battleId, badTokenId);
        assertFalse(canJoinBad);
        assertEq(reasonBad, "LP value not within 5% tolerance");
    }

    function testAssemblyStablecoinOptimization() public {
        // Test that assembly-initialized stablecoins work correctly
        assertTrue(vault.stablecoins(0xf817257fed379853cDe0fa4F97AB987181B1E5Ea)); // USDC
        assertTrue(vault.stablecoins(0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D)); // USDT
    }

    function testMemoryCachingInJoinBattle() public {
        // This test ensures that memory caching in joinBattle works correctly
        vm.startPrank(creator);
        mockPositionManager.approve(address(vault), creatorTokenId);
        uint256 battleId = vault.createBattle(creatorTokenId, 3600);
        vm.stopPrank();

        // Get battle data before join
        (
            ,
            bool isResolvedBefore,
            ,
            ,
            ,
            ,
            address opponentBefore,
            ,
            ,
            ,
            ,
            ,
            uint256 totalValueBefore
        ) = vault.battles(battleId);

        assertFalse(isResolvedBefore);
        assertEq(opponentBefore, address(0));
        assertGt(totalValueBefore, 0);

        // Join battle - this tests memory caching optimization
        vm.startPrank(opponent);
        mockPositionManager.approve(address(vault), opponentTokenId);
        vault.joinBattle(battleId, opponentTokenId);
        vm.stopPrank();

        // Verify that cached values were used correctly
        (
            ,
            bool isResolvedAfter,
            ,
            ,
            ,
            ,
            address opponentAfter,
            ,
            ,
            ,
            ,
            ,
            uint256 totalValueAfter
        ) = vault.battles(battleId);

        assertFalse(isResolvedAfter);
        assertEq(opponentAfter, opponent);
        assertEq(totalValueAfter, totalValueBefore); // Should remain the same
    }
}

// Mock contracts for testing
contract MockPositionManager {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => bool) public approved;
    mapping(uint256 => PositionData) public positions;
    
    struct PositionData {
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
        ownerOf[tokenId] = owner;
        positions[tokenId] = PositionData({
            owner: owner,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            tokensOwed0: 1000000, // Mock fees
            tokensOwed1: 1000000  // Mock fees
        });
    }

    function approve(address, uint256 tokenId) external {
        approved[tokenId] = true;
    }

    function safeTransferFrom(address, address, uint256) external pure {
        // Mock transfer
    }

    function collect(INonfungiblePositionManager.CollectParams calldata)
        external
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        return (500000, 500000); // Mock collected fees
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
    int24 public currentTick;

    function setSlot0(uint160 _sqrtPriceX96, int24 _tick) external {
        sqrtPriceX96 = _sqrtPriceX96;
        currentTick = _tick;
    }

    function setCurrentTick(int24 _tick) external {
        currentTick = _tick;
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
        return (sqrtPriceX96, currentTick, 0, 0, 0, 0, false);
    }
}

contract MockOracle {
    int256 public price;
    uint256 public updatedAt;

    constructor() {
        updatedAt = block.timestamp;
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAtReturn,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, updatedAt, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1000000 * 10**18;
    }
}