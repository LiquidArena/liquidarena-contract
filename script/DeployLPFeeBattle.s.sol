// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LPFeeBattle.sol";

contract DeployLPFeeBattle is Script {
    // Monad Testnet addresses
    address public constant POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address public constant FACTORY = 0x961235a9020B05C44DF1026D956D1F4D78014276;
    
    function run() external returns (LPFeeBattle) {
        vm.startBroadcast();
        
        // Deploy LPFeeBattle contract
        LPFeeBattle battle = new LPFeeBattle(POSITION_MANAGER, FACTORY);
        
        console.log("LPFeeBattle deployed at:", address(battle));
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Factory:", FACTORY);
        
        vm.stopBroadcast();
        
        return battle;
    }
}