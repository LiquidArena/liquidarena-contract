// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LPBattleVault.sol";

contract DeployLPBattleVault is Script {
    // Monad Testnet addresses
    address public constant POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address public constant FACTORY = 0x961235a9020B05C44DF1026D956D1F4D78014276;
    
    function run() external returns (LPBattleVault) {
        vm.startBroadcast();
        
        // Deploy LPBattleVault contract
        LPBattleVault vault = new LPBattleVault(POSITION_MANAGER, FACTORY);
        
        console.log("LPBattleVault deployed at:", address(vault));
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Factory:", FACTORY);
        
        vm.stopBroadcast();
        
        return vault;
    }
}