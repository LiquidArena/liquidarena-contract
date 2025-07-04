// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Script.sol";
// import "forge-std/console.sol";
// import "../src/LPBattleVault.sol";
// import "../src/MockPriceFeed.sol";

// contract DemoPriceFeed is Script {
//     // Demo addresses
//     address constant DEMO_OWNER = 0x1234567890123456789012345678901234567890;
//     address constant DEMO_USER = 0x2345678901234567890123456789012345678901;
    
//     // Mock tokens
//     address constant WETH = 0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37;
//     address constant USDC = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;
    
//     function run() external {
//         // Start broadcast with demo owner
//         vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
//         console.log("=== LiquidArena Price Feed Demo ===");
        
//         // 1. Deploy mock price feeds
//         console.log("\nDeploying mock price feeds...");
//         MockPriceFeed ethFeed = new MockPriceFeed(8, 2000 * 1e8); // $2000 ETH
//         MockPriceFeed usdcFeed = new MockPriceFeed(8, 1 * 1e8);   // $1 USDC
        
//         console.log("ETH Feed deployed at:", address(ethFeed));
//         console.log("USDC Feed deployed at:", address(usdcFeed));
        
//         // 2. Deploy LPBattleVault with mock position manager and factory
//         console.log("\nDeploying LPBattleVault...");
//         // For demo, we can use any address as position manager and factory
//         LPBattleVault vault = new LPBattleVault(DEMO_OWNER, DEMO_OWNER);
//         console.log("LPBattleVault deployed at:", address(vault));
        
//         // 3. Set price feeds
//         console.log("\nSetting price feeds...");
//         vault.setPriceFeed(WETH, address(ethFeed));
//         vault.setPriceFeed(USDC, address(usdcFeed));
//         console.log("Price feeds set for WETH and USDC");
        
//         // 4. Demo price staleness check
//         console.log("\n=== Price Staleness Demo ===");
        
//         // Current timestamp
//         uint256 currentTime = block.timestamp;
//         console.log("Current timestamp:", currentTime);
        
//         // Set ETH price with current timestamp
//         ethFeed.setPriceWithTimestamp(2000 * 1e8, currentTime);
//         console.log("ETH price updated at current time");
        
//         // Try to get token value (should work)
//         try this.getTokenValue(address(vault), WETH, 1e18) returns (uint256 value) {
//             console.log("ETH value (1 ETH):", value / 1e8, "USD");
//         } catch Error(string memory reason) {
//             console.log("Error:", reason);
//         }
        
//         // Set ETH price with stale timestamp (6 hours ago)
//         ethFeed.setPriceWithTimestamp(2100 * 1e8, currentTime - 6 hours);
//         console.log("\nETH price updated 6 hours ago (beyond 5-hour threshold)");
        
//         // Try to get token value (should fail due to staleness)
//         try this.getTokenValue(address(vault), WETH, 1e18) returns (uint256 value) {
//             console.log("ETH value (1 ETH):", value / 1e8, "USD");
//         } catch Error(string memory reason) {
//             console.log("Error:", reason);
//         } catch (bytes memory) {
//             console.log("Error: StalePrice (price feed update too old)");
//         }
        
//         // Set ETH price with acceptable timestamp (4 hours ago)
//         ethFeed.setPriceWithTimestamp(2200 * 1e8, currentTime - 4 hours);
//         console.log("\nETH price updated 4 hours ago (within 5-hour threshold)");
        
//         // Try to get token value (should work)
//         try this.getTokenValue(address(vault), WETH, 1e18) returns (uint256 value) {
//             console.log("ETH value (1 ETH):", value / 1e8, "USD");
//         } catch Error(string memory reason) {
//             console.log("Error:", reason);
//         }
        
//         vm.stopBroadcast();
//     }
    
//     // Helper function to call getTokenUSDValue (needs to be external for try/catch)
//     function getTokenValue(address vault, address token, uint256 amount) external returns (uint256) {
//         // This is a simplified version - you'll need to expose this function in your contract
//         return LPBattleVault(vault).getTokenUSDValueExternal(token, amount);
//     }
// }