// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
     * @param raw The raw USD value (with 18 decimal places)
     * @return Formatted string like "123.45 USD"
     */
    function formatUSDValue(uint256 raw) external pure returns (string memory) {
        // Convert from 18 decimals to dollars and cents
        uint256 dollars = raw / 1e18;
        uint256 cents = (raw % 1e18) / 1e16; // Get 2 decimal places for cents

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

    /**
     * @dev Helper function to format USD values with more precision (4 decimal places)
     * @param raw The raw USD value (with 18 decimal places)
     * @return Formatted string like "123.4567 USD"
     */
    function formatUSDValuePrecise(uint256 raw) external pure returns (string memory) {
        // Convert from 18 decimals to dollars and 4 decimal places
        uint256 dollars = raw / 1e18;
        uint256 decimals = (raw % 1e18) / 1e14; // Get 4 decimal places

        return string(
            abi.encodePacked(
                _uint2str(dollars),
                ".",
                decimals < 1000 ? "0" : "",
                decimals < 100 ? "0" : "",
                decimals < 10 ? "0" : "",
                _uint2str(decimals),
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