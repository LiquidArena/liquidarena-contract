# LPFeeBattle - Fee Accumulation Battles

A DeFi protocol for Uniswap V3 LP position fee accumulation battles with **pool-based USD pricing** and **gas-optimized architecture**. Users compete based on fee growth rate during the battle period.

## 🎯 Overview

**LPFeeBattle** enables users to compete based on **fee accumulation rates** rather than price ranges. The winner is determined by who has the highest fee growth rate (fees generated per dollar of LP value) during the battle period.

### 🔥 **KEY FEATURES**

- ✅ **Fee Rate Competition**: Battles based on fee generation efficiency
- ✅ **Cross-Pool Battles**: Battle between different pools with 5% value tolerance
- ✅ **Gas Optimized**: Library architecture reduces deployment costs and improves efficiency
- ✅ **Pool-Based Pricing**: No external oracles required - uses Uniswap pool prices
- ✅ **Comprehensive Frontend Helpers**: 15+ functions for easy integration
- ✅ **Real-time Performance Tracking**: Live fee rate monitoring and leader determination

### ⚠️ Important: Fee Collection Mechanism

LPFeeBattle collects fees from LP positions and distributes them to the winner:

- **Winner receives**: All accumulated fees from both LP NFTs (based on fee rate performance)
- **Resolver receives**: 1% of total collected fees as incentive
- **Original owners receive**: Their NFTs back (with fees extracted)
- **Fee collection**: Uses Uniswap's `collect()` function to extract available fees
- **5% value tolerance**: Required for joining battles (LP positions must be within 5% value range)

### Network Information

**Sepolia Testnet (Recommended)**
- **Chain**: Ethereum Sepolia (Chain ID: 11155111)
- **RPC URL**: `https://ethereum-sepolia-rpc.publicnode.com`
- **Position Manager**: `0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4`
- **Factory**: `0x0227628f3F023bb0B980b67D528571c95c6DaC1c`

## 🚀 Quick Start - Frontend Integration

### 1. Deploy Contracts

```bash
# Set environment variables
export PRIVATE_KEY="your_private_key"
export RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"

# Deploy optimized system with libraries (Sepolia)
forge script script/DeployLPBattleVault.s.sol --rpc-url $RPC_URL --broadcast --verify

# OR use the CLI deployment script
chmod +x deploy-sepolia.sh
./deploy-sepolia.sh
```

### 🆕 **Gas-Optimized Architecture**

The contract uses a **library-based architecture** for maximum efficiency:

- **Main Contract**: 3,232,133 gas (14,634 bytes)
- **PoolUtils Library**: 1,004,831 gas (batched pool operations)
- **TransferUtils Library**: 364,419 gas (optimized token transfers) 
- **StringUtils Library**: 142,205 gas (USD formatting utilities)
- **Total System Deployment**: ~4.7M gas (libraries reusable across deployments)

## 🎮 Battle Mechanics

### How Fee Battles Work

1. **Creator** deposits LP NFT and sets battle duration (minimum 1 hour)
2. **Opponent** joins with LP NFT of similar value (within 5% tolerance)
3. **Battle runs** for the specified duration, tracking fee accumulation
4. **Winner determined** by highest fee rate: `(fee_growth_USD / lp_value_USD)`
5. **Fees distributed** to winner minus 1% resolver reward

### Fee Rate Calculation

```solidity
// Fee growth in USD during battle period
uint256 feeGrowthUSD = convertFeesToUSD(
    currentFees0 - startFees0,
    currentFees1 - startFees1,
    token0,
    token1
);

// Fee rate = fee growth / LP value (with high precision)
uint256 feeRate = lpValueUSD > 0 ? (feeGrowthUSD * 1e24) / lpValueUSD : 0;

// Winner = highest fee rate
address winner = creatorFeeRate >= opponentFeeRate ? creator : opponent;
```

## 📊 Pool-Based USD Pricing

### How It Works

```solidity
// 1. For Stablecoin Pairs (USDC/USDT)
if (token0IsStable && token1IsStable) {
    usdValue = amount0 + amount1; // Direct 1:1 conversion
}

// 2. For Stablecoin/Token Pairs  
else if (token1IsStable) {
    token1ValueUSD = amount1; // Direct USD value
    token0ValueInToken1 = (amount0 * sqrtPriceX96²) / 1e36;
    usdValue = token0ValueInToken1 + token1ValueUSD;
}

// 3. For Non-Stablecoin Pairs
else {
    // Use pool ratio for relative comparison
    totalValueInToken1 = amount1 + (amount0 * sqrtPriceX96²) / 1e36;
    usdValue = totalValueInToken1; // Relative valuation
}
```

### Stablecoin Configuration

```typescript
// Set stablecoins (only owner)
await contract.setStablecoin(USDC_ADDRESS, true);
await contract.setStablecoin(USDT_ADDRESS, true);

// Check if token is stablecoin
const isStable = await contract.stablecoins(tokenAddress);
```

## 🔧 Core Contract Functions

### LPFeeBattle Interface

```typescript
interface LPFeeBattle {
  // Battle management
  createBattle(tokenId: BigNumber, duration: BigNumber): Promise<BigNumber>;
  joinBattle(battleId: BigNumber, opponentTokenId: BigNumber): Promise<void>;
  resolveBattle(battleId: BigNumber): Promise<void>;
  
  // View functions
  getLPTokenValueUSD(tokenId: BigNumber): Promise<BigNumber>;
  getBattleDetails(battleId: BigNumber): Promise<{
    creator: string;
    opponent: string;
    creatorTokenId: BigNumber;
    opponentTokenId: BigNumber;
    isResolved: boolean;
    winner: string;
    startTime: BigNumber;
    duration: BigNumber;
    creatorLPValueUSD: BigNumber;
    status: string;
  }>;
  getBattleStatus(battleId: BigNumber): Promise<string>;
  
  // Fee performance tracking
  getCurrentFeePerformance(battleId: BigNumber): Promise<{
    creatorFeeGrowthUSD: BigNumber;
    opponentFeeGrowthUSD: BigNumber;
    creatorFeeRate: BigNumber;
    opponentFeeRate: BigNumber;
    currentLeader: string;
  }>;
  
  // 🆕 Frontend Helper Functions
  getBattleUSDValue(battleId: BigNumber): Promise<string>; // "1,234.56 USD" format
  
  getCompleteBattleDetails(battleId: BigNumber): Promise<{
    creator: string;
    opponent: string;
    creatorTokenId: BigNumber;
    opponentTokenId: BigNumber;
    isResolved: boolean;
    winner: string;
    startTime: BigNumber;
    duration: BigNumber;
    valueUSD: BigNumber;
    status: string;
    creatorFeeGrowthUSD: BigNumber;
    opponentFeeGrowthUSD: BigNumber;
    creatorFeeRate: BigNumber;
    opponentFeeRate: BigNumber;
    currentLeader: string;
  }>;
  
  getDetailedFeePerformance(battleId: BigNumber): Promise<{
    creatorStartFees: BigNumber;
    opponentStartFees: BigNumber;
    creatorCurrentFees: BigNumber;
    opponentCurrentFees: BigNumber;
    creatorFeeGrowthUSD: BigNumber;
    opponentFeeGrowthUSD: BigNumber;
    creatorFeeRate: BigNumber;
    opponentFeeRate: BigNumber;
    currentLeader: string;
    leadReason: string;
  }>;
  
  // Batch query functions
  getAllActiveBattles(): Promise<[BigNumber[], string[]]>; // battleIds, statuses
  getBattlesWaitingForOpponent(): Promise<BigNumber[]>;
  getBattlesReadyToResolve(): Promise<BigNumber[]>;
  getUserBattles(user: string): Promise<[BigNumber[], boolean[]]>; // battleIds, isCreator
  
  // Battle information
  getBattleTokenInfo(battleId: BigNumber): Promise<{
    token0: string;
    token1: string;
    fee: number;
    poolName: string;
  }>;
  
  canJoinBattle(battleId: BigNumber, userTokenId: BigNumber): Promise<[boolean, string]>; // canJoin, reason
  
  getPositionDetails(tokenId: BigNumber): Promise<{
    token0: string;
    token1: string;
    fee: number;
    tickLower: number;
    tickUpper: number;
    liquidity: BigNumber;
    valueUSD: BigNumber;
    fees0: BigNumber;
    fees1: BigNumber;
    feesUSD: BigNumber;
  }>;
  
  getTimeRemaining(battleId: BigNumber): Promise<BigNumber>;
  
  // Configuration
  setStablecoin(token: string, isStablecoin: boolean): Promise<void>; // onlyOwner
}
```

## 📋 Frontend Helper Functions

### 🆕 **Comprehensive Frontend Support**

The LPFeeBattle contract includes 15+ frontend helper functions for seamless integration:

#### Complete Battle Information
- `getCompleteBattleDetails()` - Get all battle info including real-time fee performance
- `getDetailedFeePerformance()` - Comprehensive fee tracking with start/current/growth data
- `getCurrentFeePerformance()` - Real-time battle performance with current leader
- `getTimeRemaining()` - Time left in ongoing battles

#### Batch Query Functions  
- `getAllActiveBattles()` - All non-resolved battles with statuses
- `getBattlesWaitingForOpponent()` - Battles needing opponents
- `getBattlesReadyToResolve()` - Battles ready for resolution
- `getUserBattles()` - User's battles with creator/opponent status

#### Position & Battle Information
- `getPositionDetails()` - Complete LP position information including fees in USD
- `getBattleTokenInfo()` - Token pair and pool information
- `canJoinBattle()` - Validation check for joining battles with reasons
- `getBattleUSDValue()` - Formatted USD value display

#### Key Benefits for Frontend Developers:
- ✅ **Real-time Fee Tracking**: Monitor fee accumulation and rates live
- ✅ **Batch Queries**: Reduce RPC calls with single function calls
- ✅ **Performance Analytics**: Detailed fee growth and rate analysis
- ✅ **Validation Helpers**: Check compatibility before transactions
- ✅ **USD Formatting**: Ready-to-display formatted values
- ✅ **Complete Data**: All necessary information in single calls

## 🎮 Battle Flow

### Creating a Battle

```typescript
// 1. User approves NFT to contract
await positionManager.approve(battleContractAddress, tokenId);

// 2. Create battle with duration (minimum 1 hour)
const battleId = await contract.createBattle(tokenId, 3600); // 1 hour

// 3. Battle is now waiting for opponent
```

### Joining a Battle

```typescript
// 1. Check compatibility first
const [canJoin, reason] = await contract.canJoinBattle(battleId, userTokenId);

if (canJoin) {
  // 2. Approve NFT to contract
  await positionManager.approve(battleContractAddress, userTokenId);
  
  // 3. Join battle
  await contract.joinBattle(battleId, userTokenId);
  
  // 4. Battle starts automatically
}
```

### Resolving a Battle

```typescript
// 1. Check if battle is ready to resolve
const status = await contract.getBattleStatus(battleId);

if (status === "ready_to_resolve") {
  // 2. Anyone can resolve and earn 1% of fees
  await contract.resolveBattle(battleId);
  
  // 3. Winner gets remaining fees based on fee rate, NFTs returned to owners
}
```

## 🔍 Events for Frontend

### Battle Events

```typescript
// Battle lifecycle events
interface BattleCreated {
  battleId: BigNumber;
  creator: string;
  creatorTokenId: BigNumber;
}

interface BattleJoined {
  battleId: BigNumber;
  opponent: string;
  opponentTokenId: BigNumber;
}

interface BattleResolved {
  battleId: BigNumber;
  winner: string; // address(0) for draws (impossible in fee battles)
}

// Configuration events
interface StablecoinSet {
  token: string;
  isStablecoin: boolean;
}
```

### Event Listeners

```typescript
// Listen for new battles
contract.on("BattleCreated", (battleId, creator, creatorTokenId) => {
  console.log(`New fee battle ${battleId} created by ${creator}`);
  refreshBattleList();
});

// Listen for battle joins
contract.on("BattleJoined", (battleId, opponent, opponentTokenId) => {
  console.log(`Fee battle ${battleId} joined by ${opponent}`);
  updateBattleStatus(battleId);
});

// Listen for battle resolutions
contract.on("BattleResolved", (battleId, winner) => {
  console.log(`Fee battle ${battleId} resolved, winner: ${winner}`);
  updateBattleResult(battleId);
});
```

## 💡 Frontend Implementation Examples

### Real-time Fee Performance Display

```typescript
function FeePerformanceCard({ battleId }: { battleId: BigNumber }) {
  const [performance, setPerformance] = useState(null);
  const [timeRemaining, setTimeRemaining] = useState(BigNumber.from(0));
  
  useEffect(() => {
    async function updatePerformance() {
      try {
        const detailed = await contract.getDetailedFeePerformance(battleId);
        const remaining = await contract.getTimeRemaining(battleId);
        setPerformance(detailed);
        setTimeRemaining(remaining);
      } catch (error) {
        console.log("Battle not started yet");
      }
    }
    
    updatePerformance();
    const interval = setInterval(updatePerformance, 10000); // Update every 10 seconds
    
    return () => clearInterval(interval);
  }, [battleId]);
  
  if (!performance) return <div>Battle not started</div>;
  
  const formatFeeRate = (rate: BigNumber) => {
    // Convert from 1e24 precision to percentage
    const percentage = rate.mul(100).div(BigNumber.from(10).pow(24));
    return `${percentage.toString()}%`;
  };
  
  return (
    <div className="fee-performance">
      <h4>Live Fee Performance</h4>
      <div className="time-remaining">
        Time remaining: {formatTime(timeRemaining)}
      </div>
      <div className="current-leader">
        <div>Current leader: {performance.currentLeader}</div>
        <div>Reason: {performance.leadReason}</div>
      </div>
      <div className="fee-comparison">
        <div className="creator-stats">
          <h5>Creator</h5>
          <div>Start fees: ${ethers.utils.formatEther(performance.creatorStartFees)}</div>
          <div>Current fees: ${ethers.utils.formatEther(performance.creatorCurrentFees)}</div>
          <div>Growth: ${ethers.utils.formatEther(performance.creatorFeeGrowthUSD)}</div>
          <div>Rate: {formatFeeRate(performance.creatorFeeRate)}</div>
        </div>
        <div className="opponent-stats">
          <h5>Opponent</h5>
          <div>Start fees: ${ethers.utils.formatEther(performance.opponentStartFees)}</div>
          <div>Current fees: ${ethers.utils.formatEther(performance.opponentCurrentFees)}</div>
          <div>Growth: ${ethers.utils.formatEther(performance.opponentFeeGrowthUSD)}</div>
          <div>Rate: {formatFeeRate(performance.opponentFeeRate)}</div>
        </div>
      </div>
    </div>
  );
}
```

### Complete Battle Details Display

```typescript
function BattleDetailsCard({ battleId }: { battleId: BigNumber }) {
  const [battleDetails, setBattleDetails] = useState(null);
  
  useEffect(() => {
    async function loadBattleDetails() {
      const details = await contract.getCompleteBattleDetails(battleId);
      setBattleDetails(details);
    }
    loadBattleDetails();
  }, [battleId]);
  
  if (!battleDetails) return <div>Loading...</div>;
  
  return (
    <div className="battle-card">
      <h3>Fee Battle #{battleId.toString()}</h3>
      <div className="participants">
        <div>Creator: {battleDetails.creator}</div>
        <div>Opponent: {battleDetails.opponent || "Waiting..."}</div>
      </div>
      <div className="battle-status">
        <div>Status: {battleDetails.status}</div>
        <div>Value: {ethers.utils.formatEther(battleDetails.valueUSD)} USD</div>
        {battleDetails.opponent && (
          <div className="fee-status">
            <div>Creator fee growth: ${ethers.utils.formatEther(battleDetails.creatorFeeGrowthUSD)}</div>
            <div>Opponent fee growth: ${ethers.utils.formatEther(battleDetails.opponentFeeGrowthUSD)}</div>
            <div>Current leader: {battleDetails.currentLeader}</div>
          </div>
        )}
      </div>
    </div>
  );
}
```

### Position Details for LP Selection

```typescript
function PositionSelector({ userPositions, onSelect }: { 
  userPositions: BigNumber[], 
  onSelect: (tokenId: BigNumber) => void 
}) {
  const [positionDetails, setPositionDetails] = useState<Map<string, any>>(new Map());
  
  useEffect(() => {
    async function loadPositions() {
      const details = new Map();
      for (const tokenId of userPositions) {
        const detail = await contract.getPositionDetails(tokenId);
        details.set(tokenId.toString(), detail);
      }
      setPositionDetails(details);
    }
    loadPositions();
  }, [userPositions]);
  
  return (
    <div className="position-selector">
      <h3>Select LP Position for Fee Battle</h3>
      {userPositions.map(tokenId => {
        const detail = positionDetails.get(tokenId.toString());
        if (!detail) return <div key={tokenId.toString()}>Loading...</div>;
        
        return (
          <div 
            key={tokenId.toString()} 
            className="position-card"
            onClick={() => onSelect(tokenId)}
          >
            <div>Token ID: {tokenId.toString()}</div>
            <div>Pool: {detail.token0.slice(0, 6)}.../{detail.token1.slice(0, 6)}... ({detail.fee/100}%)</div>
            <div>Range: {detail.tickLower} to {detail.tickUpper}</div>
            <div>Value: ${ethers.utils.formatEther(detail.valueUSD)}</div>
            <div>Liquidity: {ethers.utils.formatEther(detail.liquidity)}</div>
            <div>Current Fees: ${ethers.utils.formatEther(detail.feesUSD)}</div>
            <div className="fee-breakdown">
              <span>Token0: {ethers.utils.formatUnits(detail.fees0, 18)}</span>
              <span>Token1: {ethers.utils.formatUnits(detail.fees1, 18)}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
```

### Battle Compatibility Checker

```typescript
function JoinBattleButton({ battleId, userTokenId }: { 
  battleId: BigNumber, 
  userTokenId: BigNumber 
}) {
  const [canJoin, setCanJoin] = useState(false);
  const [reason, setReason] = useState("");
  const [battleInfo, setBattleInfo] = useState(null);
  
  useEffect(() => {
    async function checkCompatibility() {
      const [joinable, joinReason] = await contract.canJoinBattle(battleId, userTokenId);
      const info = await contract.getBattleTokenInfo(battleId);
      
      setCanJoin(joinable);
      setReason(joinReason);
      setBattleInfo(info);
    }
    checkCompatibility();
  }, [battleId, userTokenId]);
  
  const handleJoin = async () => {
    if (canJoin) {
      try {
        // Approve NFT transfer
        await positionManager.approve(contract.address, userTokenId);
        
        // Join battle
        const tx = await contract.joinBattle(battleId, userTokenId);
        await tx.wait();
        
        console.log("Successfully joined fee battle!");
      } catch (error) {
        console.error("Failed to join battle:", error);
      }
    }
  };
  
  return (
    <div className="join-battle">
      {battleInfo && (
        <div className="battle-info">
          <div>Pool: {battleInfo.poolName}</div>
          <div>Tokens: {battleInfo.token0.slice(0, 6)}.../{battleInfo.token1.slice(0, 6)}...</div>
        </div>
      )}
      <button 
        disabled={!canJoin} 
        onClick={handleJoin}
        className={canJoin ? "join-enabled" : "join-disabled"}
      >
        {canJoin ? "Join Fee Battle" : reason}
      </button>
    </div>
  );
}
```

### Battle List with Categories

```typescript
function FeeBattleList() {
  const [waitingBattles, setWaitingBattles] = useState<BigNumber[]>([]);
  const [activeBattles, setActiveBattles] = useState<[BigNumber[], string[]]>([[], []]);
  const [readyBattles, setReadyBattles] = useState<BigNumber[]>([]);
  
  useEffect(() => {
    async function loadBattles() {
      const waiting = await contract.getBattlesWaitingForOpponent();
      const active = await contract.getAllActiveBattles();
      const ready = await contract.getBattlesReadyToResolve();
      
      setWaitingBattles(waiting);
      setActiveBattles(active);
      setReadyBattles(ready);
    }
    loadBattles();
  }, []);
  
  return (
    <div className="battle-lists">
      <section>
        <h3>Waiting for Opponent ({waitingBattles.length})</h3>
        {waitingBattles.map(battleId => (
          <FeeBattleCard key={battleId.toString()} battleId={battleId} />
        ))}
      </section>
      
      <section>
        <h3>Active Fee Battles ({activeBattles[0].length})</h3>
        {activeBattles[0].map((battleId, index) => (
          <FeeBattleCard 
            key={battleId.toString()} 
            battleId={battleId} 
            status={activeBattles[1][index]} 
          />
        ))}
      </section>
      
      <section>
        <h3>Ready to Resolve ({readyBattles.length})</h3>
        {readyBattles.map(battleId => (
          <ResolvableFeeBattleCard key={battleId.toString()} battleId={battleId} />
        ))}
      </section>
    </div>
  );
}
```

## 🛠️ Development Setup

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone <repository-url>
cd bet

# Install dependencies
forge install
```

### Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
PRIVATE_KEY=your_private_key_here
RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
CHAIN_ID=11155111
```

### Testing

```bash
# Run all LPFeeBattle tests (87 total tests)
forge test --match-path test/LPFeeBattleTest.t.sol

# Run LPFeeBattle core tests (39 tests)
forge test --match-contract LPFeeBattleTest

# Run LPFeeBattle helper tests (48 tests including 9 new frontend helper tests)
forge test --match-contract LPFeeBattleHelperTest

# Test specific frontend helper functions
forge test --match-test "testGetCompleteBattleDetails|testGetDetailedFeePerformance|testCanJoinBattle"

# Run with gas report
forge test --match-path test/LPFeeBattleTest.t.sol --gas-report

# Run with verbose output
forge test --match-path test/LPFeeBattleTest.t.sol -vv
```

#### 🆕 New Test Coverage for LPFeeBattle Frontend Helpers

The following new tests ensure all frontend helper functions work correctly:

- `testGetBattleUSDValue()` - Formatted USD value display
- `testGetCompleteBattleDetails()` - Complete battle information with fee performance
- `testGetCompleteBattleDetailsAfterJoin()` - Battle details after opponent joins
- `testCanJoinBattle()` - Battle compatibility validation
- `testCanJoinBattleValueTolerance()` - Value tolerance validation  
- `testGetPositionDetails()` - Complete LP position information with fee data
- `testGetDetailedFeePerformance()` - Comprehensive fee tracking and analytics
- `testGetDetailedFeePerformanceNotStarted()` - Error handling for unstarted battles
- `testGetDetailedFeePerformanceResolved()` - Behavior for resolved battles

**Total Test Coverage**: 87 tests (48 LPFeeBattleHelperTest + 39 LPFeeBattleTest) - All passing ✅

### Gas Report Summary

**Optimized LPFeeBattle Contract Performance:**
- **Main Contract Deployment**: 3,232,133 gas (14,634 bytes)
- **StringUtils Library**: 142,205 gas (740 bytes)
- **Total System**: ~4.7M gas (with shared libraries)

**Key Function Gas Costs:**
- **createBattle**: ~220,000-240,000 gas
- **joinBattle**: ~175,000-210,000 gas  
- **resolveBattle**: ~340,000-430,000 gas
- **getBattleUSDValue**: 13,368 gas (formatted string)
- **getCompleteBattleDetails**: 28,000-93,000 gas (depending on battle state)
- **getDetailedFeePerformance**: 26,000-93,000 gas (comprehensive analytics)

### Deployment

```bash
# Deploy optimized system with libraries
forge script script/DeployLPBattleVault.s.sol --rpc-url $RPC_URL --broadcast --verify

# OR use CLI deployment script for Sepolia
chmod +x deploy-sepolia.sh
./deploy-sepolia.sh

# Check deployment status
forge script script/DeployLPBattleVault.s.sol --rpc-url $RPC_URL --broadcast --verify --resume
```

## 🔐 Security Features

### Pool-Based Pricing Security

- **Manipulation Resistance**: Uses established Uniswap V3 pools with deep liquidity
- **No External Dependencies**: Eliminates oracle manipulation vectors
- **Consensus Pricing**: Pool prices reflect market consensus
- **Real-time Updates**: Prices update with every transaction

### Battle Security

- **Ownership Verification**: Only NFT owners can create/join battles
- **Value Tolerance**: 5% tolerance prevents unfair matchups
- **Time Locks**: Minimum battle duration prevents front-running
- **Resolver Incentives**: 1% fee encourages timely resolution
- **Fee Rate Based**: Fair competition based on efficiency, not absolute amounts

### Access Control

- **Owner Functions**: Only contract owner can set stablecoins
- **Battle Isolation**: Each battle operates independently
- **Safe NFT Transfers**: Uses Uniswap's safe transfer mechanisms

## 🚨 Important Notes

### Pool-Based Pricing Considerations

1. **Stablecoin Configuration**: Ensure USDC/USDT are properly configured as stablecoins
2. **Pool Liquidity**: Prices are only reliable for pools with sufficient liquidity
3. **Price Volatility**: Pool prices may be more volatile than oracle prices
4. **Multi-Pool Price Discovery**: Contract searches multiple fee tiers for best price reference

### Fee Battle Mechanics

1. **Fee Collection**: Winners receive accumulated fees based on rate performance
2. **Resolver Rewards**: Anyone can resolve battles and earn 1% of collected fees
3. **Value Tolerance**: 5% tolerance ensures fair matchups but may limit participation
4. **Minimum Duration**: 1-hour minimum prevents instant resolution attacks
5. **Rate-Based Fairness**: Smaller LPs can compete fairly against larger ones

### Frontend Integration

1. **Use Comprehensive Helpers**: 15+ functions provide complete battle analytics
2. **Real-time Updates**: Monitor fee performance and rates live
3. **Event Listening**: Track battle lifecycle events for UI updates
4. **Error Handling**: Always check battle eligibility before joining
5. **Gas Optimization**: Batch view calls when possible

## 📞 Support

For technical support or questions:
- Create an issue in the repository
- Check existing documentation
- Review test files for usage examples

## 📄 License

MIT License - see LICENSE file for details.