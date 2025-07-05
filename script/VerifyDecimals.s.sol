// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";

contract VerifyDecimals is Script {
    LPBattleVault public vault;
    LPFeeBattle public feeBattle;
    
    // Mock token addresses for testing
    address constant USDC = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;
    address constant USDT = 0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D;
    address constant WETH = 0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37;
    address constant WBTC = 0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d;
    
    function run() external {
        // Load deployed contracts (replace with actual addresses)
        vault = LPBattleVault(0x1234567890123456789012345678901234567890); // Replace with actual
        feeBattle = LPFeeBattle(0x2345678901234567890123456789012345678901); // Replace with actual
        
        console.log("=== DECIMAL VERIFICATION SCRIPT ===");
        console.log("Testing decimal handling across all contracts...\n");
        
        // Test 1: Verify stablecoin decimal handling
        testStablecoinDecimals();
        
        // Test 2: Verify price feed decimal handling
        testPriceFeedDecimals();
        
        // Test 3: Verify string formatting
        testStringFormatting();
        
        // Test 4: Cross-contract consistency
        testCrossContractConsistency();
        
        // Test 5: Edge cases
        testEdgeCases();
        
        console.log("\n=== VERIFICATION COMPLETE ===");
    }
    
    function testStablecoinDecimals() internal {
        console.log("--- Testing Stablecoin Decimals ---");
        
        // Test USDC (6 decimals)
        uint256 usdcAmount = 710000; // 0.71 USDC
        console.log("Input: 0.71 USDC (710000 raw units)");
        
        try vault.getTokenUSDValueExternal(USDC, usdcAmount) returns (uint256 vaultResult) {
            console.log("LPBattleVault result:", vaultResult);
            console.log("Expected: 710000000000000000 (0.71 * 1e18)");
            
            if (vaultResult == 710000000000000000) {
                console.log("LPBattleVault: PASS");
            } else {
                console.log("LPBattleVault: FAIL");
            }
        } catch {
            console.log("LPBattleVault: ERROR - Call failed");
        }
        
        try feeBattle.getTokenUSDValueExternal(USDC, usdcAmount) returns (uint256 feeResult) {
            console.log("LPFeeBattle result:", feeResult);
            
            if (feeResult == 710000000000000000) {
                console.log("LPFeeBattle: PASS");
            } else {
                console.log("LPFeeBattle: FAIL");
            }
        } catch {
            console.log("LPFeeBattle: ERROR - Call failed");
        }
        
        console.log("");
    }
    
    function testPriceFeedDecimals() internal {
        console.log("--- Testing Price Feed Decimals ---");
        console.log("Skipping price feed tests - no mock price feeds configured");
        console.log("Price feed tests require actual Chainlink feeds to be set up");
        console.log("");
    }
    
    function testStringFormatting() internal {
        console.log("--- Testing String Formatting ---");
        
        // Test various USD amounts
        uint256[] memory testAmounts = new uint256[](4);
        testAmounts[0] = 710000000000000000; // 0.71 USD
        testAmounts[1] = 71000000000000000000; // 71 USD
        testAmounts[2] = 2000000000000000000000; // 2000 USD
        testAmounts[3] = 1234567890123456789; // 1.234567890123456789 USD
        
        string[] memory expected = new string[](4);
        expected[0] = "0.71 USD";
        expected[1] = "71.00 USD";
        expected[2] = "2000.00 USD";
        expected[3] = "1.23 USD";
        
        for (uint i = 0; i < testAmounts.length; i++) {
            string memory result = StringUtils.formatUSDValue(testAmounts[i]);
            console.log("Amount:", testAmounts[i]);
            console.log("Formatted:", result);
            console.log("Expected:", expected[i]);
            console.log("---");
        }
        
        console.log("");
    }
    
    function testCrossContractConsistency() internal {
        console.log("--- Testing Cross-Contract Consistency ---");
        
        uint256 testAmount = 1000000; // 1 USDC
        
        try vault.getTokenUSDValueExternal(USDC, testAmount) returns (uint256 vaultResult) {
            try feeBattle.getTokenUSDValueExternal(USDC, testAmount) returns (uint256 feeResult) {
                console.log("LPBattleVault result:", vaultResult);
                console.log("LPFeeBattle result:", feeResult);
                
                if (vaultResult == feeResult) {
                    console.log("Cross-contract consistency: PASS");
                } else {
                    console.log("Cross-contract consistency: FAIL");
                    console.log("Difference:", vaultResult > feeResult ? vaultResult - feeResult : feeResult - vaultResult);
                }
            } catch {
                console.log("LPFeeBattle call failed");
            }
        } catch {
            console.log("LPBattleVault call failed");
        }
        
        console.log("");
    }
    
    function testEdgeCases() internal {
        console.log("--- Testing Edge Cases ---");
        
        // Test very small amount
        uint256 smallAmount = 1; // 0.000001 USDC
        console.log("Testing very small amount: 1 (0.000001 USDC)");
        
        try vault.getTokenUSDValueExternal(USDC, smallAmount) returns (uint256 result) {
            console.log("Result:", result);
            console.log("Expected: 1000000000000 (0.000001 * 1e18)");
            
            if (result == 1000000000000) {
                console.log("Small amount: PASS");
            } else {
                console.log("Small amount: FAIL");
            }
        } catch {
            console.log("Small amount: ERROR");
        }
        
        // Test large amount
        uint256 largeAmount = 1000000000000; // 1 million USDC
        console.log("Testing large amount: 1000000000000 (1M USDC)");
        
        try vault.getTokenUSDValueExternal(USDC, largeAmount) returns (uint256 result) {
            console.log("Result:", result);
            console.log("Expected: 1000000000000000000000000 (1M * 1e18)");
            
            if (result == 1000000000000000000000000) {
                console.log("Large amount: PASS");
            } else {
                console.log("Large amount: FAIL");
            }
        } catch {
            console.log("Large amount: ERROR");
        }
        
        // Test zero amount
        console.log("Testing zero amount");
        try vault.getTokenUSDValueExternal(USDC, 0) returns (uint256 result) {
            if (result == 0) {
                console.log("Zero amount: PASS");
            } else {
                console.log("Zero amount: FAIL");
            }
        } catch {
            console.log("Zero amount: ERROR");
        }
        
        console.log("");
    }
    
    // Helper function to deploy contracts for testing
    function deployContracts() external {
        vm.startBroadcast();

        // Deploy mock position manager and factory (use any address for testing)
        address mockPM = address(0x1111);
        address mockFactory = address(0x2222);

        // Deploy contracts
        LPBattleVault newVault = new LPBattleVault(mockPM, mockFactory);
        LPFeeBattle newFeeBattle = new LPFeeBattle(mockPM, mockFactory);

        // Configure stablecoins only
        newVault.setStablecoin(USDC, true);
        newVault.setStablecoin(USDT, true);
        newFeeBattle.setStablecoin(USDC, true);
        newFeeBattle.setStablecoin(USDT, true);

        console.log("Contracts deployed:");
        console.log("LPBattleVault:", address(newVault));
        console.log("LPFeeBattle:", address(newFeeBattle));

        vm.stopBroadcast();
    }
}
