// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IShared.sol";

// PoolUtils Library
library PoolUtils {
    struct PoolData {
        address token0;
        address token1;
        uint24 fee;
        address pool;
        int24 currentTick;
    }

    struct PositionData {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function getPoolData(
        INonfungiblePositionManager positionManager,
        IUniswapV3Factory factory,
        uint256 tokenId
    ) internal view returns (PoolData memory poolData) {
        (,, address token0, address token1, uint24 fee,,,,,,,) = positionManager.positions(tokenId);

        poolData.token0 = token0;
        poolData.token1 = token1;
        poolData.fee = fee;
        poolData.pool = factory.getPool(token0, token1, fee);

        if (poolData.pool != address(0)) {
            (, poolData.currentTick,,,,,) = IUniswapV3PoolState(poolData.pool).slot0();
        }
    }

    function getPositionData(
        INonfungiblePositionManager positionManager,
        uint256 tokenId
    ) internal view returns (PositionData memory posData) {
        (
            ,
            ,
            posData.token0,
            posData.token1,
            posData.fee,
            posData.tickLower,
            posData.tickUpper,
            posData.liquidity,
            ,
            ,
            posData.tokensOwed0,
            posData.tokensOwed1
        ) = positionManager.positions(tokenId);
    }

    function isInRange(int24 currentTick, int24 tickLower, int24 tickUpper)
        internal
        pure
        returns (bool)
    {
        return currentTick >= tickLower && currentTick <= tickUpper;
    }

    function getTotalFees(uint128 tokensOwed0, uint128 tokensOwed1)
        internal
        pure
        returns (uint256)
    {
        return uint256(tokensOwed0) + uint256(tokensOwed1);
    }

    function calculateResolverReward(uint256 amount, uint256 basisPoints)
        internal
        pure
        returns (uint256)
    {
        return (amount * basisPoints) / 10000;
    }
}