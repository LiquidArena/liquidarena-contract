// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface INonfungiblePositionManager {
    function approve(address to, uint256 tokenId) external;
}

contract ApproveLPBattle is Script {
    address public constant POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address public constant BATTLE_CONTRACT = 0xf561672007c37786c4D7D16BEEDbA2EA36b459A0;
    uint256 public constant TOKEN_ID = 65217; // your LP NFT tokenId

    function run() external {
        vm.startBroadcast(); // broadcast tx using your private key

        INonfungiblePositionManager(POSITION_MANAGER).approve(BATTLE_CONTRACT, TOKEN_ID);

        vm.stopBroadcast();
    }
}