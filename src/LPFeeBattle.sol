// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

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
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IUniswapV3Pool {
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

interface IOracle {
    function latestAnswer() external view returns (int256);
}

contract LPFeeBattle is IERC721Receiver {
    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public factory;

    mapping(address => address) public usdOracles;

    struct Battle {
        address creator;
        uint256 creatorTokenId;
        uint256 opponentTokenId;
        address opponent;
        bool isResolved;
        address winner;
        uint256 startTime;
        uint256 duration;
        uint256 creatorStartFee0;
        uint256 creatorStartFee1;
        uint256 opponentStartFee0;
        uint256 opponentStartFee1;
        uint256 creatorLPValue;
    }

    uint256 public battleIdCounter;
    mapping(uint256 => Battle) public battles;
    mapping(uint256 => uint256) public battleStart;

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    constructor(address _positionManager, address _factory) {
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = IUniswapV3Factory(_factory);
    }

    function setOracle(address token, address oracle) external {
        usdOracles[token] = oracle;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function getLPTokenValueUSD(uint256 tokenId) public view returns (uint256 usdValue) {
        (,, address token0, address token1, uint24 fee,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);

        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool not found");

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();

        uint256 amount0 = uint256(liquidity) * 1e18 / uint256(sqrtPriceX96);
        uint256 amount1 = uint256(liquidity) * uint256(sqrtPriceX96) / 1e18;

        bool token0IsStable = usdOracles[token0] == address(0);
        bool token1IsStable = usdOracles[token1] == address(0);

        if (!token0IsStable && usdOracles[token0] != address(0)) {
            uint256 price0 = uint256(IOracle(usdOracles[token0]).latestAnswer());
            usdValue += amount0 * price0 / 1e8;
        }
        if (!token1IsStable && usdOracles[token1] != address(0)) {
            uint256 price1 = uint256(IOracle(usdOracles[token1]).latestAnswer());
            usdValue += amount1 * price1 / 1e8;
        }
        if (token0IsStable) {
            usdValue += amount0 / 1e6;
        }
        if (token1IsStable) {
            usdValue += amount1 / 1e6;
        }
    }

    function createBattle(uint256 tokenId, uint256 duration) external returns (uint256) {
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        (,,,,,,,,,, uint128 owed0, uint128 owed1) = positionManager.positions(tokenId);

        uint256 lpValue = getLPTokenValueUSD(tokenId);

        uint256 battleId = battleIdCounter++;
        battles[battleId] = Battle({
            creator: msg.sender,
            creatorTokenId: tokenId,
            opponentTokenId: 0,
            opponent: address(0),
            isResolved: false,
            winner: address(0),
            startTime: 0,
            duration: duration,
            creatorStartFee0: owed0,
            creatorStartFee1: owed1,
            opponentStartFee0: 0,
            opponentStartFee1: 0,
            creatorLPValue: lpValue
        });

        emit BattleCreated(battleId, msg.sender, tokenId);
        return battleId;
    }

    function joinBattle(uint256 battleId, uint256 tokenId) external {
        Battle storage b = battles[battleId];
        require(b.opponent == address(0), "Already joined");
        require(!b.isResolved, "Already resolved");
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");

        uint256 joinerLPValue = getLPTokenValueUSD(tokenId);
        require(
            joinerLPValue >= (b.creatorLPValue * 95 / 100) && joinerLPValue <= (b.creatorLPValue * 105 / 100),
            "LP Value not within 5% tolerance"
        );

        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);
        (,,,,,,,,,, uint128 owed0, uint128 owed1) = positionManager.positions(tokenId);

        battleStart[battleId] = block.timestamp + b.duration;
        b.opponent = msg.sender;
        b.opponentTokenId = tokenId;
        b.opponentStartFee0 = owed0;
        b.opponentStartFee1 = owed1;
        b.startTime = block.timestamp;

        emit BattleJoined(battleId, msg.sender, tokenId);
    }

    function resolveBattle(uint256 battleId) external {
        Battle storage b = battles[battleId];
        require(!b.isResolved, "Already resolved");
        require(b.opponent != address(0), "Not started");
        require(block.timestamp >= battleStart[battleId], "Not finished");

        (,,,,,,,,,, uint128 newCreatorFee0, uint128 newCreatorFee1) = positionManager.positions(b.creatorTokenId);
        (,,,,,,,,,, uint128 newOpponentFee0, uint128 newOpponentFee1) = positionManager.positions(b.opponentTokenId);

        uint256 creatorFeeGrowth = (newCreatorFee0 - b.creatorStartFee0) + (newCreatorFee1 - b.creatorStartFee1);
        uint256 opponentFeeGrowth = (newOpponentFee0 - b.opponentStartFee0) + (newOpponentFee1 - b.opponentStartFee1);

        address winner = creatorFeeGrowth >= opponentFeeGrowth ? b.creator : b.opponent;
        b.winner = winner;
        b.isResolved = true;

        positionManager.safeTransferFrom(address(this), winner, b.creatorTokenId);
        positionManager.safeTransferFrom(address(this), winner, b.opponentTokenId);

        emit BattleResolved(battleId, winner);
    }
}
