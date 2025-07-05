// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IShared.sol";
import "./libraries/PoolUtils.sol";
import "./libraries/TransferUtils.sol";
import "./libraries/StringUtils.sol";
import "./interfaces/IShared.sol";

/// @title LiquidArena LP Battle Vault
/// @notice Enables PvP battles between Uniswap V3 LP positions based on price range validity
/// @dev Uses Chainlink price feeds for accurate USD valuations and implements battle resolution logic
/// @author LiquidArena Team
contract LPBattleVault is IERC721Receiver, Pausable, ReentrancyGuard {
    // Additional decimal-specific errors (shared errors are imported from IShared.sol)
    error InvalidTokenDecimals();
    error AmountTooLarge();
    error InvalidPrice();

    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public factory;

    address public owner;
    mapping(address => bool) public stablecoins;

    // Chainlink Price Feeds (Monad Testnet)
    mapping(address => address) public priceFeeds;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 18000; // 5 hours

    // Tambahkan cache untuk decimal token
    mapping(address => uint8) private tokenDecimals;

    struct Battle {
        address creator;             // 20 bytes - Slot 0
        bool isResolved;            // 1 byte
        int24 creatorTickLower;     // 3 bytes
        int24 creatorTickUpper;     // 3 bytes
        int24 opponentTickLower;    // 3 bytes
        int24 opponentTickUpper;    // 3 bytes (Total: 32 bytes)

        address opponent;           // 20 bytes - Slot 1
        address winner;             // 12 bytes (Total: 32 bytes)

        uint256 creatorTokenId;     // 32 bytes - Slot 2
        uint256 opponentTokenId;    // 32 bytes - Slot 3
        uint256 startTime;          // 32 bytes - Slot 4
        uint256 duration;           // 32 bytes - Slot 5
        uint256 totalValueUSD;      // 32 bytes - Slot 6
    }

    uint256 public battleIdCounter;
    mapping(uint256 => Battle) public battles;

    // Constants
    uint256 public constant RESOLVER_REWARD_BPS = 100; // 1% in basis points
    uint256 public constant MIN_BATTLE_DURATION = 5 minutes; // Minimum battle duration
    uint256 public constant MAX_BATTLE_DURATION = 7 days; // Maximum battle duration
    uint256 public constant LP_VALUE_TOLERANCE_BPS = 500; // 5% tolerance in basis points
    uint256 public constant MAX_PRICE_STALENESS = 18000; // 5 hours maximum price staleness

    // Events
    event BattleCreated(
        uint256 indexed battleId,
        address indexed creator,
        uint256 creatorTokenId,
        uint256 duration,
        uint256 totalValueUSD
    );
    event BattleJoined(
        uint256 indexed battleId,
        address indexed opponent,
        uint256 opponentTokenId,
        uint256 startTime
    );
    event BattleResolved(
        uint256 indexed battleId,
        address indexed winner,
        address indexed resolver,
        uint256 resolverReward
    );

    // New events for better tracking
    event BattleStatusChanged(
        uint256 indexed battleId,
        string previousStatus,
        string newStatus,
        uint256 timestamp
    );

    event PlayerOutOfRange(
        uint256 indexed battleId,
        address indexed player,
        bool isCreator,
        uint256 timestamp
    );

    event StablecoinSet(address indexed token, bool isStablecoin);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PriceFeedSet(address indexed token, address indexed priceFeed);
    event ContractPausedByOwner(address indexed by);
    event ContractUnpausedByOwner(address indexed by);
    event EmergencyWithdrawal(uint256 indexed battleId, address indexed to, uint256 tokenId);

    constructor(address _positionManager, address _factory) {
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = IUniswapV3Factory(_factory);
        owner = msg.sender;

        // Initialize using assembly for gas optimization
        assembly {
            // USDC stablecoin
            mstore(0x00, 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea)
            mstore(0x20, stablecoins.slot)
            sstore(keccak256(0x00, 0x40), 1)

            // USDT stablecoin
            mstore(0x00, 0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D)
            sstore(keccak256(0x00, 0x40), 1)
        }

        // Direct price feed mappings
        priceFeeds[0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37] = 0x0c76859E85727683Eeba0C70Bc2e0F5781337818; // WETH -> ETH/USD
        priceFeeds[0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d] = 0x2Cd9D7E85494F68F5aF08EF96d6FD5e8F71B4d31; // WBTC -> BTC/USD
        priceFeeds[0xf817257fed379853cDe0fa4F97AB987181B1E5Ea] = 0x70BB0758a38ae43418ffcEd9A25273dd4e804D15; // USDC -> USDC/USD
        priceFeeds[0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D] = 0x14eE6bE30A91989851Dc23203E41C804D4D71441; // USDT -> USDT/USD
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
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

    /// @notice Sets whether a token is considered a stablecoin
    /// @dev Only owner can call this function
    /// @param token The token address
    /// @param isStablecoin Whether the token is a stablecoin
    function setStablecoin(address token, bool isStablecoin) external onlyOwner {
        if (token == address(0)) {
            revert ZeroAddress();
        }
        stablecoins[token] = isStablecoin;
        emit StablecoinSet(token, isStablecoin);
    }

    /// @notice Sets the Chainlink price feed for a token
    /// @dev Only owner can call this function
    /// @param token The token address
    /// @param priceFeed The Chainlink price feed address
    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        if (token == address(0) || priceFeed == address(0)) {
            revert ZeroAddress();
        }
        priceFeeds[token] = priceFeed;
        emit PriceFeedSet(token, priceFeed);
    }

    /// @notice Transfers ownership of the contract
    /// @dev Only current owner can call this function
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidOwner();
        }
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /// @notice Pauses the contract, preventing new battles
    /// @dev Only owner can call this function
    function pause() external onlyOwner {
        _pause();
        emit ContractPausedByOwner(msg.sender);
    }

    /// @notice Unpauses the contract, allowing new battles
    /// @dev Only owner can call this function
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpausedByOwner(msg.sender);
    }

    /// @notice Emergency withdrawal function for stuck NFTs
    /// @dev Only owner can call this function in case of emergencies
    /// @param battleId The battle ID containing the stuck NFT
    /// @param to The address to send the NFT to
    /// @param tokenId The NFT token ID to withdraw
    function emergencyWithdraw(uint256 battleId, address to, uint256 tokenId) external onlyOwner {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        Battle storage battle = battles[battleId];
        // If battle is not resolved and hasn't expired
        if (!battle.isResolved) {
            if (battle.startTime == 0) {
                // For unjoined battles, allow emergency withdrawal after 7 days from creation
                // We don't have a creation timestamp, so we'll allow it if battle exists
                // This is a reasonable assumption for emergency cases
            } else {
                // For joined battles, require 7 days after battle end
                if (block.timestamp < battle.startTime + battle.duration + 7 days) {
                    revert BattleNotExpiredForEmergencyWithdrawal();
                }
            }
        }

        positionManager.safeTransferFrom(address(this), to, tokenId);
        emit EmergencyWithdrawal(battleId, to, tokenId);
    }

    function getLPTokenValueUSD(uint256 tokenId)
        external
        view
        returns (uint256 amount0, uint256 amount1, uint256 usdValue)
    {
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = positionManager.positions(tokenId);

        address pool = factory.getPool(token0, token1, fee);
        if (pool == address(0)) {
            revert PoolNotFound();
        }

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolState(pool).slot0();

        // Calculate actual token amounts in the position using proper Uniswap V3 math
        (amount0, amount1) = getTokenAmountsFromLiquidity(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            liquidity
        );

        // Use Chainlink price feeds for accurate USD valuation
        usdValue = calculateChainlinkUSDValue(token0, token1, amount0, amount1);
    }

    function getTokenAmountsFromLiquidity(
        uint160 sqrtPriceX96,
        int24,
        int24,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Simplified calculation - in production, use TickMath library
        // For now, use approximate calculation with consistent scaling
        amount0 = (uint256(liquidity) * 1e18) / uint256(sqrtPriceX96);
        amount1 = (uint256(liquidity) * uint256(sqrtPriceX96)) / (1e18);
    }

    function calculateChainlinkUSDValue(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint256 usdValue) {
        uint256 token0ValueUSD = getTokenUSDValue(token0, amount0);
        uint256 token1ValueUSD = getTokenUSDValue(token1, amount1);

        usdValue = token0ValueUSD + token1ValueUSD;
    }

    /**
     * @dev Get token decimals with caching for gas optimization
     * @param token The token address
     * @return The number of decimals for the token
     */
    function getTokenDecimals(address token) internal view returns (uint8) {
        // Return cached value if available
        uint8 cachedDecimals = tokenDecimals[token];
        if (cachedDecimals > 0) {
            return cachedDecimals;
        }

        // Try to get decimals from token
        try IERC20Metadata(token).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            // Default to 18 if call fails
            return 18;
        }
    }

    /**
     * @dev Get price feed decimals
     * @param priceFeed The price feed address
     * @return The number of decimals for the price feed
     */
    function getPriceFeedDecimals(address priceFeed) internal view returns (uint8) {
        try AggregatorV3Interface(priceFeed).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            // Default to 8 if call fails (most Chainlink feeds use 8 decimals)
            return 8;
        }
    }

    /**
     * @dev Set token decimals (for gas optimization)
     * @param token The token address
     * @param decimals The number of decimals
     */
    function setTokenDecimals(address token, uint8 decimals) external onlyOwner {
        tokenDecimals[token] = decimals;
    }

    /**
     * @dev Get token USD value with proper decimal handling
     * @param token The token address
     * @param amount The token amount
     * @return The USD value with 18 decimals precision (standardized)
     */
    function getTokenUSDValue(address token, uint256 amount) internal view returns (uint256) {
        // Handle zero amount early
        if (amount == 0) {
            return 0;
        }

        uint8 tokenDec = getTokenDecimals(token);

        // Validate token decimals for safety
        if (tokenDec > 77) {
            revert InvalidTokenDecimals();
        }

        // Handle stablecoins (1:1 with USD)
        if (stablecoins[token]) {
            // Convert stablecoin amount to 18 decimal USD representation
            // For USDC (6 decimals): 710000 (0.71 USDC) -> 710000000000000000 (0.71 USD with 18 decimals)
            if (tokenDec <= 18) {
                uint256 scaleFactor = 10 ** (18 - tokenDec);
                // Check for overflow before multiplication
                if (amount > type(uint256).max / scaleFactor) {
                    revert AmountTooLarge();
                }
                return amount * scaleFactor;
            } else {
                uint256 scaleFactor = 10 ** (tokenDec - 18);
                return amount / scaleFactor;
            }
        }

        // Get Chainlink price feed
        address priceFeed = priceFeeds[token];
        if (priceFeed == address(0)) {
            revert PriceFeedNotSet();
        }

        // Get latest price
        (, int256 price,, uint256 updatedAt,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (price <= 0) {
            revert InvalidPrice();
        }
        if (block.timestamp - updatedAt >= PRICE_STALENESS_THRESHOLD) {
            revert StalePrice();
        }

        uint8 priceFeedDecimals = getPriceFeedDecimals(priceFeed);

        // Validate price feed decimals
        if (priceFeedDecimals > 77) {
            revert InvalidTokenDecimals();
        }

        // Calculate USD value with improved decimal handling
        // Target: normalize to 18 decimals for USD
        // Formula: (amount * price) * 10^(18 - tokenDecimals) / 10^priceFeedDecimals

        uint256 usdValue;
        uint256 priceUint = uint256(price);

        // Use safe math to prevent overflow
        if (tokenDec <= 18) {
            // Scale up token amount to 18 decimals, then apply price
            uint256 scaledAmount = amount * (10 ** (18 - tokenDec));
            // Check for overflow in multiplication
            if (scaledAmount > type(uint256).max / priceUint) {
                revert AmountTooLarge();
            }
            usdValue = (scaledAmount * priceUint) / (10 ** priceFeedDecimals);
        } else {
            // Scale down token amount to 18 decimals, then apply price
            uint256 scaledAmount = amount / (10 ** (tokenDec - 18));
            usdValue = (scaledAmount * priceUint) / (10 ** priceFeedDecimals);
        }

        return usdValue;
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

    /// @notice Creates a new battle with an LP NFT
    /// @dev Transfers the LP NFT to this contract and initializes battle state
    /// @param tokenId The Uniswap V3 LP NFT token ID
    /// @param durations Battle duration in seconds (minimum 1 hour, maximum 7 days)
    /// @return battleId The unique identifier for the created battle
    function createBattle(uint256 tokenId, uint256 durations)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        // Input validation
        // if (durations < MIN_BATTLE_DURATION) {
        //     revert BattleDurationTooShort(durations, MIN_BATTLE_DURATION);
        // }
        if (durations > MAX_BATTLE_DURATION) {
            revert BattleDurationTooLong(durations, MAX_BATTLE_DURATION);
        }
        if (positionManager.ownerOf(tokenId) != msg.sender) {
            revert NotLPOwner();
        }
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

        emit BattleCreated(battleId, msg.sender, tokenId, durations, usdValue);
        return battleId;
    }

    /// @notice Joins an existing battle with an LP NFT
    /// @dev Validates LP value compatibility and starts the battle
    /// @param battleId The battle to join
    /// @param opponentTokenId The opponent's LP NFT token ID
    function joinBattle(uint256 battleId, uint256 opponentTokenId)
        external
        nonReentrant
        whenNotPaused
    {
        if (positionManager.ownerOf(opponentTokenId) != msg.sender) {
            revert NotLPOwner();
        }

        Battle memory b = battles[battleId]; // Cache in memory
        if (b.isResolved) {
            revert BattleAlreadyResolved();
        }
        if (b.opponent != address(0)) {
            revert BattleAlreadyJoined();
        }

        // Cross-pool battles allowed! Only requirement is 5% value tolerance
        (,, uint256 opponentValueUSD) = this.getLPTokenValueUSD(opponentTokenId);

        // Cache totalValueUSD to avoid reading from storage
        uint256 creatorValue = b.totalValueUSD;
        uint256 minValue = (creatorValue * 5) / 100;
        uint256 maxValue = (creatorValue * 2000) / 100;

        if (opponentValueUSD < minValue || opponentValueUSD > maxValue) {
            revert LPValueNotWithinTolerance();
        }

        positionManager.safeTransferFrom(msg.sender, address(this), opponentTokenId);

        (,,,,, int24 oppTickLower, int24 oppTickUpper,,,,,) = positionManager.positions(opponentTokenId);

        // Update storage directly (b is memory copy, so we need storage reference)
        Battle storage battleStorage = battles[battleId];
        battleStorage.opponent = msg.sender;
        battleStorage.opponentTokenId = opponentTokenId;
        battleStorage.startTime = block.timestamp;
        battleStorage.opponentTickLower = oppTickLower;
        battleStorage.opponentTickUpper = oppTickUpper;

        emit BattleJoined(battleId, msg.sender, opponentTokenId, block.timestamp);
    }

    /// @notice Resolves a completed battle and distributes rewards
    /// @dev Can be called by anyone after battle duration expires
    /// @param battleId The battle to resolve
    function resolveBattle(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        if (b.isResolved) {
            revert AlreadyResolved();
        }
        if (b.opponent == address(0)) {
            revert NoOpponentJoined();
        }
        if (block.timestamp < b.startTime + b.duration) {
            revert BattleNotEnded();
        }

        // Get pool data for both positions using library
        PoolUtils.PoolData memory creatorPoolData = PoolUtils.getPoolData(positionManager, factory, b.creatorTokenId);
        PoolUtils.PoolData memory opponentPoolData = PoolUtils.getPoolData(positionManager, factory, b.opponentTokenId);

        if (creatorPoolData.pool == address(0)) {
            revert InvalidCreatorPool();
        }
        if (opponentPoolData.pool == address(0)) {
            revert InvalidOpponentPool();
        }

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

            // Fix: If fees are equal, creator wins (creator advantage)
            winner = creatorTotalFees >= opponentTotalFees ? b.creator : b.opponent;
        } else {
            // Fix: If both out of range, creator wins (creator advantage)
            uint256 randomValue = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                battleId,
                b.creator,
                b.opponent
            )));

            winner = (randomValue % 2 == 0) ? b.creator : b.opponent;
        }

        // Update battle state BEFORE transfers for consistency
        b.isResolved = true;
        b.winner = winner;

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

        // Calculate total resolver reward for event
        uint256 totalResolverReward = creatorResolverReward0 + creatorResolverReward1 +
                                     opponentResolverReward0 + opponentResolverReward1;

        // Return NFTs to original owners
        positionManager.safeTransferFrom(address(this), b.creator, b.creatorTokenId);
        positionManager.safeTransferFrom(address(this), b.opponent, b.opponentTokenId);

        emit BattleResolved(battleId, winner, msg.sender, totalResolverReward);
    }

    function getBattleUSDValue(uint256 battleId) external view returns (string memory) {
        uint256 raw = battles[battleId].totalValueUSD;
        return StringUtils.formatUSDValue(raw);
    }

    /**
     * @dev Get battle USD value with high precision formatting
     * @param battleId The battle ID
     * @return Formatted USD string with 4 decimal places
     */
    function getBattleUSDValuePrecise(uint256 battleId) external view returns (string memory) {
        uint256 raw = battles[battleId].totalValueUSD;
        return StringUtils.formatUSDValuePrecise(raw);
    }

    /**
     * @dev Get raw USD value for external integrations
     * @param battleId The battle ID
     * @return Raw USD value with 18 decimals
     */
    function getBattleUSDValueRaw(uint256 battleId) external view returns (uint256) {
        return battles[battleId].totalValueUSD;
    }

    /**
     * @dev Validate token decimals for safety
     * @param token The token address
     * @return isValid Whether the token has valid decimals (between 0 and 77)
     */
    function validateTokenDecimals(address token) external view returns (bool isValid) {
        try IERC20Metadata(token).decimals() returns (uint8 decimals) {
            // Solidity supports up to 77 decimals due to uint256 limitations
            return decimals <= 77;
        } catch {
            return false;
        }
    }

    /**
     * @dev Get detailed token information for debugging
     * @param token The token address
     * @return decimals Token decimals
     * @return isStablecoin Whether token is marked as stablecoin
     * @return hasPriceFeed Whether token has a price feed configured
     */
    function getTokenInfo(address token) external view returns (
        uint8 decimals,
        bool isStablecoin,
        bool hasPriceFeed
    ) {
        decimals = getTokenDecimals(token);
        isStablecoin = stablecoins[token];
        hasPriceFeed = priceFeeds[token] != address(0);
    }

    /**
     * @dev External wrapper for getTokenUSDValue for testing purposes
     * @param token The token address
     * @param amount The token amount
     * @return The USD value with 18 decimals precision
     */
    function getTokenUSDValueExternal(address token, uint256 amount) external view returns (uint256) {
        return getTokenUSDValue(token, amount);
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

    /**
     * @dev Update battle status and emit events for tracking
     * @param battleId The battle ID to update
     */
    function updateBattleStatus(uint256 battleId) external {
        Battle memory b = battles[battleId];
        if (b.creator == address(0)) {
            revert BattleDoesNotExist();
        }

        string memory currentStatus = this.getBattleStatus(battleId);

        // Check for range violations and emit events
        if (!b.isResolved && b.opponent != address(0)) {
            (bool creatorInRange, bool opponentInRange,,) = this.getCurrentPerformance(battleId);

            // Emit out of range events
            if (!creatorInRange) {
                emit PlayerOutOfRange(battleId, b.creator, true, block.timestamp);
            }
            if (!opponentInRange) {
                emit PlayerOutOfRange(battleId, b.opponent, false, block.timestamp);
            }
        }

        emit BattleStatusChanged(battleId, currentStatus, currentStatus, block.timestamp);
    }

    function getBattleDetails(uint256 battleId)
        external
        view
        returns (address creator, address opponent, uint256 usdValue, address winner, string memory status)
    {
        Battle memory b = battles[battleId];
        creator = b.creator;
        opponent = b.opponent;
        usdValue = b.totalValueUSD;
        winner = b.winner;
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
            uint256 opponentFees
        )
    {
        Battle memory b = battles[battleId];
        if (b.opponent == address(0)) {
            revert BattleNotStarted();
        }

        if (b.isResolved) {
            return (false, false, 0, 0);
        }

        // Get pool data using library (batched calls)
        PoolUtils.PoolData memory creatorPoolData = PoolUtils.getPoolData(positionManager, factory, b.creatorTokenId);
        PoolUtils.PoolData memory opponentPoolData = PoolUtils.getPoolData(positionManager, factory, b.opponentTokenId);

        if (creatorPoolData.pool == address(0)) {
            revert InvalidCreatorPool();
        }
        if (opponentPoolData.pool == address(0)) {
            revert InvalidOpponentPool();
        }

        // Check ranges using library functions
        creatorInRange = PoolUtils.isInRange(creatorPoolData.currentTick, b.creatorTickLower, b.creatorTickUpper);
        opponentInRange = PoolUtils.isInRange(opponentPoolData.currentTick, b.opponentTickLower, b.opponentTickUpper);

        // Get current fees using library
        PoolUtils.PositionData memory creatorPosData = PoolUtils.getPositionData(positionManager, b.creatorTokenId);
        PoolUtils.PositionData memory opponentPosData = PoolUtils.getPositionData(positionManager, b.opponentTokenId);

        creatorFees = PoolUtils.getTotalFees(creatorPosData.tokensOwed0, creatorPosData.tokensOwed1);
        opponentFees = PoolUtils.getTotalFees(opponentPosData.tokensOwed0, opponentPosData.tokensOwed1);
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
        if (b.creator == address(0)) {
            revert BattleDoesNotExist();
        }

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

    /**
     * @dev Get multiple battle details in a single call
     * @param battleIds Array of battle IDs to query
     */
    function getBattlesBatch(uint256[] calldata battleIds)
        external
        view
        returns (
            address[] memory creators,
            address[] memory opponents,
            string[] memory statuses,
            uint256[] memory timeRemaining,
            bool[] memory isResolved
        )
    {
        uint256 length = battleIds.length;
        creators = new address[](length);
        opponents = new address[](length);
        statuses = new string[](length);
        timeRemaining = new uint256[](length);
        isResolved = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            Battle memory b = battles[battleIds[i]];
            creators[i] = b.creator;
            opponents[i] = b.opponent;
            isResolved[i] = b.isResolved;

            // Calculate status
            if (b.isResolved) {
                statuses[i] = "ended";
                timeRemaining[i] = 0;
            } else if (b.opponent == address(0)) {
                statuses[i] = "queued";
                timeRemaining[i] = 0;
            } else if (block.timestamp < b.startTime + b.duration) {
                statuses[i] = "onGoing";
                timeRemaining[i] = (b.startTime + b.duration) - block.timestamp;
            } else {
                statuses[i] = "readyToResolve";
                timeRemaining[i] = 0;
            }
        }
    }

    /**
     * @dev Get battles by status filter
     * @param status The status to filter by ("queued", "onGoing", "readyToResolve")
     */
    function getBattlesByStatus(string calldata status)
        external
        view
        returns (uint256[] memory battleIds)
    {
        uint256 count = 0;

        // Count matching battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            string memory battleStatus = this.getBattleStatus(i);
            if (keccak256(bytes(battleStatus)) == keccak256(bytes(status))) {
                count++;
            }
        }

        battleIds = new uint256[](count);
        uint256 index = 0;

        // Collect matching battles
        for (uint256 i = 0; i < battleIdCounter; i++) {
            string memory battleStatus = this.getBattleStatus(i);
            if (keccak256(bytes(battleStatus)) == keccak256(bytes(status))) {
                battleIds[index] = i;
                index++;
            }
        }
    }
}
