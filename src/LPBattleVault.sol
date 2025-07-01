// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IShared.sol";


contract LPBattleVault is IERC721Receiver {
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
        int24 creatorTickLower;
        int24 creatorTickUpper;
        int24 opponentTickLower;
        int24 opponentTickUpper;
        uint256 totalValueUSD;
    }

    uint256 public battleIdCounter;
    mapping(uint256 => Battle) public battles;
    mapping(uint256 => uint256) public battleStart;
    
    uint256 public constant RESOLVER_REWARD_BPS = 100; // 1% in basis points

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

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
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

    function getLPTokenValueUSD(uint256 tokenId)
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 usdValue)
    {
        (,, address token0, address token1, uint24 fee,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);

        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool not found");

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();

        // Calculate token amounts from liquidity
        amount0 = (uint256(liquidity) * 1e18) / uint256(sqrtPriceX96);
        amount1 = (uint256(liquidity) * uint256(sqrtPriceX96)) / 1e18;

        // Use pool-based pricing instead of oracles
        usdValue = calculatePoolBasedValue(token0, token1, amount0, amount1, sqrtPriceX96);
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

    function getFeeEarnings(uint256 tokenId) 
        internal 
        view 
        returns (uint256 fee0, uint256 fee1) 
    {
        (,,,,,,,,,, uint128 tokensOwed0, uint128 tokensOwed1) = positionManager.positions(tokenId);
        
        fee0 = uint256(tokensOwed0);
        fee1 = uint256(tokensOwed1);
    }

    function createBattle(uint256 tokenId, uint256 durations) external returns (uint256) {
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        (,, uint256 usdValue) = getLPTokenValueUSD(tokenId);

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = positionManager.positions(tokenId);

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
        require(positionManager.ownerOf(opponentTokenId) == msg.sender, "Not LP owner");
        Battle storage b = battles[battleId];
        require(!b.isResolved, "Battle already resolved");
        require(b.opponent == address(0), "Battle already joined");

        (,, uint256 opponentValueUSD) = getLPTokenValueUSD(opponentTokenId);
        require(
            opponentValueUSD >= ((b.totalValueUSD * 95) / 100) && opponentValueUSD <= ((b.totalValueUSD * 105) / 100),
            "LP value not within 5% tolerance"
        );

        positionManager.safeTransferFrom(msg.sender, address(this), opponentTokenId);

        (,,,,, int24 oppTickLower, int24 oppTickUpper,,,,,) = positionManager.positions(opponentTokenId);

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

        (,, address token0, address token1, uint24 fee,,,,,,,) = positionManager.positions(b.creatorTokenId);

        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Invalid pool");

        (, int24 currentTick,,,,,) = IUniswapV3Pool(pool).slot0();

        bool creatorInRange = currentTick >= b.creatorTickLower && currentTick <= b.creatorTickUpper;
        bool opponentInRange = currentTick >= b.opponentTickLower && currentTick <= b.opponentTickUpper;

        address winner;
        if (creatorInRange && !opponentInRange) {
            winner = b.creator;
        } else if (!creatorInRange && opponentInRange) {
            winner = b.opponent;
        } else if (creatorInRange && opponentInRange) {
            (uint256 creatorFee0, uint256 creatorFee1) = getFeeEarnings(b.creatorTokenId);
            (uint256 opponentFee0, uint256 opponentFee1) = getFeeEarnings(b.opponentTokenId);
            
            uint256 creatorTotalFees = creatorFee0 + creatorFee1;
            uint256 opponentTotalFees = opponentFee0 + opponentFee1;
            
            if (creatorTotalFees > opponentTotalFees) {
                winner = b.creator;
            } else if (opponentTotalFees > creatorTotalFees) {
                winner = b.opponent;
            } else {
                winner = address(0);
            }
        } else {
            winner = address(0);
        }

        // Collect fees from both positions first
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
        
        // Transfer remaining fees to winner (or split if draw)
        uint256 remainingAmount0 = totalAmount0 - resolverReward0;
        uint256 remainingAmount1 = totalAmount1 - resolverReward1;
        
        if (winner != address(0)) {
            if (remainingAmount0 > 0) {
                IERC20(token0).transfer(winner, remainingAmount0);
            }
            if (remainingAmount1 > 0) {
                IERC20(token1).transfer(winner, remainingAmount1);
            }
        } else {
            // Draw - split remaining fees between both players
            uint256 splitAmount0 = remainingAmount0 / 2;
            uint256 splitAmount1 = remainingAmount1 / 2;
            
            if (splitAmount0 > 0) {
                IERC20(token0).transfer(b.creator, splitAmount0);
                IERC20(token0).transfer(b.opponent, remainingAmount0 - splitAmount0);
            }
            if (splitAmount1 > 0) {
                IERC20(token1).transfer(b.creator, splitAmount1);
                IERC20(token1).transfer(b.opponent, remainingAmount1 - splitAmount1);
            }
        }

        // Return NFTs to original owners
        positionManager.safeTransferFrom(address(this), b.creator, b.creatorTokenId);
        positionManager.safeTransferFrom(address(this), b.opponent, b.opponentTokenId);

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


    function getBattleUSDValue(uint256 battleId) external view returns (string memory) {
        uint256 raw = battles[battleId].totalValueUSD;
        uint256 dollars = raw / 1e8;
        uint256 cents = (raw % 1e8) / 1e6;

        return string(
            abi.encodePacked(
                uint2str(dollars),
                ".",
                cents < 10 ? "0" : "", // pad single digit cents
                uint2str(cents),
                " USD"
            )
        );
    }

    function getBattleStatus(uint256 battleId) external view returns (string memory) {
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

    function getBattleDetails(uint256 battleId)
        external
        view
        returns (address creator, address opponent, uint256 usdValue, string memory status)
    {
        Battle memory b = battles[battleId];
        creator = b.creator;
        opponent = b.opponent;
        usdValue = b.totalValueUSD;
        status = b.isResolved
            ? "ended"
            : b.opponent == address(0) ? "queued" : block.timestamp < battleStart[battleId] ? "onGoing" : "readyToResolve";
    }

    // Frontend Helper Functions

    /**
     * @dev Get comprehensive battle details for frontend
     */
    function getCompleteBattleDetails(uint256 battleId) 
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
            uint256 valueUSD,
            string memory status,
            bool creatorInRange,
            bool opponentInRange,
            int24 currentTick
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
        valueUSD = b.totalValueUSD;
        status = this.getBattleStatus(battleId);
        
        // Get current tick and range status if battle has started
        if (b.opponent != address(0)) {
            (,, address token0, address token1, uint24 fee,,,,,,,) = positionManager.positions(b.creatorTokenId);
            address pool = factory.getPool(token0, token1, fee);
            
            if (pool != address(0)) {
                (, currentTick,,,,,) = IUniswapV3Pool(pool).slot0();
                creatorInRange = currentTick >= b.creatorTickLower && currentTick <= b.creatorTickUpper;
                opponentInRange = currentTick >= b.opponentTickLower && currentTick <= b.opponentTickUpper;
            }
        }
    }

    /**
     * @dev Get time remaining in battle
     */
    function getTimeRemaining(uint256 battleId) external view returns (uint256) {
        Battle memory b = battles[battleId];
        
        if (b.isResolved || b.opponent == address(0)) {
            return 0;
        }
        
        uint256 endTime = battleStart[battleId];
        if (block.timestamp >= endTime) {
            return 0;
        }
        
        return endTime - block.timestamp;
    }

    /**
     * @dev Get current battle performance (who's winning)
     */
    function getCurrentPerformance(uint256 battleId) 
        external 
        view 
        returns (
            bool creatorInRange,
            bool opponentInRange,
            uint256 creatorFees,
            uint256 opponentFees,
            address currentLeader,
            string memory leadReason
        ) 
    {
        Battle memory b = battles[battleId];
        require(b.opponent != address(0), "Battle not started");
        
        if (b.isResolved) {
            return (false, false, 0, 0, b.winner, "Battle resolved");
        }

        // Get current tick and range status
        (,, address token0, address token1, uint24 fee,,,,,,,) = positionManager.positions(b.creatorTokenId);
        address pool = factory.getPool(token0, token1, fee);
        require(pool != address(0), "Pool not found");
        
        (, int24 currentTick,,,,,) = IUniswapV3Pool(pool).slot0();
        
        creatorInRange = currentTick >= b.creatorTickLower && currentTick <= b.creatorTickUpper;
        opponentInRange = currentTick >= b.opponentTickLower && currentTick <= b.opponentTickUpper;
        
        // Get current fees
        (uint256 creatorFee0, uint256 creatorFee1) = getFeeEarnings(b.creatorTokenId);
        (uint256 opponentFee0, uint256 opponentFee1) = getFeeEarnings(b.opponentTokenId);
        
        creatorFees = creatorFee0 + creatorFee1;
        opponentFees = opponentFee0 + opponentFee1;

        // Determine current leader based on range battle logic
        if (creatorInRange && !opponentInRange) {
            currentLeader = b.creator;
            leadReason = "Creator in range, opponent out";
        } else if (!creatorInRange && opponentInRange) {
            currentLeader = b.opponent;
            leadReason = "Opponent in range, creator out";
        } else if (creatorInRange && opponentInRange) {
            if (creatorFees > opponentFees) {
                currentLeader = b.creator;
                leadReason = "Both in range, creator has more fees";
            } else if (opponentFees > creatorFees) {
                currentLeader = b.opponent;
                leadReason = "Both in range, opponent has more fees";
            } else {
                currentLeader = b.creator;
                leadReason = "Both in range, tied on fees (creator advantage)";
            }
        } else {
            currentLeader = address(0);
            leadReason = "Both out of range - draw";
        }
    }

    /**
     * @dev Get all active battles
     */
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
                statuses[index] = this.getBattleStatus(i);
                index++;
            }
        }
    }

    /**
     * @dev Get battles waiting for opponents
     */
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

    /**
     * @dev Get battles ready to resolve
     */
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

    /**
     * @dev Get user's battles
     */
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

    /**
     * @dev Get battle token information
     */
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
        
        // Simple pool name generation
        poolName = string(abi.encodePacked("Pool-", uint2str(fee / 100), "bps"));
    }

    /**
     * @dev Check if user can join a battle
     */
    function canJoinBattle(uint256 battleId, uint256 userTokenId) 
        external 
        view 
        returns (bool canJoin, string memory reason) 
    {
        Battle memory b = battles[battleId];
        
        if (b.creator == address(0)) {
            return (false, "Battle does not exist");
        }
        
        if (b.isResolved) {
            return (false, "Battle already resolved");
        }
        
        if (b.opponent != address(0)) {
            return (false, "Battle already has opponent");
        }

        // Check LP value compatibility (within 5% tolerance)
        (,, uint256 userUSDValue) = getLPTokenValueUSD(userTokenId);
        uint256 minValue = (b.totalValueUSD * 95) / 100;
        uint256 maxValue = (b.totalValueUSD * 105) / 100;
        
        if (userUSDValue < minValue || userUSDValue > maxValue) {
            return (false, "LP value not within 5% tolerance");
        }

        return (true, "Can join battle");
    }

    /**
     * @dev Get position details for a token ID
     */
    function getPositionDetails(uint256 tokenId) 
        external 
        view 
        returns (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 valueUSD,
            uint256 fees0,
            uint256 fees1
        ) 
    {
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        
        (
            ,
            ,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            liquidity,
            ,
            ,
            tokensOwed0,
            tokensOwed1
        ) = positionManager.positions(tokenId);
        
        (amount0, amount1, valueUSD) = getLPTokenValueUSD(tokenId);
        fees0 = uint256(tokensOwed0);
        fees1 = uint256(tokensOwed1);
    }
}