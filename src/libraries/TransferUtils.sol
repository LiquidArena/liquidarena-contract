// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TransferUtils {
    struct TokenTransfer {
        address token;
        address to;
        uint256 amount;
    }

    function batchTransfer(TokenTransfer[] memory transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            if (transfers[i].amount > 0) {
                IERC20(transfers[i].token).transfer(transfers[i].to, transfers[i].amount);
            }
        }
    }

    function safeTransferIfNonZero(address token, address to, uint256 amount) internal {
        if (amount > 0) {
            IERC20(token).transfer(to, amount);
        }
    }
}