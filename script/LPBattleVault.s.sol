// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LPBattleVault.sol";

interface IPositionManager {
    function approve(address to, uint256 tokenId) external;
}

contract LPBattleVaultScript is Script {
    // Monad Testnet addresses
    address public constant POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address public constant FACTORY = 0x961235a9020B05C44DF1026D956D1F4D78014276;
    address public constant BATTLE_CONTRACT = 0xde196Dd5e1ce9a9872b6d44794eEB3F1B4AF28b4; // Previously deployed
    uint256 public constant TOKEN_ID = 65217; // your LP NFT tokenId

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Option 1: Deploy new LPBattleVault
        deployVault();
        
        // Option 2: Approve existing contract to use your LP NFT
        // approveExistingContract();

        vm.stopBroadcast();
    }
    
    function deployVault() public returns (LPBattleVault) {
        console.log("Deploying LPBattleVault...");
        
        LPBattleVault vault = new LPBattleVault(POSITION_MANAGER, FACTORY);
        
        console.log("LPBattleVault deployed at:", address(vault));
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Factory:", FACTORY);
        
        return vault;
    }
    
    function approveExistingContract() public {
        console.log("Approving existing contract to use LP NFT...");
        console.log("Contract:", BATTLE_CONTRACT);
        console.log("Token ID:", TOKEN_ID);
        
        IPositionManager(POSITION_MANAGER).approve(BATTLE_CONTRACT, TOKEN_ID);
        
        console.log("Approval granted successfully");
    }
}
