// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "../src/libraries/StringUtils.sol";

contract DecimalHandlingTest is Test {
    LPBattleVault public vault;
    LPFeeBattle public feeBattle;

    // Mock tokens with different decimals
    MockERC20 public usdc; // 6 decimals
    MockERC20 public usdt; // 6 decimals
    MockERC20 public weth; // 18 decimals
    MockERC20 public wbtc; // 8 decimals
    MockERC20 public dai;  // 18 decimals
    
    address public owner = address(this);
    
    function setUp() public {
        // Deploy mock position manager and factory
        address mockPM = address(0x1111);
        address mockFactory = address(0x2222);

        // Deploy contracts
        vault = new LPBattleVault(mockPM, mockFactory);
        feeBattle = new LPFeeBattle(mockPM, mockFactory);

        // Deploy mock tokens
        usdc = new MockERC20("USDC", "USDC", 6);
        usdt = new MockERC20("USDT", "USDT", 6);
        weth = new MockERC20("WETH", "WETH", 18);
        wbtc = new MockERC20("WBTC", "WBTC", 8);
        dai = new MockERC20("DAI", "DAI", 18);

        // Configure stablecoins only (no price feeds needed for stablecoin tests)
        vault.setStablecoin(address(usdc), true);
        vault.setStablecoin(address(usdt), true);
        vault.setStablecoin(address(dai), true);

        feeBattle.setStablecoin(address(usdc), true);
        feeBattle.setStablecoin(address(usdt), true);
        feeBattle.setStablecoin(address(dai), true);

        // Set token decimals for caching
        vault.setTokenDecimals(address(usdc), 6);
        vault.setTokenDecimals(address(usdt), 6);
        vault.setTokenDecimals(address(dai), 18);

        feeBattle.setTokenDecimals(address(usdc), 6);
        feeBattle.setTokenDecimals(address(usdt), 6);
        feeBattle.setTokenDecimals(address(dai), 18);
    }
    
    function testStablecoinDecimals() public {
        console.log("=== Testing Stablecoin Decimals ===");
        
        // Test USDC (6 decimals)
        uint256 usdcAmount = 710000; // 0.71 USDC
        uint256 expectedUSD = 710000000000000000; // 0.71 USD with 18 decimals
        
        uint256 vaultResult = vault.getTokenUSDValueExternal(address(usdc), usdcAmount);
        uint256 feeResult = feeBattle.getTokenUSDValueExternal(address(usdc), usdcAmount);
        
        assertEq(vaultResult, expectedUSD, "Vault USDC conversion failed");
        assertEq(feeResult, expectedUSD, "FeeBattle USDC conversion failed");
        assertEq(vaultResult, feeResult, "Cross-contract USDC consistency failed");
        
        console.log("USDC test passed");
    }
    
    function testDAIDecimals() public {
        console.log("=== Testing DAI Decimals (18 decimals stablecoin) ===");

        // Test DAI (18 decimals) - should work same as other stablecoins
        uint256 daiAmount = 710000000000000000; // 0.71 DAI (18 decimals)
        uint256 expectedUSD = 710000000000000000; // 0.71 USD with 18 decimals (same)

        uint256 vaultResult = vault.getTokenUSDValueExternal(address(dai), daiAmount);
        uint256 feeResult = feeBattle.getTokenUSDValueExternal(address(dai), daiAmount);

        assertEq(vaultResult, expectedUSD, "Vault DAI conversion failed");
        assertEq(feeResult, expectedUSD, "FeeBattle DAI conversion failed");
        assertEq(vaultResult, feeResult, "Cross-contract DAI consistency failed");

        console.log("DAI test passed");
    }

    function testUSDTDecimals() public {
        console.log("=== Testing USDT Decimals (6 decimals stablecoin) ===");

        // Test USDT (6 decimals) - should work same as USDC
        uint256 usdtAmount = 710000; // 0.71 USDT
        uint256 expectedUSD = 710000000000000000; // 0.71 USD with 18 decimals

        uint256 vaultResult = vault.getTokenUSDValueExternal(address(usdt), usdtAmount);
        uint256 feeResult = feeBattle.getTokenUSDValueExternal(address(usdt), usdtAmount);

        assertEq(vaultResult, expectedUSD, "Vault USDT conversion failed");
        assertEq(feeResult, expectedUSD, "FeeBattle USDT conversion failed");
        assertEq(vaultResult, feeResult, "Cross-contract USDT consistency failed");

        console.log("USDT test passed");
    }
    
    function testEdgeCases() public {
        console.log("=== Testing Edge Cases ===");
        
        // Test zero amount
        uint256 zeroResult = vault.getTokenUSDValueExternal(address(usdc), 0);
        assertEq(zeroResult, 0, "Zero amount test failed");
        
        // Test very small amount
        uint256 smallAmount = 1; // 0.000001 USDC
        uint256 expectedSmall = 1000000000000; // 0.000001 * 1e18
        uint256 smallResult = vault.getTokenUSDValueExternal(address(usdc), smallAmount);
        assertEq(smallResult, expectedSmall, "Small amount test failed");
        
        // Test large amount
        uint256 largeAmount = 1000000 * 1e6; // 1M USDC
        uint256 expectedLarge = 1000000 * 1e18; // 1M USD with 18 decimals
        uint256 largeResult = vault.getTokenUSDValueExternal(address(usdc), largeAmount);
        assertEq(largeResult, expectedLarge, "Large amount test failed");
        
        console.log("Edge cases passed");
    }
    
    function testStringFormatting() public {
        console.log("=== Testing String Formatting ===");
        
        // Test various USD amounts
        uint256 amount1 = 710000000000000000; // 0.71 USD
        string memory result1 = StringUtils.formatUSDValue(amount1);
        assertEq(result1, "0.71 USD", "Format 0.71 failed");
        
        uint256 amount2 = 71000000000000000000; // 71 USD
        string memory result2 = StringUtils.formatUSDValue(amount2);
        assertEq(result2, "71.00 USD", "Format 71.00 failed");
        
        uint256 amount3 = 2000000000000000000000; // 2000 USD
        string memory result3 = StringUtils.formatUSDValue(amount3);
        assertEq(result3, "2000.00 USD", "Format 2000.00 failed");
        
        console.log("String formatting passed");
    }
    
    function testDecimalValidation() public {
        console.log("=== Testing Decimal Validation ===");
        
        // Test valid decimals
        assertTrue(vault.validateTokenDecimals(address(usdc)), "USDC validation failed");
        assertTrue(vault.validateTokenDecimals(address(weth)), "WETH validation failed");
        assertTrue(feeBattle.validateTokenDecimals(address(usdc)), "FeeBattle USDC validation failed");
        
        console.log("Decimal validation passed");
    }
    
    function testCrossContractConsistency() public {
        console.log("=== Testing Cross-Contract Consistency ===");

        uint256[] memory testAmounts = new uint256[](3);
        testAmounts[0] = 1000000; // 1 USDC (6 decimals)
        testAmounts[1] = 1000000; // 1 USDT (6 decimals)
        testAmounts[2] = 1e18; // 1 DAI (18 decimals)

        address[] memory testTokens = new address[](3);
        testTokens[0] = address(usdc);
        testTokens[1] = address(usdt);
        testTokens[2] = address(dai);

        for (uint i = 0; i < testAmounts.length; i++) {
            uint256 vaultResult = vault.getTokenUSDValueExternal(testTokens[i], testAmounts[i]);
            uint256 feeResult = feeBattle.getTokenUSDValueExternal(testTokens[i], testAmounts[i]);

            assertEq(vaultResult, feeResult, "Cross-contract consistency failed");
        }

        console.log("Cross-contract consistency passed");
    }
}

// Mock ERC20 token for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
}
