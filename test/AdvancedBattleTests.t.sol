// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/interfaces/IShared.sol";
import "./BattleLifecycle.t.sol";

contract AdvancedBattleTests is Test {
    LPBattleVault public vault;
    LPFeeBattle public feeBattle;
    MockPositionManager public positionManager;
    MockFactory public factory;
    MockPool public pool;
    MockPriceFeed public ethPriceFeed;
    MockPriceFeed public usdcPriceFeed;
    MockERC20 public weth;
    MockERC20 public usdc;
    
    address public creator = address(0x1);
    address public opponent = address(0x2);
    address public resolver = address(0x3);
    address public spectator = address(0x4);
    
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
        
        // Deploy price feeds with realistic prices
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
        
        // Setup mock LP positions with different values
        positionManager.setPosition(CREATOR_TOKEN_ID, creator, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        positionManager.setPosition(OPPONENT_TOKEN_ID, opponent, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        
        // Setup pool
        factory.setPool(address(weth), address(usdc), 3000, address(pool));
        
        // Fund accounts
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        vm.deal(resolver, 10 ether);
        vm.deal(spectator, 10 ether);
    }
    
    function testMultipleBattlesSimultaneously() public {
        console.log("=== Testing Multiple Simultaneous Battles ===");
        
        // Create multiple battles
        vm.startPrank(creator);
        uint256 battleId1 = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        
        // Setup additional tokens for multiple battles
        uint256 creatorToken2 = 3;
        positionManager.setPosition(creatorToken2, creator, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        uint256 battleId2 = feeBattle.createBattle(creatorToken2, BATTLE_DURATION);
        vm.stopPrank();
        
        // Join both battles
        vm.startPrank(opponent);
        vault.joinBattle(battleId1, OPPONENT_TOKEN_ID);
        
        uint256 opponentToken2 = 4;
        positionManager.setPosition(opponentToken2, opponent, address(weth), address(usdc), 3000, -60, 60, 1000e18, 0, 0);
        feeBattle.joinBattle(battleId2, opponentToken2);
        vm.stopPrank();
        
        // Verify both battles are active
        (, , , , string memory status1) = vault.getBattleDetails(battleId1);
        string memory status2 = feeBattle.getBattleStatus(battleId2);
        
        assertEq(status1, "onGoing", "Vault battle should be ongoing");
        assertEq(status2, "onGoing", "Fee battle should be ongoing");
        
        // Resolve both battles after duration
        vm.warp(block.timestamp + BATTLE_DURATION + 1);
        
        vault.resolveBattle(battleId1);
        feeBattle.resolveBattle(battleId2);
        
        // Verify both battles are resolved
        (, , , , status1) = vault.getBattleDetails(battleId1);
        status2 = feeBattle.getBattleStatus(battleId2);
        
        assertEq(status1, "ended", "Vault battle should be ended");
        assertEq(status2, "resolved", "Fee battle should be resolved");
        
        console.log("Multiple simultaneous battles test passed");
    }
    
    function testBattleValueToleranceChecks() public {
        console.log("=== Testing Battle Value Tolerance ===");
        
        // Create battle with specific value
        vm.startPrank(creator);
        uint256 battleId = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        vm.stopPrank();
        
        // Test 1: Try to join with LP value outside tolerance (too low)
        uint256 lowValueTokenId = 5;
        positionManager.setPosition(lowValueTokenId, opponent, address(weth), address(usdc), 3000, -60, 60, 500e18, 0, 0); // 50% of original value
        
        vm.startPrank(opponent);
        vm.expectRevert(); // Should revert due to value mismatch
        vault.joinBattle(battleId, lowValueTokenId);
        vm.stopPrank();
        
        // Test 2: Try to join with LP value outside tolerance (too high)
        uint256 highValueTokenId = 6;
        positionManager.setPosition(highValueTokenId, opponent, address(weth), address(usdc), 3000, -60, 60, 2000e18, 0, 0); // 200% of original value
        
        vm.startPrank(opponent);
        vm.expectRevert(); // Should revert due to value mismatch
        vault.joinBattle(battleId, highValueTokenId);
        vm.stopPrank();
        
        // Test 3: Join with LP value within tolerance (should succeed)
        uint256 validTokenId = 7;
        positionManager.setPosition(validTokenId, opponent, address(weth), address(usdc), 3000, -60, 60, 980e18, 0, 0); // 98% of original (within 5% tolerance)
        
        vm.startPrank(opponent);
        vault.joinBattle(battleId, validTokenId); // Should succeed
        vm.stopPrank();
        
        (, address battleOpponent, , , ) = vault.getBattleDetails(battleId);
        assertEq(battleOpponent, opponent, "Opponent should be set after successful join");
        
        console.log("Battle value tolerance test passed");
    }
    
    function testChainlinkPriceFeedEdgeCases() public {
        console.log("=== Testing Chainlink Price Feed Edge Cases ===");
        
        // Test 1: Zero price should revert
        ethPriceFeed.setPrice(0);

        vm.expectRevert(); // Should revert with custom error
        vault.getTokenUSDValueExternal(address(weth), 1e18);

        // Test 2: Negative price should revert
        ethPriceFeed.setPrice(-1000 * 1e8);

        vm.expectRevert(); // Should revert with custom error
        vault.getTokenUSDValueExternal(address(weth), 1e18);
        
        // Test 3: Very high price should work
        ethPriceFeed.setPrice(100000 * 1e8); // $100,000 ETH
        
        uint256 result = vault.getTokenUSDValueExternal(address(weth), 1e18);
        assertEq(result, 100000e18, "High price should work correctly");
        
        // Test 4: Very low price should work
        ethPriceFeed.setPrice(1); // Very low price
        
        result = vault.getTokenUSDValueExternal(address(weth), 1e18);
        assertGt(result, 0, "Very low price should still work");
        
        // Test 5: Price feed not set should revert
        MockERC20 newToken = new MockERC20("NEW", "NEW", 18);
        
        vm.expectRevert(PriceFeedNotSet.selector);
        vault.getTokenUSDValueExternal(address(newToken), 1e18);
        
        console.log("Chainlink price feed edge cases test passed");
    }
    
    function testBattleGasOptimization() public {
        console.log("=== Testing Battle Gas Optimization ===");
        
        // Test gas usage for battle operations
        uint256 gasBefore;
        uint256 gasAfter;
        
        // Test 1: Create battle gas usage
        vm.startPrank(creator);
        gasBefore = gasleft();
        uint256 battleId = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        gasAfter = gasleft();
        uint256 createGas = gasBefore - gasAfter;
        console.log("Create battle gas:", createGas);
        vm.stopPrank();
        
        // Test 2: Join battle gas usage
        vm.startPrank(opponent);
        gasBefore = gasleft();
        vault.joinBattle(battleId, OPPONENT_TOKEN_ID);
        gasAfter = gasleft();
        uint256 joinGas = gasBefore - gasAfter;
        console.log("Join battle gas:", joinGas);
        vm.stopPrank();
        
        // Test 3: Resolve battle gas usage
        vm.warp(block.timestamp + BATTLE_DURATION + 1);
        
        gasBefore = gasleft();
        vault.resolveBattle(battleId);
        gasAfter = gasleft();
        uint256 resolveGas = gasBefore - gasAfter;
        console.log("Resolve battle gas:", resolveGas);
        
        // Verify gas usage is reasonable (these are rough estimates)
        assertLt(createGas, 500000, "Create battle should use less than 500k gas");
        assertLt(joinGas, 300000, "Join battle should use less than 300k gas");
        assertLt(resolveGas, 400000, "Resolve battle should use less than 400k gas");
        
        console.log("Battle gas optimization test passed");
    }
    
    function testBattleTimeManagement() public {
        console.log("=== Testing Battle Time Management ===");
        
        // Create and join battle
        vm.startPrank(creator);
        uint256 battleId = vault.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        vm.stopPrank();
        
        vm.startPrank(opponent);
        vault.joinBattle(battleId, OPPONENT_TOKEN_ID);
        vm.stopPrank();
        
        uint256 startTime = block.timestamp;
        
        // Test 1: Battle should not be resolvable before duration
        vm.warp(startTime + BATTLE_DURATION - 1);
        
        vm.expectRevert(BattleNotEnded.selector);
        vault.resolveBattle(battleId);
        
        // Test 2: Battle should be resolvable exactly at duration end
        vm.warp(startTime + BATTLE_DURATION);
        
        vault.resolveBattle(battleId); // Should succeed
        
        (, , , , string memory status) = vault.getBattleDetails(battleId);
        assertEq(status, "ended", "Battle should be ended");
        
        console.log("Battle time management test passed");
    }
    
    function testFeeBattlePerformanceTracking() public {
        console.log("=== Testing Fee Battle Performance Tracking ===");
        
        // Create and join fee battle
        vm.startPrank(creator);
        uint256 battleId = feeBattle.createBattle(CREATOR_TOKEN_ID, BATTLE_DURATION);
        vm.stopPrank();
        
        vm.startPrank(opponent);
        feeBattle.joinBattle(battleId, OPPONENT_TOKEN_ID);
        vm.stopPrank();
        
        // Simulate fee accumulation over time
        vm.warp(block.timestamp + BATTLE_DURATION / 2); // Halfway through battle
        
        // Set different fee accumulation rates
        positionManager.setFees(CREATOR_TOKEN_ID, 50e6, 25e18);   // Creator: 50 USDC, 25 WETH
        positionManager.setFees(OPPONENT_TOKEN_ID, 30e6, 40e18);  // Opponent: 30 USDC, 40 WETH
        
        // Check current performance
        (uint256 creatorFeeUSD, uint256 opponentFeeUSD, , ) =
            feeBattle.getCurrentFeePerformance(battleId);
        
        assertGt(creatorFeeUSD, 0, "Creator should have fee growth");
        assertGt(opponentFeeUSD, 0, "Opponent should have fee growth");
        
        // Finish battle and resolve
        vm.warp(block.timestamp + BATTLE_DURATION / 2 + 1);
        
        feeBattle.resolveBattle(battleId);
        
        string memory status = feeBattle.getBattleStatus(battleId);
        assertEq(status, "resolved", "Battle should be resolved");
        
        console.log("Fee battle performance tracking test passed");
    }
}
