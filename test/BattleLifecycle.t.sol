// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/interfaces/IShared.sol";

contract BattleLifecycleTest is Test {
    LPBattleVault public vault;
    LPFeeBattle public feeBattle;
    
    // Mock contracts
    MockPositionManager public positionManager;
    MockFactory public factory;
    MockPool public pool;
    MockPriceFeed public ethPriceFeed;
    MockPriceFeed public usdcPriceFeed;
    MockERC20 public weth;
    MockERC20 public usdc;
    
    // Test accounts
    address public creator = address(0x1);
    address public opponent = address(0x2);
    address public resolver = address(0x3);
    
    // Test data
    uint256 public constant CREATOR_TOKEN_ID = 1;
    uint256 public constant OPPONENT_TOKEN_ID = 2;
    uint256 public constant BATTLE_DURATION = 2 hours;
    


    function setUp() public {
        // Deploy mock contracts
        weth = new MockERC20("WETH", "WETH", 18);
        usdc = new MockERC20("USDC", "USDC", 6);
        positionManager = new MockPositionManager();
        factory = new MockFactory();
        pool = new MockPool();
        
        // Deploy price feeds
        ethPriceFeed = new MockPriceFeed(8, 2000 * 1e8); // $2000 ETH
        usdcPriceFeed = new MockPriceFeed(8, 1 * 1e8); // $1 USDC
        
        // Deploy battle contracts
        vault = new LPBattleVault(address(positionManager), address(factory));
        feeBattle = new LPFeeBattle(address(positionManager), address(factory));
        
        // Setup price feeds
        vault.setPriceFeed(address(weth), address(ethPriceFeed));
        vault.setPriceFeed(address(usdc), address(usdcPriceFeed));
        feeBattle.setPriceFeed(address(weth), address(ethPriceFeed));
        feeBattle.setPriceFeed(address(usdc), address(usdcPriceFeed));
        
        // Setup stablecoins
        vault.setStablecoin(address(usdc), true);
        feeBattle.setStablecoin(address(usdc), true);
        
        // Setup mock LP positions
        positionManager.setPosition(CREATOR_TOKEN_ID, creator, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        positionManager.setPosition(OPPONENT_TOKEN_ID, opponent, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        
        // Setup pool
        factory.setPool(address(weth), address(usdc), 3000, address(pool));
        
        // Fund accounts
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        vm.deal(resolver, 10 ether);
    }
    
    function testVaultBattleLifecycle() public {
        console.log("=== Testing LPBattleVault Full Lifecycle ===");
        
        // Test 1: Create Battle
        vm.startPrank(creator);

        uint256 battleId = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);

        assertEq(battleId, 0, "First battle should have ID 0");
        assertEq(positionManager.ownerOf(CREATOR_TOKEN_ID), address(vault), "Vault should own creator's NFT");

        // Check battle details
        (address battleCreator, address battleOpponent, uint256 usdValue, address winner, string memory status) =
            vault.getBattleDetails(battleId);

        assertEq(battleCreator, creator, "Creator should match");
        assertEq(battleOpponent, address(0), "No opponent yet");
        assertGt(usdValue, 0, "USD value should be greater than 0");
        assertEq(winner, address(0), "No winner yet");
        assertEq(status, "queued", "Status should be queued");
        
        vm.stopPrank();
        
        // Test 2: Join Battle
        vm.startPrank(opponent);

        vault.joinBattle(battleId, OPPONENT_TOKEN_ID);
        
        assertEq(positionManager.ownerOf(OPPONENT_TOKEN_ID), address(vault), "Vault should own opponent's NFT");
        
        // Check updated battle details
        (battleCreator, battleOpponent, usdValue, winner, status) = vault.getBattleDetails(battleId);
        
        assertEq(battleOpponent, opponent, "Opponent should be set");
        assertEq(status, "onGoing", "Status should be onGoing");
        
        vm.stopPrank();
        
        // Test 3: Resolve Battle (after duration)
        vm.warp(block.timestamp + BATTLE_DURATION + 1);

        vm.startPrank(resolver);

        vault.resolveBattle(battleId);
        
        // Check final battle state
        (battleCreator, battleOpponent, usdValue, winner, status) = vault.getBattleDetails(battleId);
        
        assertEq(winner, creator, "Creator should win");
        assertEq(status, "ended", "Status should be ended");
        
        // Check NFTs returned
        assertEq(positionManager.ownerOf(CREATOR_TOKEN_ID), creator, "Creator should get NFT back");
        assertEq(positionManager.ownerOf(OPPONENT_TOKEN_ID), opponent, "Opponent should get NFT back");
        
        vm.stopPrank();
        
        console.log("LPBattleVault lifecycle test passed");
    }
    
    function testFeeBattleLifecycle() public {
        console.log("=== Testing LPFeeBattle Full Lifecycle ===");
        
        // Test 1: Create Fee Battle
        vm.startPrank(creator);
        
        uint256 battleId = feeBattle.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        
        assertEq(battleId, 0, "First battle should have ID 0");
        assertEq(positionManager.ownerOf(CREATOR_TOKEN_ID), address(feeBattle), "FeeBattle should own creator's NFT");
        
        // Check battle status
        string memory status = feeBattle.getBattleStatus(battleId);
        assertEq(status, "waiting_for_opponent", "Status should be waiting for opponent");
        
        vm.stopPrank();
        
        // Test 2: Join Fee Battle
        vm.startPrank(opponent);
        
        feeBattle.joinBattle(battleId, OPPONENT_TOKEN_ID);
        
        assertEq(positionManager.ownerOf(OPPONENT_TOKEN_ID), address(feeBattle), "FeeBattle should own opponent's NFT");
        
        // Check updated status
        status = feeBattle.getBattleStatus(battleId);
        assertEq(status, "onGoing", "Status should be onGoing");
        
        vm.stopPrank();
        
        // Test 3: Simulate fee accumulation and resolve
        vm.warp(block.timestamp + BATTLE_DURATION + 1);
        
        // Mock some fee accumulation
        positionManager.setFees(CREATOR_TOKEN_ID, 100e6, 50e18); // 100 USDC, 50 WETH fees
        positionManager.setFees(OPPONENT_TOKEN_ID, 80e6, 60e18);  // 80 USDC, 60 WETH fees
        
        vm.startPrank(resolver);
        
        feeBattle.resolveBattle(battleId);
        
        // Check final status
        status = feeBattle.getBattleStatus(battleId);
        assertEq(status, "resolved", "Status should be resolved");
        
        // Check NFTs returned
        assertEq(positionManager.ownerOf(CREATOR_TOKEN_ID), creator, "Creator should get NFT back");
        assertEq(positionManager.ownerOf(OPPONENT_TOKEN_ID), opponent, "Opponent should get NFT back");
        
        vm.stopPrank();
        
        console.log("LPFeeBattle lifecycle test passed");
    }
    
    function testChainlinkPriceFeedIntegration() public {
        console.log("=== Testing Chainlink Price Feed Integration ===");
        
        // Test 1: Price feed functionality
        uint256 ethAmount = 1e18; // 1 ETH
        uint256 expectedUSD = 2000e18; // $2000
        
        uint256 actualUSD = vault.getTokenUSDValueExternal(address(weth), ethAmount);
        assertEq(actualUSD, expectedUSD, "ETH price conversion should be correct");
        
        // Test 2: Stablecoin handling
        uint256 usdcAmount = 1000e6; // 1000 USDC
        uint256 expectedUSDFromUSDC = 1000e18; // $1000
        
        uint256 actualUSDFromUSDC = vault.getTokenUSDValueExternal(address(usdc), usdcAmount);
        assertEq(actualUSDFromUSDC, expectedUSDFromUSDC, "USDC conversion should be correct");
        
        // Test 3: Price staleness check
        vm.warp(block.timestamp + 6 hours); // Make price stale
        
        vm.expectRevert(StalePrice.selector);
        vault.getTokenUSDValueExternal(address(weth), ethAmount);
        
        // Test 4: Update price and verify it works again
        ethPriceFeed.setPrice(2100 * 1e8); // Update to $2100
        
        uint256 newExpectedUSD = 2100e18;
        uint256 newActualUSD = vault.getTokenUSDValueExternal(address(weth), ethAmount);
        assertEq(newActualUSD, newExpectedUSD, "Updated ETH price should work");
        
        console.log("Chainlink price feed integration test passed");
    }

    function testBattleEdgeCases() public {
        console.log("=== Testing Battle Edge Cases ===");

        // Test 1: Cannot join own battle
        vm.startPrank(creator);
        uint256 battleId = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);

        vm.expectRevert(); // Should revert when trying to join own battle
        vault.joinBattle(battleId, OPPONENT_TOKEN_ID);
        vm.stopPrank();

        // Test 2: Cannot resolve battle before it ends
        vm.startPrank(opponent);
        vault.joinBattle(battleId, OPPONENT_TOKEN_ID);
        vm.stopPrank();

        vm.expectRevert(BattleNotEnded.selector);
        vault.resolveBattle(battleId);

        // Test 3: Cannot join already resolved battle
        vm.warp(block.timestamp + BATTLE_DURATION + 1);
        vault.resolveBattle(battleId);

        vm.startPrank(creator);
        uint256 newTokenId = 3;
        positionManager.setPosition(newTokenId, creator, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);

        vm.expectRevert(BattleAlreadyResolved.selector);
        vault.joinBattle(battleId, newTokenId);
        vm.stopPrank();

        console.log("Battle edge cases test passed");
    }

    function testWinnerDetermination() public {
        console.log("=== Testing Winner Determination Logic ===");

        // Create and join fee battle
        vm.startPrank(creator);
        uint256 battleId = feeBattle.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        vm.stopPrank();

        vm.startPrank(opponent);
        feeBattle.joinBattle(battleId, OPPONENT_TOKEN_ID);
        vm.stopPrank();

        // Simulate different fee scenarios
        vm.warp(block.timestamp + BATTLE_DURATION + 1);

        // Test 1: Creator has higher fees (should win)
        positionManager.setFees(CREATOR_TOKEN_ID, 200e6, 100e18); // Higher fees
        positionManager.setFees(OPPONENT_TOKEN_ID, 100e6, 50e18);  // Lower fees

        feeBattle.resolveBattle(battleId);

        (,,,, bool isResolved, address winner,,,,) = feeBattle.getBattleDetails(battleId);
        assertEq(winner, creator, "Creator should win with higher fees");

        console.log("Winner determination test passed");
    }
}

// Mock contracts for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balanceOf[address(this)] = 1000000e18; // Give contract some balance
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[address(this)] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockPriceFeed {
    uint8 private _decimals;
    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;

    constructor(uint8 decimals_, int256 price_) {
        _decimals = decimals_;
        _price = price_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function setPrice(int256 price_) external {
        _price = price_;
        _updatedAt = block.timestamp;
        _roundId++;
    }
}

contract MockPositionManager {
    mapping(uint256 => address) private _owners;
    mapping(uint256 => Position) private _positions;
    mapping(uint256 => Fees) private _fees;

    struct Position {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    struct Fees {
        uint128 owed0;
        uint128 owed1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function setPosition(uint256 tokenId, address owner, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint128 owed0, uint128 owed1) external {
        _owners[tokenId] = owner;
        _positions[tokenId] = Position(token0, token1, fee, tickLower, tickUpper, liquidity);
        _fees[tokenId] = Fees(owed0, owed1);
    }

    function setFees(uint256 tokenId, uint128 owed0, uint128 owed1) external {
        _fees[tokenId] = Fees(owed0, owed1);
    }

    function positions(uint256 tokenId) external view returns (
        uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128
    ) {
        Position memory pos = _positions[tokenId];
        Fees memory fees = _fees[tokenId];
        return (0, address(0), pos.token0, pos.token1, pos.fee, pos.tickLower, pos.tickUpper, pos.liquidity, 0, 0, fees.owed0, fees.owed1);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(_owners[tokenId] == from, "Not owner");
        _owners[tokenId] = to;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external returns (uint256 amount0, uint256 amount1) {
        // Mock collect function - return some fees
        return (1000, 2000); // Mock fee amounts
    }
}

contract MockPool {
    uint160 public sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96 (price = 1)
    int24 public tick = 0;
    uint16 public observationIndex = 0;
    uint16 public observationCardinality = 1;
    uint16 public observationCardinalityNext = 1;
    uint8 public feeProtocol = 0;
    bool public unlocked = true;

    function slot0() external view returns (
        uint160 sqrtPriceX96_,
        int24 tick_,
        uint16 observationIndex_,
        uint16 observationCardinality_,
        uint16 observationCardinalityNext_,
        uint8 feeProtocol_,
        bool unlocked_
    ) {
        return (sqrtPriceX96, tick, observationIndex, observationCardinality, observationCardinalityNext, feeProtocol, unlocked);
    }

    function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
        sqrtPriceX96 = _sqrtPriceX96;
    }
}

contract MockFactory {
    mapping(bytes32 => address) private _pools;

    function getPool(address token0, address token1, uint24 fee) external view returns (address) {
        bytes32 key = keccak256(abi.encodePacked(token0, token1, fee));
        return _pools[key];
    }

    function setPool(address token0, address token1, uint24 fee, address pool) external {
        bytes32 key = keccak256(abi.encodePacked(token0, token1, fee));
        _pools[key] = pool;
    }
}
