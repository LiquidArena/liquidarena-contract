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

    function positions(
        uint256 tokenId
    )
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

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function collect(
        CollectParams calldata params
    ) external returns (uint256 amount0, uint256 amount1);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address);
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

contract LPBattleVault is IERC721Receiver {
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
        int24 creatorTickLower;
        int24 creatorTickUpper;
        int24 opponentTickLower;
        int24 opponentTickUpper;
        uint256 totalValueUSD;
    }

    uint256 public battleIdCounter;
    mapping(uint256 => Battle) public battles;
    mapping(uint256 => uint256) public battleStart;

    event BattleCreated(
        uint256 indexed battleId,
        address indexed creator,
        uint256 creatorTokenId
    );
    event BattleJoined(
        uint256 indexed battleId,
        address indexed opponent,
        uint256 opponentTokenId
    );
    event BattleResolved(uint256 indexed battleId, address indexed winner);

    constructor(address _positionManager, address _factory) {
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = IUniswapV3Factory(_factory);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setOracle(address token, address oracle) external {
        usdOracles[token] = oracle;
    }

    function getLPTokenValueUSD(
        uint256 tokenId
    ) public view returns (uint256 amount0, uint256 amount1, uint256 usdValue) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenId);

        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool not found");

        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

        amount0 = (uint256(liquidity) * 1e18) / uint256(sqrtPriceX96);
        amount1 = (uint256(liquidity) * uint256(sqrtPriceX96)) / 1e18;

        bool token0IsStable = usdOracles[token0] == address(0);
        bool token1IsStable = usdOracles[token1] == address(0);

        if (!token0IsStable && usdOracles[token0] != address(0)) {
            uint256 price0 = uint256(
                IOracle(usdOracles[token0]).latestAnswer()
            );
            usdValue += (amount0 * price0) / 1e8;
        }
        if (!token1IsStable && usdOracles[token1] != address(0)) {
            uint256 price1 = uint256(
                IOracle(usdOracles[token1]).latestAnswer()
            );
            usdValue += (amount1 * price1) / 1e8;
        }

        if (token0IsStable) {
            usdValue += amount0 / 1e6;
        }
        if (token1IsStable) {
            usdValue += amount1 / 1e6;
        }
    }

    function createBattle(
        uint256 tokenId,
        uint256 durations
    ) external returns (uint256) {
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        (, , uint256 usdValue) = getLPTokenValueUSD(tokenId);

        (, , , , , int24 tickLower, int24 tickUpper, , , , , ) = positionManager
            .positions(tokenId);

        uint256 battleId = battleIdCounter++;
        battles[battleId] = Battle({
            creator: msg.sender,
            creatorTokenId: tokenId,
            opponentTokenId: 0,
            opponent: address(0),
            isResolved: false,
            winner: address(0),
            startTime: 0,
            duration: durations,
            creatorTickLower: tickLower,
            creatorTickUpper: tickUpper,
            opponentTickLower: 0,
            opponentTickUpper: 0,
            totalValueUSD: usdValue
        });

        emit BattleCreated(battleId, msg.sender, tokenId);
        return battleId;
    }

    function joinBattle(uint256 battleId, uint256 opponentTokenId) external {
        require(
            positionManager.ownerOf(opponentTokenId) == msg.sender,
            "Not LP owner"
        );
        Battle storage b = battles[battleId];
        require(!b.isResolved, "Battle already resolved");
        require(b.opponent == address(0), "Battle already joined");

        (, , uint256 opponentValueUSD) = getLPTokenValueUSD(opponentTokenId);
        require(
            opponentValueUSD >= ((b.totalValueUSD * 95) / 100) &&
                opponentValueUSD <= ((b.totalValueUSD * 105) / 100),
            "LP value not within 5% tolerance"
        );

        positionManager.safeTransferFrom(
            msg.sender,
            address(this),
            opponentTokenId
        );

        (
            ,
            ,
            ,
            ,
            ,
            int24 oppTickLower,
            int24 oppTickUpper,
            ,
            ,
            ,
            ,

        ) = positionManager.positions(opponentTokenId);

        battleStart[battleId] = block.timestamp + b.duration;
        b.opponent = msg.sender;
        b.opponentTokenId = opponentTokenId;
        b.startTime = block.timestamp;
        b.opponentTickLower = oppTickLower;
        b.opponentTickUpper = oppTickUpper;

        emit BattleJoined(battleId, msg.sender, opponentTokenId);
    }

    function resolveBattle(uint256 battleId) external {
        Battle storage b = battles[battleId];
        require(!b.isResolved, "Already resolved");
        require(b.opponent != address(0), "No opponent joined");
        require(block.timestamp >= battleStart[battleId], "Battle not ended");

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = positionManager.positions(b.creatorTokenId);

        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Invalid pool");

        (, int24 currentTick, , , , , ) = IUniswapV3Pool(pool).slot0();

        bool creatorInRange = currentTick >= b.creatorTickLower &&
            currentTick <= b.creatorTickUpper;
        bool opponentInRange = currentTick >= b.opponentTickLower &&
            currentTick <= b.opponentTickUpper;

        address winner;
        if (creatorInRange && !opponentInRange) {
            winner = b.creator;
        } else if (!creatorInRange && opponentInRange) {
            winner = b.opponent;
        } else {
            winner = address(0); // optional: can handle draw
        }

        // Collect fees from both NFTs
        INonfungiblePositionManager.CollectParams
            memory paramsCreator = INonfungiblePositionManager.CollectParams({
                tokenId: b.creatorTokenId,
                recipient: winner,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        INonfungiblePositionManager.CollectParams
            memory paramsOpponent = INonfungiblePositionManager.CollectParams({
                tokenId: b.opponentTokenId,
                recipient: winner,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        positionManager.collect(paramsCreator);
        positionManager.collect(paramsOpponent);

        // Return NFTs to original owners
        positionManager.safeTransferFrom(
            address(this),
            b.creator,
            b.creatorTokenId
        );
        positionManager.safeTransferFrom(
            address(this),
            b.opponent,
            b.opponentTokenId
        );

        b.isResolved = true;
        b.winner = winner;

        emit BattleResolved(battleId, winner);
    }

    function uint2str(uint256 _i) internal pure returns (string memory str) {
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

    function getBattleUSDValue(
        uint256 battleId
    ) external view returns (string memory) {
        uint256 raw = battles[battleId].totalValueUSD;
        uint256 dollars = raw / 1e8;
        uint256 cents = (raw % 1e8) / 1e6;

        return
            string(
                abi.encodePacked(
                    uint2str(dollars),
                    ".",
                    cents < 10 ? "0" : "", // pad single digit cents
                    uint2str(cents),
                    " USD"
                )
            );
    }

    function getBattleStatus(
        uint256 battleId
    ) external view returns (string memory) {
        Battle memory b = battles[battleId];

        if (b.isResolved) {
            return "ended";
        } else if (b.opponent == address(0)) {
            return "queued";
        } else if (block.timestamp < battleStart[battleId]) {
            return "onGoing";
        } else {
            return "readyToResolve";
        }
    }

    function getBattleDetails(
        uint256 battleId
    )
        external
        view
        returns (
            address creator,
            address opponent,
            uint256 usdValue,
            string memory status
        )
    {
        Battle memory b = battles[battleId];
        creator = b.creator;
        opponent = b.opponent;
        usdValue = b.totalValueUSD;
        status = b.isResolved ? "ended" : b.opponent == address(0)
            ? "queued"
            : block.timestamp < battleStart[battleId]
            ? "onGoing"
            : "readyToResolve";
    }
}
