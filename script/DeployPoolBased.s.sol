// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";

/**
 * @title DeployPoolBased
 * @dev Simple deployment script for pool-based pricing system
 */
contract DeployPoolBased is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Monad Testnet addresses
        address POSITION_MANAGER = vm.envOr("POSITION_MANAGER", 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7);
        address FACTORY = vm.envOr("FACTORY", 0x961235a9020B05C44DF1026D956D1F4D78014276);
        
        // Common stablecoin addresses (update with actual Monad testnet addresses)
        address USDC = vm.envOr("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        address USDT = vm.envOr("USDT", 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying LP Battle System with Pool-Based Pricing ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Factory:", FACTORY);
        
        // Deploy main contracts
        console.log("\n=== Deploying Main Contracts ===");
        
        LPBattleVault vault = new LPBattleVault(POSITION_MANAGER, FACTORY);
        console.log("LPBattleVault deployed at:", address(vault));
        
        LPFeeBattle feeBattle = new LPFeeBattle(POSITION_MANAGER, FACTORY);
        console.log("LPFeeBattle deployed at:", address(feeBattle));
        
        // Configure stablecoins
        console.log("\n=== Configuring Stablecoins ===");
        
        if (USDC != address(0)) {
            vault.setStablecoin(USDC, true);
            feeBattle.setStablecoin(USDC, true);
            console.log("USDC configured as stablecoin:", USDC);
        }
        
        if (USDT != address(0)) {
            vault.setStablecoin(USDT, true);
            feeBattle.setStablecoin(USDT, true);
            console.log("USDT configured as stablecoin:", USDT);
        }
        
        vm.stopBroadcast();
        
        // Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("LPBattleVault:", address(vault));
        console.log("LPFeeBattle:", address(feeBattle));
        
        console.log("\n=== Pool-Based Pricing Configured ===");
        console.log("- No external oracles required");
        console.log("- Uses Uniswap V3 pool prices for USD calculations");
        console.log("- Stablecoins configured for USD reference");
        
        // Save addresses to file for frontend use
        string memory addresses = string(abi.encodePacked(
            "# LP Battle System Deployment Addresses (Pool-Based Pricing)\n",
            "LP_BATTLE_VAULT=", vm.toString(address(vault)), "\n",
            "LP_FEE_BATTLE=", vm.toString(address(feeBattle)), "\n",
            "POSITION_MANAGER=", vm.toString(POSITION_MANAGER), "\n",
            "FACTORY=", vm.toString(FACTORY), "\n",
            "USDC=", vm.toString(USDC), "\n",
            "USDT=", vm.toString(USDT), "\n"
        ));
        
        vm.writeFile("deployment-addresses.txt", addresses);
        console.log("\nDeployment addresses saved to: deployment-addresses.txt");
    }
}