// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockPriceFeed {
    int256 public price;
    uint256 public updatedAt;
    uint8 public decimals;

    constructor(uint8 _decimals, int256 _price) {
        decimals = _decimals;
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound) {
        return (1, price, block.timestamp, updatedAt, 1);
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function setPriceWithTimestamp(int256 _price, uint256 _timestamp) external {
        price = _price;
        updatedAt = _timestamp;
    }
}