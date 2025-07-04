// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LPBattleVault.sol";
import "../src/libraries/PoolUtils.sol";
import "../src/libraries/TransferUtils.sol";
import "../src/libraries/StringUtils.sol";

contract DeployLPBattleVault is Script {
    // Sepolia addresses
    address public constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    address public constant FACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    
    function run() external returns (LPBattleVault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy libraries first (these are automatically linked)
        console.log("Deploying libraries...");
        
        // Deploy LPBattleVault contract (libraries will be linked automatically)
        LPBattleVault vault = new LPBattleVault(POSITION_MANAGER, FACTORY);
        
        console.log("=== Deployment Complete ===");
        console.log("LPBattleVault deployed at:", address(vault));
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Factory:", FACTORY);
        console.log("Network: Sepolia");
        
        // Setup initial stablecoins
        console.log("Setting up stablecoins...");
        vault.setStablecoin(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, true); // WETH (for testing)
        vault.setStablecoin(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, true); // USDC
        
        console.log("=== Setup Complete ===");
        
        vm.stopBroadcast();
        
        return vault;
    }
}