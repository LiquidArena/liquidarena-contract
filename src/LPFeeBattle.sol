// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IShared.sol";


contract LPFeeBattle is IERC721Receiver {
    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public factory;
    
    address public owner;
    mapping(address => bool) public stablecoins;

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
    
    uint256 public constant RESOLVER_REWARD_BPS = 100; // 1% in basis points
    uint256 public constant MIN_BATTLE_DURATION = 1 hours; // Minimum battle duration

    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId);
    event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId);
    event BattleResolved(uint256 indexed battleId, address indexed winner);
    event StablecoinSet(address indexed token, bool isStablecoin);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _positionManager, address _factory) {
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = IUniswapV3Factory(_factory);
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setStablecoin(address token, bool isStablecoin) external onlyOwner {
        stablecoins[token] = isStablecoin;
        emit StablecoinSet(token, isStablecoin);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
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

        // Calculate token amounts from liquidity
        uint256 amount0 = uint256(liquidity) * 1e18 / uint256(sqrtPriceX96);
        uint256 amount1 = uint256(liquidity) * uint256(sqrtPriceX96) / 1e18;

        // Use pool-based pricing instead of oracles
        usdValue = calculatePoolBasedValue(token0, token1, amount0, amount1, sqrtPriceX96);
    }

    function convertFeesToUSD(uint256 amount0, uint256 amount1, address token0, address token1) 
        internal 
        view 
        returns (uint256 usdValue) 
    {
        // Get current pool price for conversion
        address pool = factory.getPool(token0, token1, 3000); // Assume 0.3% fee pool for price reference
        if (pool == address(0)) {
            pool = factory.getPool(token0, token1, 500); // Try 0.05% fee pool
        }
        if (pool == address(0)) {
            pool = factory.getPool(token0, token1, 10000); // Try 1% fee pool
        }
        
        if (pool != address(0)) {
            (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            usdValue = calculatePoolBasedValue(token0, token1, amount0, amount1, sqrtPriceX96);
        } else {
            // Fallback: assume both tokens have equal value for relative comparison
            usdValue = amount0 + amount1;
        }
    }
    
    function calculatePoolBasedValue(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96
    ) internal view returns (uint256 usdValue) {
        bool token0IsStable = stablecoins[token0];
        bool token1IsStable = stablecoins[token1];
        
        if (token0IsStable && token1IsStable) {
            // Both stablecoins - treat as 1:1 USD (no decimals adjustment for tests)
            usdValue = amount0 + amount1;
        } else if (token0IsStable) {
            // Token0 is stable - use it as USD reference
            uint256 token0ValueUSD = amount0;
            uint256 token1ValueInToken0 = (amount1 * uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1e36);
            usdValue = token0ValueUSD + token1ValueInToken0;
        } else if (token1IsStable) {
            // Token1 is stable - use it as USD reference  
            uint256 token1ValueUSD = amount1;
            uint256 token0ValueInToken1 = (amount0 * 1e36) / (uint256(sqrtPriceX96) * uint256(sqrtPriceX96));
            usdValue = token0ValueInToken1 + token1ValueUSD;
        } else {
            // Neither token is stable - use pool ratio for relative valuation
            // Convert everything to token1 terms for comparison
            uint256 token0InToken1Terms = (amount0 * uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1e36);
            usdValue = amount1 + token0InToken1Terms;
        }
    }

    function createBattle(uint256 tokenId, uint256 duration) external returns (uint256) {
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");
        require(duration >= MIN_BATTLE_DURATION, "Battle duration too short");
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

        (,, address token0, address token1,,,,,,, uint128 newCreatorFee0, uint128 newCreatorFee1) = positionManager.positions(b.creatorTokenId);
        (,,,,,,,,,, uint128 newOpponentFee0, uint128 newOpponentFee1) = positionManager.positions(b.opponentTokenId);

        // Calculate fee growth in USD
        uint256 creatorFeeGrowthUSD = convertFeesToUSD(
            newCreatorFee0 - b.creatorStartFee0,
            newCreatorFee1 - b.creatorStartFee1,
            token0,
            token1
        );
        
        uint256 opponentFeeGrowthUSD = convertFeesToUSD(
            newOpponentFee0 - b.opponentStartFee0,
            newOpponentFee1 - b.opponentStartFee1,
            token0,
            token1
        );

        // Calculate fee rates (fee growth / LP value) for fair comparison
        // Use higher precision to avoid zero results
        uint256 creatorFeeRate = b.creatorLPValue > 0 ? (creatorFeeGrowthUSD * 1e24) / b.creatorLPValue : 0;
        
        // Get opponent LP value for rate calculation
        uint256 opponentLPValue = getLPTokenValueUSD(b.opponentTokenId);
        uint256 opponentFeeRate = opponentLPValue > 0 ? (opponentFeeGrowthUSD * 1e24) / opponentLPValue : 0;

        address winner = creatorFeeRate >= opponentFeeRate ? b.creator : b.opponent;
        b.winner = winner;
        b.isResolved = true;

        // Collect fees from both positions first to this contract
        (uint256 creatorAmount0, uint256 creatorAmount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: b.creatorTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        
        (uint256 opponentAmount0, uint256 opponentAmount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: b.opponentTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Calculate resolver reward (1% of total fees collected)
        uint256 totalAmount0 = creatorAmount0 + opponentAmount0;
        uint256 totalAmount1 = creatorAmount1 + opponentAmount1;
        
        uint256 resolverReward0 = (totalAmount0 * RESOLVER_REWARD_BPS) / 10000;
        uint256 resolverReward1 = (totalAmount1 * RESOLVER_REWARD_BPS) / 10000;
        
        // Transfer resolver reward to msg.sender
        if (resolverReward0 > 0) {
            IERC20(token0).transfer(msg.sender, resolverReward0);
        }
        if (resolverReward1 > 0) {
            IERC20(token1).transfer(msg.sender, resolverReward1);
        }
        
        // Transfer remaining fees to winner
        uint256 remainingAmount0 = totalAmount0 - resolverReward0;
        uint256 remainingAmount1 = totalAmount1 - resolverReward1;
        
        if (remainingAmount0 > 0) {
            IERC20(token0).transfer(winner, remainingAmount0);
        }
        if (remainingAmount1 > 0) {
            IERC20(token1).transfer(winner, remainingAmount1);
        }

        // Return NFTs to original owners
        positionManager.safeTransferFrom(address(this), b.creator, b.creatorTokenId);
        positionManager.safeTransferFrom(address(this), b.opponent, b.opponentTokenId);

        emit BattleResolved(battleId, winner);
    }

    // Frontend Helper Functions

    function getBattleDetails(uint256 battleId) 
        external 
        view 
        returns (
            address creator,
            address opponent,
            uint256 creatorTokenId,
            uint256 opponentTokenId,
            bool isResolved,
            address winner,
            uint256 startTime,
            uint256 duration,
            uint256 creatorLPValueUSD,
            string memory status
        ) 
    {
        Battle memory b = battles[battleId];
        creator = b.creator;
        opponent = b.opponent;
        creatorTokenId = b.creatorTokenId;
        opponentTokenId = b.opponentTokenId;
        isResolved = b.isResolved;
        winner = b.winner;
        startTime = b.startTime;
        duration = b.duration;
        creatorLPValueUSD = b.creatorLPValue;
        status = getBattleStatus(battleId);
    }

    function getBattleStatus(uint256 battleId) public view returns (string memory) {
        Battle memory b = battles[battleId];
        
        if (b.isResolved) {
            return "resolved";
        } else if (b.opponent == address(0)) {
            return "waiting_for_opponent";
        } else if (b.startTime == 0) {
            return "joined_not_started";
        } else if (block.timestamp >= battleStart[battleId]) {
            return "ready_to_resolve";
        } else {
            return "ongoing";
        }
    }

    function getTimeRemaining(uint256 battleId) external view returns (uint256) {
        if (battles[battleId].isResolved || battles[battleId].opponent == address(0)) {
            return 0;
        }
        
        uint256 endTime = battleStart[battleId];
        if (block.timestamp >= endTime) {
            return 0;
        }
        
        return endTime - block.timestamp;
    }

    function getCurrentFeePerformance(uint256 battleId) 
        external 
        view 
        returns (
            uint256 creatorFeeGrowthUSD,
            uint256 opponentFeeGrowthUSD,
            uint256 creatorFeeRate,
            uint256 opponentFeeRate,
            address currentLeader
        ) 
    {
        Battle memory b = battles[battleId];
        require(b.opponent != address(0), "Battle not started");
        
        if (b.isResolved) {
            return (0, 0, 0, 0, b.winner);
        }

        (,, address token0, address token1,,,,,,, uint128 newCreatorFee0, uint128 newCreatorFee1) = positionManager.positions(b.creatorTokenId);
        (,,,,,,,,,, uint128 newOpponentFee0, uint128 newOpponentFee1) = positionManager.positions(b.opponentTokenId);

        creatorFeeGrowthUSD = convertFeesToUSD(
            newCreatorFee0 - b.creatorStartFee0,
            newCreatorFee1 - b.creatorStartFee1,
            token0,
            token1
        );
        
        opponentFeeGrowthUSD = convertFeesToUSD(
            newOpponentFee0 - b.opponentStartFee0,
            newOpponentFee1 - b.opponentStartFee1,
            token0,
            token1
        );

        creatorFeeRate = b.creatorLPValue > 0 ? (creatorFeeGrowthUSD * 1e24) / b.creatorLPValue : 0;
        uint256 opponentLPValue = getLPTokenValueUSD(b.opponentTokenId);
        opponentFeeRate = opponentLPValue > 0 ? (opponentFeeGrowthUSD * 1e24) / opponentLPValue : 0;

        currentLeader = creatorFeeRate >= opponentFeeRate ? b.creator : b.opponent;
    }

    function getAllActiveBattles() 
        external 
        view 
        returns (uint256[] memory battleIds, string[] memory statuses) 
    {
        uint256 activeCount = 0;
        
        // Count active battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (!battles[i].isResolved) {
                activeCount++;
            }
        }
        
        battleIds = new uint256[](activeCount);
        statuses = new string[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (!battles[i].isResolved) {
                battleIds[index] = i;
                statuses[index] = getBattleStatus(i);
                index++;
            }
        }
    }

    function getBattlesWaitingForOpponent() 
        external 
        view 
        returns (uint256[] memory battleIds) 
    {
        uint256 waitingCount = 0;
        
        // Count waiting battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (!battles[i].isResolved && battles[i].opponent == address(0)) {
                waitingCount++;
            }
        }
        
        battleIds = new uint256[](waitingCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (!battles[i].isResolved && battles[i].opponent == address(0)) {
                battleIds[index] = i;
                index++;
            }
        }
    }

    function getBattlesReadyToResolve() 
        external 
        view 
        returns (uint256[] memory battleIds) 
    {
        uint256 readyCount = 0;
        
        // Count ready battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            Battle memory b = battles[i];
            if (!b.isResolved && b.opponent != address(0) && block.timestamp >= battleStart[i]) {
                readyCount++;
            }
        }
        
        battleIds = new uint256[](readyCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < battleIdCounter; i++) {
            Battle memory b = battles[i];
            if (!b.isResolved && b.opponent != address(0) && block.timestamp >= battleStart[i]) {
                battleIds[index] = i;
                index++;
            }
        }
    }

    function getUserBattles(address user) 
        external 
        view 
        returns (uint256[] memory battleIds, bool[] memory isCreator) 
    {
        uint256 userBattleCount = 0;
        
        // Count user battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (battles[i].creator == user || battles[i].opponent == user) {
                userBattleCount++;
            }
        }
        
        battleIds = new uint256[](userBattleCount);
        isCreator = new bool[](userBattleCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < battleIdCounter; i++) {
            if (battles[i].creator == user || battles[i].opponent == user) {
                battleIds[index] = i;
                isCreator[index] = (battles[i].creator == user);
                index++;
            }
        }
    }

    function getBattleTokenInfo(uint256 battleId) 
        external 
        view 
        returns (
            address token0,
            address token1,
            uint24 fee,
            string memory poolName
        ) 
    {
        Battle memory b = battles[battleId];
        require(b.creator != address(0), "Battle does not exist");
        
        (,, token0, token1, fee,,,,,,,) = positionManager.positions(b.creatorTokenId);
        
        // Simple pool name (you might want to get actual token symbols from token contracts)
        poolName = string(abi.encodePacked("Pool-", uint2str(fee / 100), "bps"));
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
}
