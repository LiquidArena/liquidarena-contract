# LP Battle System - Pool-Based Pricing 

A DeFi protocol for Uniswap V3 LP position battles on Monad Testnet with **pool-based USD pricing** (no external oracles required). Users can compete in two types of battles: price range battles and fee accumulation battles.

## 🎯 Overview

### Contract Types

1. **LPBattleVault** - Price range battles where users compete based on whether their LP positions remain in-range at battle end
2. **LPFeeBattle** - Fee accumulation battles where users compete based on fee growth rate during battle period

### 🔥 **NEW: Pool-Based Pricing System**

Our system uses **Uniswap V3 pool prices** instead of external oracles for USD value calculations:

- ✅ **No Oracle Dependencies**: Works without Chainlink or external price feeds
- ✅ **Automatic Price Discovery**: Uses pool `sqrtPriceX96` for real-time pricing
- ✅ **Stablecoin Support**: USDC/USDT as USD reference points
- ✅ **Universal Compatibility**: Works with any token pair on Monad
- ✅ **Manipulation Resistant**: Uses on-chain pool consensus

### ⚠️ Important: Fee Collection Mechanism

Both contracts collect fees from LP positions and distribute them to the winner:

- **Winner receives**: All accumulated fees from both LP NFTs (token0 + token1)
- **Resolver receives**: 1% of total collected fees as incentive
- **Original owners receive**: Their NFTs back (with fees extracted)
- **Fee collection**: Uses Uniswap's `collect()` function to extract available fees
- **5% value tolerance**: Required for joining battles (LP positions must be within 5% value range)

### Network Information

- **Chain**: Monad Testnet (Chain ID: 10143)
- **RPC URL**: `https://testnet-rpc.monad.xyz`
- **Position Manager**: `0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7`
- **Factory**: `0x961235a9020B05C44DF1026D956D1F4D78014276`

## 🚀 Quick Start - Frontend Integration

### 1. Deploy Contracts

```bash
# Set environment variables
export PRIVATE_KEY="your_private_key"
export RPC_URL="https://testnet-rpc.monad.xyz"

# Deploy complete system with helpers
forge script script/DeployWithHelpers.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 2. Frontend Helper Contract

Use the `FrontendHelpers` contract for easy integration:

```typescript
import { FrontendHelpers__factory } from './contracts';

const helpers = FrontendHelpers__factory.connect(HELPERS_ADDRESS, provider);

// Get battle overview with all details
const battle = await helpers.getBattleOverview(battleId);

// Get all active battles
const activeBattles = await helpers.getAllActiveBattleOverviews();

// Get compatible battles for user's LP
const compatibleBattles = await helpers.getCompatibleBattles(userTokenId);

// Check if user can join a battle
const [canJoin, reason] = await helpers.canJoinBattle(battleId, userTokenId);
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
const isStable = await helpers.isStablecoin(tokenAddress);
```

## 📋 Frontend Helper Functions

### Battle Management

```typescript
interface BattleOverview {
  battleId: BigNumber;
  creator: string;
  opponent: string;
  creatorTokenId: BigNumber;
  opponentTokenId: BigNumber;
  valueUSD: BigNumber;
  status: string; // "waiting_for_opponent" | "ongoing" | "ready_to_resolve" | "resolved"
  timeRemaining: BigNumber;
  currentLeader: string;
}

// Get comprehensive battle info
const battle: BattleOverview = await helpers.getBattleOverview(battleId);

// Get all active battles
const activeBattles: BattleOverview[] = await helpers.getAllActiveBattleOverviews();

// Get battles waiting for opponents
const waitingBattles: BattleOverview[] = await helpers.getBattlesWaitingForOpponentOverviews();

// Get user's battles
const [userBattles, isCreator] = await helpers.getUserBattleOverviews(userAddress);
```

### Position Information

```typescript
interface PositionInfo {
  token0: string;
  token1: string;
  fee: number;
  tickLower: number;
  tickUpper: number;
  liquidity: BigNumber;
  amount0: BigNumber;
  amount1: BigNumber;
  valueUSD: BigNumber;
  fees0: BigNumber;
  fees1: BigNumber;
  feesUSD: BigNumber;
}

// Get detailed position info
const position: PositionInfo = await helpers.getPositionInfo(tokenId, contractAddress);
```

### Platform Statistics

```typescript
interface BattleStats {
  totalBattles: BigNumber;
  activeBattles: BigNumber;
  resolvedBattles: BigNumber;
  waitingForOpponent: BigNumber;
  totalValueLocked: BigNumber;
  averageBattleValue: BigNumber;
}

// Get platform statistics
const stats: BattleStats = await helpers.getBattleStats();
```

### Compatibility Checking

```typescript
// Check if user can join specific battle
const [canJoin, reason] = await helpers.canJoinBattle(battleId, userTokenId);

// Get all compatible battles for user's LP
const compatibleBattles = await helpers.getCompatibleBattles(userTokenId);

// Format USD values for display
const formattedValue = await helpers.formatUSDValue(valueInWei);
// Returns: "1,234.56 USD"
```

### Pool Price Information

```typescript
// Get current pool price between tokens
const [price, exists] = await helpers.getPoolPrice(token0, token1, fee);

// Price is in token1/token0 ratio with 18 decimals
if (exists) {
  console.log(`Price: ${ethers.utils.formatEther(price)} ${token1Symbol}/${token0Symbol}`);
}
```

## 🔧 Core Contract Functions

### LPBattleVault (Price Range Battles)

```typescript
interface LPBattleVault {
  // Battle management
  createBattle(tokenId: BigNumber, duration: BigNumber): Promise<BigNumber>;
  joinBattle(battleId: BigNumber, opponentTokenId: BigNumber): Promise<void>;
  resolveBattle(battleId: BigNumber): Promise<void>;
  
  // View functions
  getLPTokenValueUSD(tokenId: BigNumber): Promise<[BigNumber, BigNumber, BigNumber]>; // amount0, amount1, usdValue
  getBattleDetails(battleId: BigNumber): Promise<{
    creator: string;
    opponent: string;
    usdValue: BigNumber;
    status: string;
  }>;
  getBattleStatus(battleId: BigNumber): Promise<string>;
  
  // Configuration
  setStablecoin(token: string, isStablecoin: boolean): Promise<void>; // onlyOwner
}
```

### LPFeeBattle (Fee Accumulation Battles)

```typescript
interface LPFeeBattle {
  // Battle management  
  createBattle(tokenId: BigNumber, duration: BigNumber): Promise<BigNumber>;
  joinBattle(battleId: BigNumber, tokenId: BigNumber): Promise<void>;
  resolveBattle(battleId: BigNumber): Promise<void>;
  
  // View functions
  getLPTokenValueUSD(tokenId: BigNumber): Promise<BigNumber>;
  getCurrentFeePerformance(battleId: BigNumber): Promise<{
    creatorFeeGrowthUSD: BigNumber;
    opponentFeeGrowthUSD: BigNumber;
    creatorFeeRate: BigNumber;
    opponentFeeRate: BigNumber;
    currentLeader: string;
  }>;
  getTimeRemaining(battleId: BigNumber): Promise<BigNumber>;
  
  // Batch queries
  getAllActiveBattles(): Promise<[BigNumber[], string[]]>; // battleIds, statuses
  getBattlesWaitingForOpponent(): Promise<BigNumber[]>;
  getBattlesReadyToResolve(): Promise<BigNumber[]>;
  getUserBattles(user: string): Promise<[BigNumber[], boolean[]]>; // battleIds, isCreator
  
  // Configuration
  setStablecoin(token: string, isStablecoin: boolean): Promise<void>; // onlyOwner
}
```

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
const [canJoin, reason] = await helpers.canJoinBattle(battleId, userTokenId);

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
const status = await helpers.getBattleOverview(battleId);

if (status.status === "ready_to_resolve") {
  // 2. Anyone can resolve and earn 1% of fees
  await contract.resolveBattle(battleId);
  
  // 3. Winner gets remaining fees, NFTs returned to owners
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
  winner: string; // address(0) for draws
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
  console.log(`New battle ${battleId} created by ${creator}`);
  refreshBattleList();
});

// Listen for battle joins
contract.on("BattleJoined", (battleId, opponent, opponentTokenId) => {
  console.log(`Battle ${battleId} joined by ${opponent}`);
  updateBattleStatus(battleId);
});

// Listen for battle resolutions
contract.on("BattleResolved", (battleId, winner) => {
  console.log(`Battle ${battleId} resolved, winner: ${winner}`);
  updateBattleResult(battleId);
});
```

## 💡 Frontend Implementation Examples

### Battle List Component

```typescript
function BattleList() {
  const [battles, setBattles] = useState<BattleOverview[]>([]);
  
  useEffect(() => {
    async function loadBattles() {
      const activeBattles = await helpers.getAllActiveBattleOverviews();
      setBattles(activeBattles);
    }
    loadBattles();
  }, []);
  
  return (
    <div>
      {battles.map(battle => (
        <BattleCard key={battle.battleId.toString()} battle={battle} />
      ))}
    </div>
  );
}
```

### Join Battle Component

```typescript
function JoinBattleButton({ battleId, userTokenId }: { battleId: BigNumber, userTokenId: BigNumber }) {
  const [canJoin, setCanJoin] = useState(false);
  const [reason, setReason] = useState("");
  
  useEffect(() => {
    async function checkCompatibility() {
      const [canJoinBattle, joinReason] = await helpers.canJoinBattle(battleId, userTokenId);
      setCanJoin(canJoinBattle);
      setReason(joinReason);
    }
    checkCompatibility();
  }, [battleId, userTokenId]);
  
  const handleJoin = async () => {
    if (canJoin) {
      await positionManager.approve(contractAddress, userTokenId);
      await contract.joinBattle(battleId, userTokenId);
    }
  };
  
  return (
    <button disabled={!canJoin} onClick={handleJoin}>
      {canJoin ? "Join Battle" : reason}
    </button>
  );
}
```

### Pool Price Display

```typescript
function PoolPriceDisplay({ token0, token1, fee }: { token0: string, token1: string, fee: number }) {
  const [price, setPrice] = useState<BigNumber | null>(null);
  const [exists, setExists] = useState(false);
  
  useEffect(() => {
    async function loadPrice() {
      const [poolPrice, poolExists] = await helpers.getPoolPrice(token0, token1, fee);
      setPrice(poolPrice);
      setExists(poolExists);
    }
    loadPrice();
  }, [token0, token1, fee]);
  
  if (!exists) return <span>No pool found</span>;
  
  return (
    <span>
      Pool Price: {ethers.utils.formatEther(price!)} {token1Symbol}/{token0Symbol}
    </span>
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
RPC_URL=https://testnet-rpc.monad.xyz
CHAIN_ID=10143
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/LPFeeBattleTest.t.sol

# Run with verbose output
forge test -vv
```

### Deployment

```bash
# Deploy complete system
forge script script/DeployWithHelpers.s.sol --rpc-url $RPC_URL --broadcast --verify

# Check deployment addresses
cat deployment-addresses.txt
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

### Access Control

- **Owner Functions**: Only contract owner can set stablecoins
- **Battle Isolation**: Each battle operates independently
- **Safe NFT Transfers**: Uses Uniswap's safe transfer mechanisms

## 🚨 Important Notes

### Pool-Based Pricing Considerations

1. **Stablecoin Configuration**: Ensure USDC/USDT are properly configured as stablecoins
2. **Pool Liquidity**: Prices are only reliable for pools with sufficient liquidity
3. **Price Volatility**: Pool prices may be more volatile than oracle prices
4. **Slippage Impact**: Large trades in thin pools can affect pricing

### Battle Mechanics

1. **Fee Collection**: Winners receive accumulated fees, not the NFTs themselves
2. **Resolver Rewards**: Anyone can resolve battles and earn 1% of collected fees
3. **Value Tolerance**: 5% tolerance ensures fair matchups but may limit participation
4. **Minimum Duration**: 1-hour minimum prevents instant resolution attacks

### Frontend Integration

1. **Use FrontendHelpers**: Provides optimized functions for UI development
2. **Event Listening**: Monitor events for real-time updates
3. **Error Handling**: Always check battle eligibility before joining
4. **Gas Optimization**: Batch view calls when possible

## 📞 Support

For technical support or questions:
- Create an issue in the repository
- Check existing documentation
- Review test files for usage examples

## 📄 License

MIT License - see LICENSE file for details.