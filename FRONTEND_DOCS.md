# LiquidArena Protocol - Frontend Integration Guide

A PvP DeFi prediction protocol where users duel with Uniswap V3 LP NFTs in battles resolved by price range validity or fee performance.

## 🚀 Deployed Contracts (Monad Testnet)

- **LPBattleVault (Range Battles)**: `0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6`
- **LPFeeBattle (Fee Battles)**: `0x18d6b03A4A0499077A2dc8c45fFf8DA10aF16f64`

## 📋 Contract Overview

### LPBattleVault - Range-Based Battles
LP positions compete based on whether their price ranges remain valid during the battle period. Winners are determined by whose LP position stays "in range" longer.

### LPFeeBattle - Fee-Based Battles  
LP positions compete based on fee accumulation rates. Winners are determined by whose LP position generates more fees relative to their liquidity.

## 🔧 Frontend Integration

### Core Data Types

#### Battle Status
```typescript
type BattleStatus = 'queued' | 'onGoing' | 'readyToResolve' | 'ended';
```

#### Battle Structure (Range Battles)
```typescript
interface RangeBattle {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  totalValueUSD: bigint;
  creatorTickLower: number;
  creatorTickUpper: number;
  opponentTickLower: number;
  opponentTickUpper: number;
}
```

#### Battle Structure (Fee Battles)
```typescript
interface FeeBattle {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  creatorLPValue: bigint;
  creatorStartFee0: bigint;
  creatorStartFee1: bigint;
  opponentStartFee0: bigint;
  opponentStartFee1: bigint;
}
```

### Constants

#### LPBattleVault Constants
```typescript
const RANGE_BATTLE_CONSTANTS = {
  RESOLVER_REWARD_BPS: 100n, // 1%
  MIN_BATTLE_DURATION: 300n, // 5 minutes
  MAX_BATTLE_DURATION: 604800n, // 7 days
  LP_VALUE_TOLERANCE_BPS: 500n, // 5%
  PRICE_STALENESS_THRESHOLD: 18000n, // 5 hours
} as const;
```

#### LPFeeBattle Constants
```typescript
const FEE_BATTLE_CONSTANTS = {
  RESOLVER_REWARD_BPS: 100n, // 1%
  MIN_BATTLE_DURATION: 3600n, // 1 hour
  PRICE_STALENESS_THRESHOLD: 18000n, // 5 hours
} as const;
```

## 📖 Contract Functions Reference

### LPBattleVault (Range Battles)

#### Core Battle Functions

##### `createBattle(tokenId: bigint, duration: bigint): Promise<bigint>`
Creates a new range-based battle.
- **tokenId**: Uniswap V3 LP NFT token ID
- **duration**: Battle duration in seconds (5 minutes to 7 days)
- **Returns**: Battle ID
- **Events**: `BattleCreated(battleId, creator, tokenId, duration, totalValueUSD)`

##### `joinBattle(battleId: bigint, tokenId: bigint): Promise<void>`
Join an existing battle as opponent.
- **battleId**: ID of battle to join
- **tokenId**: Opponent's LP NFT token ID
- **Requirements**: LP value must be within 5% tolerance
- **Events**: `BattleJoined(battleId, opponent, tokenId, startTime)`

##### `resolveBattle(battleId: bigint): Promise<void>`
Resolve a completed battle.
- **battleId**: ID of battle to resolve
- **Requirements**: Battle must be ended and not already resolved
- **Events**: `BattleResolved(battleId, winner, resolver, resolverReward)`

#### View Functions

##### `getBattleDetails(battleId: bigint)`
```typescript
interface BattleDetails {
  creator: string;
  opponent: string;
  usdValue: bigint;
  winner: string;
  status: BattleStatus;
}
```

##### `getCompleteBattleDetails(battleId: bigint)`
```typescript
interface CompleteBattleDetails {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  valueUSD: bigint;
  status: BattleStatus;
  creatorInRange: boolean;
  opponentInRange: boolean;
  currentTick: number;
}
```

##### `getBattleStatus(battleId: bigint): Promise<BattleStatus>`
Returns current battle status.

##### `getBattleUSDValue(battleId: bigint): Promise<string>`
Returns formatted USD value (e.g., "$1,234.56").

##### `getBattleTokenInfo(battleId: bigint)`
```typescript
interface TokenInfo {
  token0: string;
  token1: string;
  fee: number;
  poolName: string;
}
```

### LPFeeBattle (Fee Battles)

#### Core Battle Functions

##### `createBattle(tokenId: bigint, duration: bigint): Promise<bigint>`
Creates a new fee-based battle.
- **tokenId**: Uniswap V3 LP NFT token ID  
- **duration**: Battle duration in seconds (minimum 1 hour)
- **Returns**: Battle ID
- **Events**: `BattleCreated(battleId, creator, tokenId)`

##### `joinBattle(battleId: bigint, tokenId: bigint): Promise<void>`
Join an existing battle as opponent.
- **battleId**: ID of battle to join
- **tokenId**: Opponent's LP NFT token ID
- **Requirements**: LP value must be within 5% tolerance
- **Events**: `BattleJoined(battleId, opponent, tokenId)`

##### `resolveBattle(battleId: bigint): Promise<void>`
Resolve a completed battle.
- **battleId**: ID of battle to resolve
- **Events**: `BattleResolved(battleId, winner)`

#### View Functions

##### `getBattleDetails(battleId: bigint)`
```typescript
interface FeeBattleDetails {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  creatorLPValueUSD: bigint;
  status: BattleStatus;
}
```

##### `getCurrentFeePerformance(battleId: bigint)`
```typescript
interface FeePerformance {
  creatorFeeGrowthUSD: bigint;
  opponentFeeGrowthUSD: bigint;
  creatorFeeRate: bigint; // Fee rate per hour in basis points
  opponentFeeRate: bigint;
  currentLeader: string;
}
```

##### `getDetailedFeePerformance(battleId: bigint)`
```typescript
interface DetailedFeePerformance {
  creatorStartFees: bigint;
  opponentStartFees: bigint;
  creatorCurrentFees: bigint;
  opponentCurrentFees: bigint;
  creatorFeeGrowthUSD: bigint;
  opponentFeeGrowthUSD: bigint;
  creatorFeeRate: bigint;
  opponentFeeRate: bigint;
  currentLeader: string;
  leadReason: string;
}
```

##### `getCompleteBattleDetails(battleId: bigint)`
Returns comprehensive battle information including fee performance data.

##### `getBattleUSDValue(battleId: bigint): Promise<string>`
Returns formatted USD value.

##### `getBattleTokenInfo(battleId: bigint)`
Returns token and pool information.

## 🎯 Events

### LPBattleVault Events
```typescript
// Battle created
event BattleCreated(
  uint256 indexed battleId,
  address indexed creator, 
  uint256 creatorTokenId,
  uint256 duration,
  uint256 totalValueUSD
);

// Battle joined
event BattleJoined(
  uint256 indexed battleId,
  address indexed opponent,
  uint256 opponentTokenId, 
  uint256 startTime
);

// Battle resolved
event BattleResolved(
  uint256 indexed battleId,
  address indexed winner,
  address indexed resolver,
  uint256 resolverReward
);
```

### LPFeeBattle Events
```typescript
// Battle created
event BattleCreated(
  uint256 indexed battleId,
  address indexed creator,
  uint256 creatorTokenId
);

// Battle joined  
event BattleJoined(
  uint256 indexed battleId,
  address indexed opponent,
  uint256 opponentTokenId
);

// Battle resolved
event BattleResolved(
  uint256 indexed battleId,
  address indexed winner
);
```

## ⚠️ Error Handling

### Common Errors
```typescript
// Custom errors that can be thrown
const ERRORS = {
  NotOwner: 'NotOwner()',
  NotLPOwner: 'NotLPOwner()',
  BattleAlreadyJoined: 'BattleAlreadyJoined()',
  BattleAlreadyResolved: 'BattleAlreadyResolved()',
  BattleNotEnded: 'BattleNotEnded()',
  BattleNotStarted: 'BattleNotStarted()',
  LPValueNotWithinTolerance: 'LPValueNotWithinTolerance()',
  BattleDoesNotExist: 'BattleDoesNotExist()',
  BattleDurationTooLong: 'BattleDurationTooLong(uint256,uint256)',
  PriceFeedNotSet: 'PriceFeedNotSet()',
  StalePrice: 'StalePrice()',
} as const;
```

## 🔗 Integration Examples

### Using wagmi/viem

#### Create a Range Battle
```typescript
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';

const RANGE_BATTLE_ADDRESS = '0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6';

function CreateRangeBattle() {
  const { writeContract, data: hash } = useWriteContract();

  const createBattle = async (tokenId: bigint, duration: bigint) => {
    writeContract({
      address: RANGE_BATTLE_ADDRESS,
      abi: rangeBattleAbi,
      functionName: 'createBattle',
      args: [tokenId, duration],
    });
  };

  const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash });

  return (
    <button
      onClick={() => createBattle(123n, 3600n)} // 1 hour battle
      disabled={isLoading}
    >
      {isLoading ? 'Creating...' : 'Create Battle'}
    </button>
  );
}
```

#### Get Battle Details
```typescript
import { useReadContract } from 'wagmi';

function BattleDetails({ battleId }: { battleId: bigint }) {
  const { data: battleDetails } = useReadContract({
    address: RANGE_BATTLE_ADDRESS,
    abi: rangeBattleAbi,
    functionName: 'getCompleteBattleDetails',
    args: [battleId],
  });

  if (!battleDetails) return <div>Loading...</div>;

  const [
    creator,
    opponent,
    creatorTokenId,
    opponentTokenId,
    isResolved,
    winner,
    startTime,
    duration,
    valueUSD,
    status,
    creatorInRange,
    opponentInRange,
    currentTick
  ] = battleDetails;

  return (
    <div>
      <h3>Battle #{battleId.toString()}</h3>
      <p>Status: {status}</p>
      <p>Creator: {creator}</p>
      <p>Opponent: {opponent || 'Waiting...'}</p>
      <p>Value: ${(Number(valueUSD) / 1e18).toFixed(2)}</p>
      {winner && <p>Winner: {winner}</p>}
    </div>
  );
}
```

#### Monitor Fee Battle Performance
```typescript
function FeeBattlePerformance({ battleId }: { battleId: bigint }) {
  const { data: performance } = useReadContract({
    address: '0x18d6b03A4A0499077A2dc8c45fFf8DA10aF16f64',
    abi: feeBattleAbi,
    functionName: 'getCurrentFeePerformance',
    args: [battleId],
    query: {
      refetchInterval: 30000, // Refresh every 30 seconds
    },
  });

  if (!performance) return <div>Loading...</div>;

  const [
    creatorFeeGrowthUSD,
    opponentFeeGrowthUSD,
    creatorFeeRate,
    opponentFeeRate,
    currentLeader
  ] = performance;

  return (
    <div>
      <h3>Fee Performance</h3>
      <div>
        <p>Creator Fee Growth: ${(Number(creatorFeeGrowthUSD) / 1e18).toFixed(4)}</p>
        <p>Creator Rate: {Number(creatorFeeRate) / 100}% per hour</p>
      </div>
      <div>
        <p>Opponent Fee Growth: ${(Number(opponentFeeGrowthUSD) / 1e18).toFixed(4)}</p>
        <p>Opponent Rate: {Number(opponentFeeRate) / 100}% per hour</p>
      </div>
      <p>Current Leader: {currentLeader}</p>
    </div>
  );
}
```

#### Listen to Battle Events
```typescript
import { useWatchContractEvent } from 'wagmi';

function BattleEventListener() {
  useWatchContractEvent({
    address: RANGE_BATTLE_ADDRESS,
    abi: rangeBattleAbi,
    eventName: 'BattleCreated',
    onLogs(logs) {
      logs.forEach((log) => {
        console.log('New battle created:', {
          battleId: log.args.battleId,
          creator: log.args.creator,
          tokenId: log.args.creatorTokenId,
          duration: log.args.duration,
          valueUSD: log.args.totalValueUSD,
        });
      });
    },
  });

  useWatchContractEvent({
    address: RANGE_BATTLE_ADDRESS,
    abi: rangeBattleAbi,
    eventName: 'BattleResolved',
    onLogs(logs) {
      logs.forEach((log) => {
        console.log('Battle resolved:', {
          battleId: log.args.battleId,
          winner: log.args.winner,
          resolver: log.args.resolver,
          reward: log.args.resolverReward,
        });
      });
    },
  });

  return null;
}
```

## 🛡️ Security Considerations

1. **LP NFT Approval**: Users must approve the contract to transfer their LP NFTs before creating/joining battles
2. **Battle Resolution**: Anyone can resolve ended battles and earn 1% resolver reward
3. **Emergency Functions**: Owner can pause contracts and perform emergency withdrawals
4. **Price Feeds**: Contracts use Chainlink price feeds with staleness checks (5 hours max)
5. **Reentrancy Protection**: All state-changing functions use reentrancy guards

## 📊 Battle Lifecycle

### Range Battles
1. **Create**: User deposits LP NFT and sets duration
2. **Queue**: Battle waits for opponent to join
3. **Join**: Opponent deposits similar-value LP NFT
4. **Ongoing**: Battle runs for specified duration
5. **Ready to Resolve**: Battle ended, waiting for resolution
6. **Ended**: Winner determined, fees distributed, NFTs returned

### Fee Battles
1. **Create**: User deposits LP NFT and sets duration
2. **Queue**: Battle waits for opponent
3. **Join**: Opponent deposits similar-value LP NFT, fees recorded
4. **Ongoing**: Battle tracks fee accumulation
5. **Ready to Resolve**: Battle ended, waiting for resolution
6. **Ended**: Winner determined by fee performance, rewards distributed

## 🔧 Utility Functions

Both contracts include helper functions for frontend integration:
- `getBattleStatus()`: Get current battle state
- `getBattleUSDValue()`: Get formatted USD values
- `getBattleTokenInfo()`: Get token pair and pool information
- `getCompleteBattleDetails()`: Get comprehensive battle data

## 💡 Best Practices

### State Management
```typescript
// Use React Query or SWR for efficient data fetching
import { useQuery } from '@tanstack/react-query';

function useBattleDetails(battleId: bigint) {
  return useQuery({
    queryKey: ['battle', battleId.toString()],
    queryFn: () => getBattleDetails(battleId),
    refetchInterval: 30000, // Refresh every 30 seconds
    enabled: !!battleId,
  });
}
```

### Error Handling
```typescript
function handleContractError(error: any) {
  if (error.message.includes('NotLPOwner')) {
    return 'You must own this LP NFT to create a battle';
  }
  if (error.message.includes('LPValueNotWithinTolerance')) {
    return 'LP value must be within 5% of the creator\'s position';
  }
  if (error.message.includes('BattleAlreadyJoined')) {
    return 'This battle already has an opponent';
  }
  return 'Transaction failed. Please try again.';
}
```

### Real-time Updates
```typescript
// Combine contract events with periodic polling for real-time updates
function useBattleUpdates(battleId: bigint) {
  const [battleData, setBattleData] = useState(null);

  // Poll for updates
  useEffect(() => {
    const interval = setInterval(async () => {
      const data = await getBattleDetails(battleId);
      setBattleData(data);
    }, 15000); // Every 15 seconds

    return () => clearInterval(interval);
  }, [battleId]);

  // Listen for events
  useWatchContractEvent({
    address: RANGE_BATTLE_ADDRESS,
    abi: rangeBattleAbi,
    eventName: 'BattleJoined',
    args: { battleId },
    onLogs: () => {
      // Immediately refresh data when battle is joined
      getBattleDetails(battleId).then(setBattleData);
    },
  });

  return battleData;
}
```

## 🎨 UI Components Examples

### Battle Card Component
```typescript
interface BattleCardProps {
  battleId: bigint;
  type: 'range' | 'fee';
}

function BattleCard({ battleId, type }: BattleCardProps) {
  const { data: battle } = useBattleDetails(battleId);
  const { data: tokenInfo } = useBattleTokenInfo(battleId);

  if (!battle || !tokenInfo) return <BattleCardSkeleton />;

  return (
    <div className="battle-card">
      <div className="battle-header">
        <h3>Battle #{battleId.toString()}</h3>
        <span className={`status ${battle.status}`}>
          {battle.status}
        </span>
      </div>

      <div className="battle-info">
        <p>Pool: {tokenInfo.poolName}</p>
        <p>Value: {battle.formattedValue}</p>
        <p>Duration: {formatDuration(battle.duration)}</p>
      </div>

      <div className="participants">
        <div className="participant">
          <span>Creator:</span>
          <Address address={battle.creator} />
        </div>
        {battle.opponent && (
          <div className="participant">
            <span>Opponent:</span>
            <Address address={battle.opponent} />
          </div>
        )}
      </div>

      {battle.status === 'queued' && (
        <JoinBattleButton battleId={battleId} />
      )}

      {battle.status === 'readyToResolve' && (
        <ResolveBattleButton battleId={battleId} />
      )}
    </div>
  );
}
```

## 📱 Mobile Considerations

- Use responsive design for battle cards and lists
- Implement pull-to-refresh for battle updates
- Consider using WebSocket connections for real-time updates on mobile
- Optimize gas estimation for mobile wallet integration

## 🔍 Testing Integration

```typescript
// Mock contract calls for testing
const mockBattleDetails = {
  creator: '0x123...',
  opponent: '0x456...',
  status: 'onGoing',
  valueUSD: 1000000000000000000n, // 1 ETH in wei
  // ... other fields
};

// Test component with mock data
test('BattleCard displays correct information', () => {
  render(<BattleCard battleId={1n} type="range" />);
  expect(screen.getByText('Battle #1')).toBeInTheDocument();
  expect(screen.getByText('onGoing')).toBeInTheDocument();
});
```

## 📝 License

MIT
```
