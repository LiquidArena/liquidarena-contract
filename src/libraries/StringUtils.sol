// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringUtils {
    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     * @param _i The integer to convert
     * @return str The string representation
     */
    function uint2str(uint256 _i) external pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }
    
    /**
     * @dev Helper function to format USD values with decimal places
     * @param raw The raw USD value (with 8 decimal places)
     * @return Formatted string like "123.45 USD"
     */
    function formatUSDValue(uint256 raw) external pure returns (string memory) {
        uint256 dollars = raw / 1e8;
        uint256 cents = (raw % 1e8) / 1e6;

        return string(
            abi.encodePacked(
                _uint2str(dollars),
                ".",
                cents < 10 ? "0" : "", // pad single digit cents
                _uint2str(cents),
                " USD"
            )
        );
    }
    
    function _uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }

}