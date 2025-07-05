// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Shared Errors //
error NotOwner();
error NotLPOwner();
error InvalidOwner();
error PoolNotFound();
error BattleAlreadyJoined();
error AlreadyResolved();
error BattleAlreadyResolved();
error BattleNotEnded();
error BattleNotStarted();
error LPValueNotWithinTolerance();
error NoOpponentJoined();
error InvalidCreatorPool();
error InvalidOpponentPool();
error BattleDoesNotExist();
error PriceFeedNotSet();
error StalePrice();

error BattleDurationTooShort(uint256 provided, uint256 minimum);
error BattleDurationTooLong(uint256 provided, uint256 maximum);
error PriceTooStale(uint256 age, uint256 threshold);
error InsufficientLPValue(uint256 provided, uint256 required);
error InvalidTokenId(uint256 tokenId);
error ZeroAddress();
error InvalidBattleId(uint256 battleId);
error BattleExpired(uint256 battleId, uint256 expiredAt);
error UnauthorizedResolver(address caller);
error InvalidPriceFeed(address token, address priceFeed);
error TokenNotSupported(address token);
error InvalidFeeAmount(uint256 amount);
error ContractPaused();
error InsufficientBalance(address token, uint256 required, uint256 available);
error BattleNotExpiredForEmergencyWithdrawal();

// UNISWAP INTERFACES //

// Uniswap Non-Fungible Position Manager Interface
interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function ownerOf(uint256 tokenId) external view returns (address);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function collect(CollectParams calldata params) external returns (uint256 amount0, uint256 amount1);
}

// Uniswap V3 Pool State Interface
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

// Uniswap V3 Pool State Interface
interface IUniswapV3PoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

// Chainlink Price Feed Interface
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}