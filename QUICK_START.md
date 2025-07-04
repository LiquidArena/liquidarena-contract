# LiquidArena Protocol - Quick Start Guide

Get up and running with LiquidArena Protocol integration in minutes.

## 🚀 Installation

```bash
npm install wagmi viem @tanstack/react-query
# or
yarn add wagmi viem @tanstack/react-query
```

## 📋 Setup

### 1. Copy Contract ABIs
Copy the `CONTRACT_ABIS.ts` file to your project and import the required ABIs:

```typescript
import { 
  RANGE_BATTLE_ADDRESS, 
  FEE_BATTLE_ADDRESS,
  RANGE_BATTLE_ABI, 
  FEE_BATTLE_ABI 
} from './CONTRACT_ABIS';
```

### 2. Configure wagmi
```typescript
import { createConfig, http } from 'wagmi';
import { monadTestnet } from 'wagmi/chains';

const config = createConfig({
  chains: [monadTestnet],
  transports: {
    [monadTestnet.id]: http(),
  },
});
```

### 3. Wrap Your App
```typescript
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient();

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourApp />
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

## 🎯 Basic Usage

### Create a Range Battle
```typescript
import { useWriteContract } from 'wagmi';

function CreateBattle() {
  const { writeContract } = useWriteContract();
  
  const createBattle = () => {
    writeContract({
      address: RANGE_BATTLE_ADDRESS,
      abi: RANGE_BATTLE_ABI,
      functionName: 'createBattle',
      args: [123n, 3600n], // tokenId: 123, duration: 1 hour
    });
  };
  
  return <button onClick={createBattle}>Create Battle</button>;
}
```

### Get Battle Information
```typescript
import { useReadContract } from 'wagmi';

function BattleInfo({ battleId }: { battleId: bigint }) {
  const { data: battle } = useReadContract({
    address: RANGE_BATTLE_ADDRESS,
    abi: RANGE_BATTLE_ABI,
    functionName: 'getBattleDetails',
    args: [battleId],
  });
  
  if (!battle) return <div>Loading...</div>;
  
  const [creator, opponent, usdValue, winner, status] = battle;
  
  return (
    <div>
      <h3>Battle #{battleId.toString()}</h3>
      <p>Status: {status}</p>
      <p>Creator: {creator}</p>
      <p>Opponent: {opponent || 'Waiting...'}</p>
      <p>Value: ${(Number(usdValue) / 1e18).toFixed(2)}</p>
      {winner && <p>Winner: {winner}</p>}
    </div>
  );
}
```

### Join a Battle
```typescript
function JoinBattle({ battleId }: { battleId: bigint }) {
  const { writeContract } = useWriteContract();
  
  const joinBattle = () => {
    writeContract({
      address: RANGE_BATTLE_ADDRESS,
      abi: RANGE_BATTLE_ABI,
      functionName: 'joinBattle',
      args: [battleId, 456n], // battleId, your tokenId
    });
  };
  
  return <button onClick={joinBattle}>Join Battle</button>;
}
```

### Listen to Events
```typescript
import { useWatchContractEvent } from 'wagmi';

function EventListener() {
  useWatchContractEvent({
    address: RANGE_BATTLE_ADDRESS,
    abi: RANGE_BATTLE_ABI,
    eventName: 'BattleCreated',
    onLogs(logs) {
      logs.forEach((log) => {
        console.log('New battle created:', log.args);
      });
    },
  });
  
  return null;
}
```

## 🔥 Fee Battle Example

### Monitor Fee Performance
```typescript
function FeePerformance({ battleId }: { battleId: bigint }) {
  const { data: performance } = useReadContract({
    address: FEE_BATTLE_ADDRESS,
    abi: FEE_BATTLE_ABI,
    functionName: 'getCurrentFeePerformance',
    args: [battleId],
    query: {
      refetchInterval: 30000, // Update every 30 seconds
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
        <p>Creator: ${(Number(creatorFeeGrowthUSD) / 1e18).toFixed(4)}</p>
        <p>Rate: {Number(creatorFeeRate) / 100}% per hour</p>
      </div>
      <div>
        <p>Opponent: ${(Number(opponentFeeGrowthUSD) / 1e18).toFixed(4)}</p>
        <p>Rate: {Number(opponentFeeRate) / 100}% per hour</p>
      </div>
      <p>Leader: {currentLeader}</p>
    </div>
  );
}
```

## 🛠️ Utility Hooks

### Custom Hook for Battle Details
```typescript
import { useReadContract } from 'wagmi';

export function useBattleDetails(battleId: bigint, type: 'range' | 'fee') {
  const address = type === 'range' ? RANGE_BATTLE_ADDRESS : FEE_BATTLE_ADDRESS;
  const abi = type === 'range' ? RANGE_BATTLE_ABI : FEE_BATTLE_ABI;
  
  return useReadContract({
    address,
    abi,
    functionName: 'getBattleDetails',
    args: [battleId],
    query: {
      enabled: !!battleId,
      refetchInterval: 30000,
    },
  });
}
```

### Error Handling Hook
```typescript
import { CONTRACT_ERRORS } from './CONTRACT_ABIS';

export function useContractErrorHandler() {
  const handleError = (error: any): string => {
    const errorMessage = error.message || error.toString();
    
    if (errorMessage.includes(CONTRACT_ERRORS.NotLPOwner)) {
      return 'You must own this LP NFT to create a battle';
    }
    if (errorMessage.includes(CONTRACT_ERRORS.LPValueNotWithinTolerance)) {
      return 'LP value must be within 5% of the creator\'s position';
    }
    if (errorMessage.includes(CONTRACT_ERRORS.BattleAlreadyJoined)) {
      return 'This battle already has an opponent';
    }
    if (errorMessage.includes(CONTRACT_ERRORS.BattleNotEnded)) {
      return 'Battle is still ongoing';
    }
    
    return 'Transaction failed. Please try again.';
  };
  
  return { handleError };
}
```

## 📱 Complete Example Component

```typescript
import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useBattleDetails, useContractErrorHandler } from './hooks';

function BattleManager() {
  const [battleId, setBattleId] = useState<bigint>(1n);
  const [tokenId, setTokenId] = useState<string>('');
  
  const { data: battle } = useBattleDetails(battleId, 'range');
  const { writeContract, data: hash, error } = useWriteContract();
  const { isLoading } = useWaitForTransactionReceipt({ hash });
  const { handleError } = useContractErrorHandler();
  
  const createBattle = () => {
    if (!tokenId) return;
    
    writeContract({
      address: RANGE_BATTLE_ADDRESS,
      abi: RANGE_BATTLE_ABI,
      functionName: 'createBattle',
      args: [BigInt(tokenId), 3600n], // 1 hour battle
    });
  };
  
  const joinBattle = () => {
    if (!tokenId) return;
    
    writeContract({
      address: RANGE_BATTLE_ADDRESS,
      abi: RANGE_BATTLE_ABI,
      functionName: 'joinBattle',
      args: [battleId, BigInt(tokenId)],
    });
  };
  
  return (
    <div>
      <h2>Battle Manager</h2>
      
      <div>
        <input
          type="number"
          placeholder="Battle ID"
          value={battleId.toString()}
          onChange={(e) => setBattleId(BigInt(e.target.value || 0))}
        />
        <input
          type="number"
          placeholder="Your LP Token ID"
          value={tokenId}
          onChange={(e) => setTokenId(e.target.value)}
        />
      </div>
      
      <div>
        <button onClick={createBattle} disabled={isLoading || !tokenId}>
          {isLoading ? 'Creating...' : 'Create Battle'}
        </button>
        <button onClick={joinBattle} disabled={isLoading || !tokenId}>
          {isLoading ? 'Joining...' : 'Join Battle'}
        </button>
      </div>
      
      {error && (
        <div style={{ color: 'red' }}>
          {handleError(error)}
        </div>
      )}
      
      {battle && (
        <div>
          <h3>Battle #{battleId.toString()}</h3>
          <p>Status: {battle[4]}</p>
          <p>Creator: {battle[0]}</p>
          <p>Opponent: {battle[1] || 'Waiting...'}</p>
          <p>Value: ${(Number(battle[2]) / 1e18).toFixed(2)}</p>
          {battle[3] && <p>Winner: {battle[3]}</p>}
        </div>
      )}
    </div>
  );
}
```

## 🔗 Next Steps

1. Check out the full [Frontend Documentation](./FRONTEND_DOCS.md) for comprehensive integration details
2. Review the [Contract ABIs](./CONTRACT_ABIS.ts) for all available functions
3. Test your integration on Monad Testnet before mainnet deployment
4. Join our Discord for support and updates

## 📝 Important Notes

- Always approve LP NFT transfers before creating/joining battles
- Battle resolution can be called by anyone (earns 1% reward)
- LP values must be within 5% tolerance to join battles
- Contracts are pausable by owner for emergency situations

Happy building! 🚀
