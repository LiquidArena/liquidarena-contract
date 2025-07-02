// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IShared.sol";
import "./libraries/PoolUtils.sol";
import "./libraries/TransferUtils.sol";
import "./libraries/StringUtils.sol";


contract LPBattleVault is IERC721Receiver {
    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public factory;
    
    address public owner;
    mapping(address => bool) public stablecoins;

    struct Battle {
        address creator;
        address opponent;
        address winner;
        bool isResolved;
        int24 creatorTickLower;
        int24 creatorTickUpper;
        int24 opponentTickLower;
        int24 opponentTickUpper;
        uint256 creatorTokenId;
        uint256 opponentTokenId;
        uint256 startTime;
        uint256 duration;
        uint256 totalValueUSD;
    }

    uint256 public battleIdCounter;
    mapping(uint256 => Battle) public battles;
    
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

    function onERC721Received(address, address, uint256, bytes calldata)
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
        external
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
        PoolUtils.PositionData memory posData = PoolUtils.getPositionData(positionManager, tokenId);
        fee0 = uint256(posData.tokensOwed0);
        fee1 = uint256(posData.tokensOwed1);
    }

    function createBattle(uint256 tokenId, uint256 durations) external returns (uint256) {
        require(positionManager.ownerOf(tokenId) == msg.sender, "Not LP owner");
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        (,, uint256 usdValue) = this.getLPTokenValueUSD(tokenId);

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
        
        // Cross-pool battles allowed! Only requirement is 5% value tolerance

        (,, uint256 opponentValueUSD) = this.getLPTokenValueUSD(opponentTokenId);
        require(
            opponentValueUSD >= ((b.totalValueUSD * 95) / 100) && opponentValueUSD <= ((b.totalValueUSD * 105) / 100),
            "LP value not within 5% tolerance"
        );

        positionManager.safeTransferFrom(msg.sender, address(this), opponentTokenId);

        (,,,,, int24 oppTickLower, int24 oppTickUpper,,,,,) = positionManager.positions(opponentTokenId);

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
        require(block.timestamp >= b.startTime + b.duration, "Battle not ended");

        // Get pool data for both positions using library
        PoolUtils.PoolData memory creatorPoolData = PoolUtils.getPoolData(positionManager, factory, b.creatorTokenId);
        PoolUtils.PoolData memory opponentPoolData = PoolUtils.getPoolData(positionManager, factory, b.opponentTokenId);
        
        require(creatorPoolData.pool != address(0), "Invalid creator pool");
        require(opponentPoolData.pool != address(0), "Invalid opponent pool");

        // Check ranges using library functions
        bool creatorInRange = PoolUtils.isInRange(creatorPoolData.currentTick, b.creatorTickLower, b.creatorTickUpper);
        bool opponentInRange = PoolUtils.isInRange(opponentPoolData.currentTick, b.opponentTickLower, b.opponentTickUpper);

        // Optimized winner determination using bit manipulation
        uint8 rangeStatus = (creatorInRange ? 1 : 0) | (opponentInRange ? 2 : 0);
        address winner;
        
        if (rangeStatus == 1) { // Only creator in range
            winner = b.creator;
        } else if (rangeStatus == 2) { // Only opponent in range
            winner = b.opponent;
        } else if (rangeStatus == 3) { // Both in range - compare fees
            PoolUtils.PositionData memory creatorPosData = PoolUtils.getPositionData(positionManager, b.creatorTokenId);
            PoolUtils.PositionData memory opponentPosData = PoolUtils.getPositionData(positionManager, b.opponentTokenId);
            
            uint256 creatorTotalFees = PoolUtils.getTotalFees(creatorPosData.tokensOwed0, creatorPosData.tokensOwed1);
            uint256 opponentTotalFees = PoolUtils.getTotalFees(opponentPosData.tokensOwed0, opponentPosData.tokensOwed1);
            
            winner = creatorTotalFees > opponentTotalFees ? b.creator : 
                     opponentTotalFees > creatorTotalFees ? b.opponent : address(0);
        } // else winner = address(0) (both out of range)

        // Collect fees from both positions
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

        // Calculate resolver rewards using library
        uint256 creatorResolverReward0 = PoolUtils.calculateResolverReward(creatorAmount0, RESOLVER_REWARD_BPS);
        uint256 creatorResolverReward1 = PoolUtils.calculateResolverReward(creatorAmount1, RESOLVER_REWARD_BPS);
        uint256 opponentResolverReward0 = PoolUtils.calculateResolverReward(opponentAmount0, RESOLVER_REWARD_BPS);
        uint256 opponentResolverReward1 = PoolUtils.calculateResolverReward(opponentAmount1, RESOLVER_REWARD_BPS);
        
        // Transfer resolver rewards using library
        TransferUtils.safeTransferIfNonZero(creatorPoolData.token0, msg.sender, creatorResolverReward0);
        TransferUtils.safeTransferIfNonZero(creatorPoolData.token1, msg.sender, creatorResolverReward1);
        TransferUtils.safeTransferIfNonZero(opponentPoolData.token0, msg.sender, opponentResolverReward0);
        TransferUtils.safeTransferIfNonZero(opponentPoolData.token1, msg.sender, opponentResolverReward1);
        
        // Calculate remaining fees after resolver rewards
        uint256 creatorRemaining0 = creatorAmount0 - creatorResolverReward0;
        uint256 creatorRemaining1 = creatorAmount1 - creatorResolverReward1;
        uint256 opponentRemaining0 = opponentAmount0 - opponentResolverReward0;
        uint256 opponentRemaining1 = opponentAmount1 - opponentResolverReward1;
        
        // Distribute remaining fees based on battle outcome using optimized transfers
        if (winner == b.creator) {
            // Creator wins - gets all remaining fees
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token0, b.creator, creatorRemaining0);
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token1, b.creator, creatorRemaining1);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token0, b.creator, opponentRemaining0);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token1, b.creator, opponentRemaining1);
        } else if (winner == b.opponent) {
            // Opponent wins - gets all remaining fees
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token0, b.opponent, creatorRemaining0);
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token1, b.opponent, creatorRemaining1);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token0, b.opponent, opponentRemaining0);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token1, b.opponent, opponentRemaining1);
        } else {
            // Draw - each player gets their own pool's fees back
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token0, b.creator, creatorRemaining0);
            TransferUtils.safeTransferIfNonZero(creatorPoolData.token1, b.creator, creatorRemaining1);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token0, b.opponent, opponentRemaining0);
            TransferUtils.safeTransferIfNonZero(opponentPoolData.token1, b.opponent, opponentRemaining1);
        }

        // Return NFTs to original owners
        positionManager.safeTransferFrom(address(this), b.creator, b.creatorTokenId);
        positionManager.safeTransferFrom(address(this), b.opponent, b.opponentTokenId);

        b.isResolved = true;
        b.winner = winner;

        emit BattleResolved(battleId, winner);
    }

    function getBattleUSDValue(uint256 battleId) external view returns (string memory) {
        uint256 raw = battles[battleId].totalValueUSD;
        return StringUtils.formatUSDValue(raw);
    }

    function getBattleStatus(uint256 battleId) external view returns (string memory) {
        Battle memory b = battles[battleId];

        if (b.isResolved) {
            return "ended";
        } else if (b.opponent == address(0)) {
            return "queued";
        } else if (block.timestamp < b.startTime + b.duration) {
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
            : b.opponent == address(0) ? "queued" : block.timestamp < b.startTime + b.duration ? "onGoing" : "readyToResolve";
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
        
        // Inline status calculation to avoid external call
        if (b.isResolved) {
            status = "ended";
        } else if (b.opponent == address(0)) {
            status = "queued";
        } else if (block.timestamp < b.startTime + b.duration) {
            status = "onGoing";
        } else {
            status = "readyToResolve";
        }
        
        // Get current tick and range status if battle has started
        if (b.opponent != address(0)) {
            // Get pool data using library (more efficient)
            PoolUtils.PoolData memory creatorPoolData = PoolUtils.getPoolData(positionManager, factory, b.creatorTokenId);
            PoolUtils.PoolData memory opponentPoolData = PoolUtils.getPoolData(positionManager, factory, b.opponentTokenId);
            
            if (creatorPoolData.pool != address(0) && opponentPoolData.pool != address(0)) {
                // Use creator's tick for the return value (for backward compatibility)
                currentTick = creatorPoolData.currentTick;
                
                // Check each position against its own pool using library
                creatorInRange = PoolUtils.isInRange(creatorPoolData.currentTick, b.creatorTickLower, b.creatorTickUpper);
                opponentInRange = PoolUtils.isInRange(opponentPoolData.currentTick, b.opponentTickLower, b.opponentTickUpper);
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
        
        uint256 endTime = b.startTime + b.duration;
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

        // Get pool data using library (batched calls)
        PoolUtils.PoolData memory creatorPoolData = PoolUtils.getPoolData(positionManager, factory, b.creatorTokenId);
        PoolUtils.PoolData memory opponentPoolData = PoolUtils.getPoolData(positionManager, factory, b.opponentTokenId);
        
        require(creatorPoolData.pool != address(0), "Creator pool not found");
        require(opponentPoolData.pool != address(0), "Opponent pool not found");
        
        // Check ranges using library functions
        creatorInRange = PoolUtils.isInRange(creatorPoolData.currentTick, b.creatorTickLower, b.creatorTickUpper);
        opponentInRange = PoolUtils.isInRange(opponentPoolData.currentTick, b.opponentTickLower, b.opponentTickUpper);
        
        // Get current fees using library
        PoolUtils.PositionData memory creatorPosData = PoolUtils.getPositionData(positionManager, b.creatorTokenId);
        PoolUtils.PositionData memory opponentPosData = PoolUtils.getPositionData(positionManager, b.opponentTokenId);
        
        creatorFees = PoolUtils.getTotalFees(creatorPosData.tokensOwed0, creatorPosData.tokensOwed1);
        opponentFees = PoolUtils.getTotalFees(opponentPosData.tokensOwed0, opponentPosData.tokensOwed1);

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
                Battle memory b = battles[i];
                battleIds[index] = i;
                // Inline status calculation
                if (b.opponent == address(0)) {
                    statuses[index] = "queued";
                } else if (block.timestamp < b.startTime + b.duration) {
                    statuses[index] = "onGoing";
                } else {
                    statuses[index] = "readyToResolve";
                }
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
            if (!b.isResolved && b.opponent != address(0) && block.timestamp >= b.startTime + b.duration) {
                readyCount++;
            }
        }
        
        battleIds = new uint256[](readyCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < battleIdCounter; i++) {
            Battle memory b = battles[i];
            if (!b.isResolved && b.opponent != address(0) && block.timestamp >= b.startTime + b.duration) {
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
        poolName = string(abi.encodePacked("Pool-", StringUtils.uint2str(fee / 100), "bps"));
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
        (,, uint256 userUSDValue) = this.getLPTokenValueUSD(userTokenId);
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
        
        (amount0, amount1, valueUSD) = this.getLPTokenValueUSD(tokenId);
        fees0 = uint256(tokensOwed0);
        fees1 = uint256(tokensOwed1);
    }
}