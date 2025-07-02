# 🎯 LPBattleVault Contract - Frontend Integration Guide

## 📋 Overview

LPBattleVault enables competitive battles between Uniswap V3 LP positions using **Chainlink price feeds** for accurate USD valuations.

**Contract Address (Monad Testnet)**: `0x1D570D83E56d6791393F5BA407d8d40629C202d4`

## 🚀 Key Features

- ✅ **Chainlink Price Feeds** - Real market prices for accurate LP valuations
- ✅ **5% Tolerance System** - Fair battles with similar value LP positions  
- ✅ **Cross-Pool Support** - Battle between different pools
- ✅ **Gas Optimized** - Custom errors and efficient patterns

## 💰 Supported Tokens (Monad Testnet)

| Token | Address | Price Feed | Status |
|-------|---------|------------|--------|
| **USDC** | `0xf817257fed379853cDe0fa4F97AB987181B1E5Ea` | ✅ USD/USD | Stablecoin |
| **USDT** | `0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D` | ✅ USD/USD | Stablecoin |
| **WETH** | `0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37` | ✅ ETH/USD | Supported |
| **WBTC** | `0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d` | ✅ BTC/USD | Supported |

**Supported LP Pairs**: WETH/USDC, WETH/USDT, WBTC/USDC, WBTC/USDT, USDC/USDT

## 📊 Frontend Integration Functions

### **🎮 Battle Operations (Write Functions)**
```solidity
// Create a new battle with LP NFT
function createBattle(uint256 tokenId, uint256 durations) external returns (uint256 battleId)

// Join an existing battle
function joinBattle(uint256 battleId, uint256 opponentTokenId) external

// Resolve completed battle (anyone can call)
function resolveBattle(uint256 battleId) external
```

### **📋 Battle Information (Read Functions)**
```solidity
// Get basic battle info
function getBattleDetails(uint256 battleId) external view 
    returns (address creator, address opponent, uint256 usdValue, string memory status)

// Get battle status: "queued", "onGoing", "readyToResolve", "ended"
function getBattleStatus(uint256 battleId) external view returns (string memory)

// Get formatted USD value with decimals
function getBattleUSDValue(uint256 battleId) external view returns (string memory)

// Get remaining time in seconds
function getTimeRemaining(uint256 battleId) external view returns (uint256)

// Check if user can join battle
function canJoinBattle(uint256 battleId, uint256 userTokenId) external view 
    returns (bool canJoin, string memory reason)
```

### **🔍 Advanced Battle Information**
```solidity
// Get complete battle details for UI
function getCompleteBattleDetails(uint256 battleId) external view returns (
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

// Get real-time battle performance
function getCurrentPerformance(uint256 battleId) external view returns (
    bool creatorInRange,
    bool opponentInRange,
    uint256 creatorFees,
    uint256 opponentFees,
    address currentLeader,
    string memory leadReason
)

// Get battle token info
function getBattleTokenInfo(uint256 battleId) external view returns (
    address token0,
    address token1,
    uint24 fee,
    string memory poolName
)
```

### **💰 LP Position Functions**
```solidity
// Get LP token USD value with amounts
function getLPTokenValueUSD(uint256 tokenId) external view 
    returns (uint256 amount0, uint256 amount1, uint256 usdValue)

// Get complete position details
function getPositionDetails(uint256 tokenId) external view returns (
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
```

### **🔍 Discovery Functions**
```solidity
// Get all active battles
function getAllActiveBattles() external view 
    returns (uint256[] memory battleIds, string[] memory statuses)

// Get battles waiting for opponents
function getBattlesWaitingForOpponent() external view 
    returns (uint256[] memory battleIds)

// Get battles ready to resolve
function getBattlesReadyToResolve() external view 
    returns (uint256[] memory battleIds)

// Get user's battles
function getUserBattles(address user) external view 
    returns (uint256[] memory battleIds, bool[] memory isCreator)

// Get battle counter
function battleIdCounter() external view returns (uint256)
```

## 🎮 Frontend Implementation Guide

### **⚙️ Contract Setup**
```typescript
import { ethers } from 'ethers';

const CONTRACT_ADDRESS = '0x1D570D83E56d6791393F5BA407d8d40629C202d4';
const POSITION_MANAGER = '0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7';
const RPC_URL = 'https://testnet-rpc.monad.xyz';

// Contract ABI (include all functions you need)
const BATTLE_VAULT_ABI = [
  // Write functions
  "function createBattle(uint256 tokenId, uint256 durations) external returns (uint256)",
  "function joinBattle(uint256 battleId, uint256 opponentTokenId) external",
  "function resolveBattle(uint256 battleId) external",
  
  // Read functions
  "function getBattleDetails(uint256) external view returns (address, address, uint256, string)",
  "function getBattleStatus(uint256) external view returns (string)",
  "function getBattleUSDValue(uint256) external view returns (string)",
  "function getTimeRemaining(uint256) external view returns (uint256)",
  "function canJoinBattle(uint256, uint256) external view returns (bool, string)",
  "function getCompleteBattleDetails(uint256) external view returns (address, address, uint256, uint256, bool, address, uint256, uint256, uint256, string, bool, bool, int24)",
  "function getCurrentPerformance(uint256) external view returns (bool, bool, uint256, uint256, address, string)",
  "function getLPTokenValueUSD(uint256) external view returns (uint256, uint256, uint256)",
  "function getPositionDetails(uint256) external view returns (address, address, uint24, int24, int24, uint128, uint256, uint256, uint256, uint256, uint256)",
  "function getAllActiveBattles() external view returns (uint256[], string[])",
  "function getBattlesWaitingForOpponent() external view returns (uint256[])",
  "function getUserBattles(address) external view returns (uint256[], bool[])",
  "function battleIdCounter() external view returns (uint256)",
  
  // Events
  "event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 creatorTokenId)",
  "event BattleJoined(uint256 indexed battleId, address indexed opponent, uint256 opponentTokenId)",
  "event BattleResolved(uint256 indexed battleId, address indexed winner)"
];

// Setup provider and contract
const provider = new ethers.JsonRpcProvider(RPC_URL);
const contract = new ethers.Contract(CONTRACT_ADDRESS, BATTLE_VAULT_ABI, provider);
```

### **1️⃣ Create Battle Flow**
```typescript
async function createBattle(signer: ethers.Signer, tokenId: number, duration: number) {
  try {
    // 1. Get LP position details first
    const positionDetails = await contract.getPositionDetails(tokenId);
    console.log('Position USD Value:', ethers.formatEther(positionDetails.valueUSD));
    
    // 2. Approve NFT to contract
    const positionManager = new ethers.Contract(POSITION_MANAGER, [
      "function approve(address, uint256) external"
    ], signer);
    
    console.log('Approving NFT...');
    const approveTx = await positionManager.approve(CONTRACT_ADDRESS, tokenId);
    await approveTx.wait();
    
    // 3. Create battle
    console.log('Creating battle...');
    const contractWithSigner = contract.connect(signer);
    const createTx = await contractWithSigner.createBattle(tokenId, duration);
    const receipt = await createTx.wait();
    
    // 4. Extract battle ID from events
    const battleCreatedEvent = receipt.logs.find(log => 
      log.topics[0] === ethers.id("BattleCreated(uint256,address,uint256)")
    );
    const battleId = parseInt(battleCreatedEvent?.topics[1] || '0', 16);
    
    console.log('Battle created with ID:', battleId);
    return battleId;
    
  } catch (error) {
    console.error('Create battle failed:', error);
    throw error;
  }
}
```

### **2️⃣ Join Battle Flow**
```typescript
async function joinBattle(signer: ethers.Signer, battleId: number, tokenId: number) {
  try {
    // 1. Check if user can join
    const [canJoin, reason] = await contract.canJoinBattle(battleId, tokenId);
    if (!canJoin) {
      throw new Error(`Cannot join battle: ${reason}`);
    }
    
    // 2. Get battle and position details
    const battleDetails = await contract.getBattleDetails(battleId);
    const positionDetails = await contract.getPositionDetails(tokenId);
    
    console.log('Battle USD Value:', ethers.formatEther(battleDetails.usdValue));
    console.log('Your Position USD Value:', ethers.formatEther(positionDetails.valueUSD));
    
    // 3. Approve NFT
    const positionManager = new ethers.Contract(POSITION_MANAGER, [
      "function approve(address, uint256) external"
    ], signer);
    
    console.log('Approving NFT...');
    const approveTx = await positionManager.approve(CONTRACT_ADDRESS, tokenId);
    await approveTx.wait();
    
    // 4. Join battle
    console.log('Joining battle...');
    const contractWithSigner = contract.connect(signer);
    const joinTx = await contractWithSigner.joinBattle(battleId, tokenId);
    await joinTx.wait();
    
    console.log('Successfully joined battle!');
    
  } catch (error) {
    console.error('Join battle failed:', error);
    throw error;
  }
}
```

### **3️⃣ Monitor Battle Status**
```typescript
interface BattleInfo {
  id: number;
  creator: string;
  opponent: string;
  status: string;
  timeRemaining: number;
  usdValue: string;
  winner?: string;
  creatorInRange?: boolean;
  opponentInRange?: boolean;
  currentLeader?: string;
  leadReason?: string;
}

async function getBattleInfo(battleId: number): Promise<BattleInfo> {
  try {
    // Get complete battle details
    const details = await contract.getCompleteBattleDetails(battleId);
    const timeRemaining = await contract.getTimeRemaining(battleId);
    const usdValue = await contract.getBattleUSDValue(battleId);
    
    const battleInfo: BattleInfo = {
      id: battleId,
      creator: details[0],
      opponent: details[1],
      status: details[9], // status string
      timeRemaining: Number(timeRemaining),
      usdValue: usdValue,
      winner: details[5] !== ethers.ZeroAddress ? details[5] : undefined,
      creatorInRange: details[10],
      opponentInRange: details[11]
    };
    
    // Get current performance if battle is active
    if (battleInfo.status === 'onGoing') {
      try {
        const performance = await contract.getCurrentPerformance(battleId);
        battleInfo.currentLeader = performance[4] !== ethers.ZeroAddress ? performance[4] : undefined;
        battleInfo.leadReason = performance[5];
      } catch (error) {
        console.log('Could not get performance data:', error.message);
      }
    }
    
    return battleInfo;
    
  } catch (error) {
    console.error('Get battle info failed:', error);
    throw error;
  }
}

// Auto-refresh battle status
function startBattleMonitoring(battleId: number, onUpdate: (info: BattleInfo) => void) {
  const interval = setInterval(async () => {
    try {
      const info = await getBattleInfo(battleId);
      onUpdate(info);
      
      // Stop monitoring if battle is resolved
      if (info.status === 'ended') {
        clearInterval(interval);
      }
    } catch (error) {
      console.error('Monitoring error:', error);
    }
  }, 10000); // Update every 10 seconds
  
  return interval;
}
```

### **4️⃣ Resolve Battle**
```typescript
async function resolveBattle(signer: ethers.Signer, battleId: number) {
  try {
    // 1. Check if battle is ready to resolve
    const status = await contract.getBattleStatus(battleId);
    const timeRemaining = await contract.getTimeRemaining(battleId);
    
    if (status !== 'readyToResolve' && timeRemaining > 0) {
      throw new Error(`Battle not ready to resolve. Status: ${status}, Time remaining: ${timeRemaining}s`);
    }
    
    // 2. Resolve battle
    console.log('Resolving battle...');
    const contractWithSigner = contract.connect(signer);
    const resolveTx = await contractWithSigner.resolveBattle(battleId);
    const receipt = await resolveTx.wait();
    
    // 3. Get battle results
    const updatedInfo = await getBattleInfo(battleId);
    console.log('Battle resolved! Winner:', updatedInfo.winner);
    
    return updatedInfo;
    
  } catch (error) {
    console.error('Resolve battle failed:', error);
    throw error;
  }
}
```

### **5️⃣ Discovery Functions**
```typescript
// Get all active battles for homepage
async function getAllBattles() {
  const [battleIds, statuses] = await contract.getAllActiveBattles();
  
  const battles = await Promise.all(
    battleIds.map(async (id: bigint, index: number) => {
      const battleInfo = await getBattleInfo(Number(id));
      return battleInfo;
    })
  );
  
  return battles;
}

// Get user's battles for profile page
async function getUserBattles(userAddress: string) {
  const [battleIds, isCreatorArray] = await contract.getUserBattles(userAddress);
  
  const battles = await Promise.all(
    battleIds.map(async (id: bigint, index: number) => {
      const battleInfo = await getBattleInfo(Number(id));
      return {
        ...battleInfo,
        isCreator: isCreatorArray[index]
      };
    })
  );
  
  return battles;
}

// Get battles waiting for opponents
async function getOpenBattles() {
  const battleIds = await contract.getBattlesWaitingForOpponent();
  
  const battles = await Promise.all(
    battleIds.map(async (id: bigint) => await getBattleInfo(Number(id)))
  );
  
  return battles;
}
```

### **6️⃣ LP Position Helpers**
```typescript
// Get LP position value for validation
async function getPositionValue(tokenId: number) {
  const [amount0, amount1, usdValue] = await contract.getLPTokenValueUSD(tokenId);
  const details = await contract.getPositionDetails(tokenId);
  
  return {
    tokenId,
    token0: details[0],
    token1: details[1],
    fee: details[2],
    amount0: ethers.formatEther(amount0),
    amount1: ethers.formatEther(amount1),
    usdValue: ethers.formatEther(usdValue),
    fees0: ethers.formatEther(details[9]),
    fees1: ethers.formatEther(details[10])
  };
}

// Check if two positions can battle
async function canPositionsBattle(tokenId1: number, tokenId2: number) {
  const [pos1, pos2] = await Promise.all([
    getPositionValue(tokenId1),
    getPositionValue(tokenId2)
  ]);
  
  const value1 = parseFloat(pos1.usdValue);
  const value2 = parseFloat(pos2.usdValue);
  const tolerance = 0.05; // 5%
  
  const withinTolerance = Math.abs(value1 - value2) / Math.max(value1, value2) <= tolerance;
  
  return {
    canBattle: withinTolerance,
    position1: pos1,
    position2: pos2,
    valueDifference: Math.abs(value1 - value2),
    tolerancePercentage: (Math.abs(value1 - value2) / Math.max(value1, value2)) * 100
  };
}
```

### **7️⃣ Event Listening & Real-time Updates**
```typescript
// Listen to battle events for real-time updates
function setupEventListeners() {
  // Battle Created Events
  contract.on('BattleCreated', (battleId, creator, creatorTokenId, event) => {
    console.log('New battle created:', {
      battleId: Number(battleId),
      creator,
      creatorTokenId: Number(creatorTokenId),
      txHash: event.transactionHash
    });
    
    // Update UI with new battle
    // refreshBattlesList();
  });
  
  // Battle Joined Events
  contract.on('BattleJoined', (battleId, opponent, opponentTokenId, event) => {
    console.log('Battle joined:', {
      battleId: Number(battleId),
      opponent,
      opponentTokenId: Number(opponentTokenId),
      txHash: event.transactionHash
    });
    
    // Update specific battle UI
    // refreshBattleDetails(Number(battleId));
  });
  
  // Battle Resolved Events
  contract.on('BattleResolved', (battleId, winner, event) => {
    console.log('Battle resolved:', {
      battleId: Number(battleId),
      winner,
      txHash: event.transactionHash
    });
    
    // Update battle results
    // showBattleResults(Number(battleId), winner);
  });
}

// Clean up event listeners
function cleanupEventListeners() {
  contract.removeAllListeners('BattleCreated');
  contract.removeAllListeners('BattleJoined');
  contract.removeAllListeners('BattleResolved');
}
```

### **8️⃣ Error Handling & Custom Errors**
```typescript
// Custom error handling for contract errors
function handleContractError(error: any): string {
  const errorMessage = error.message || error.toString();
  
  // Check for specific contract errors
  if (errorMessage.includes('NotLPOwner')) {
    return 'You do not own this LP NFT';
  }
  if (errorMessage.includes('BattleAlreadyResolved')) {
    return 'This battle has already been resolved';
  }
  if (errorMessage.includes('BattleAlreadyJoined')) {
    return 'This battle already has an opponent';
  }
  if (errorMessage.includes('LPValueNotWithinTolerance')) {
    return 'LP value must be within 5% of creator\'s position';
  }
  if (errorMessage.includes('BattleNotEnded')) {
    return 'Battle is still in progress';
  }
  if (errorMessage.includes('NoOpponentJoined')) {
    return 'No opponent has joined this battle';
  }
  if (errorMessage.includes('PriceFeedNotSet')) {
    return 'Price feed not available for this token';
  }
  if (errorMessage.includes('StalePrice')) {
    return 'Price data is stale, please try again';
  }
  
  // Generic error handling
  if (errorMessage.includes('user rejected')) {
    return 'Transaction was cancelled by user';
  }
  if (errorMessage.includes('insufficient funds')) {
    return 'Insufficient gas fees';
  }
  
  return 'Transaction failed. Please check console for details.';
}

// Usage example
async function safeCreateBattle(signer: ethers.Signer, tokenId: number, duration: number) {
  try {
    return await createBattle(signer, tokenId, duration);
  } catch (error) {
    const userFriendlyMessage = handleContractError(error);
    throw new Error(userFriendlyMessage);
  }
}
```

### **9️⃣ React Hook Example**
```typescript
import { useState, useEffect, useCallback } from 'react';

// Custom hook for battle management
export function useBattle(battleId: number | null) {
  const [battleInfo, setBattleInfo] = useState<BattleInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const refreshBattle = useCallback(async () => {
    if (!battleId) return;
    
    setLoading(true);
    setError(null);
    
    try {
      const info = await getBattleInfo(battleId);
      setBattleInfo(info);
    } catch (err) {
      setError(handleContractError(err));
    } finally {
      setLoading(false);
    }
  }, [battleId]);
  
  // Auto-refresh battle info
  useEffect(() => {
    if (!battleId) return;
    
    refreshBattle();
    const interval = startBattleMonitoring(battleId, setBattleInfo);
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [battleId, refreshBattle]);
  
  return {
    battleInfo,
    loading,
    error,
    refreshBattle
  };
}

// Custom hook for user's battles
export function useUserBattles(userAddress: string | null) {
  const [battles, setBattles] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  
  useEffect(() => {
    if (!userAddress) return;
    
    const fetchUserBattles = async () => {
      setLoading(true);
      try {
        const userBattles = await getUserBattles(userAddress);
        setBattles(userBattles);
      } catch (error) {
        console.error('Error fetching user battles:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchUserBattles();
  }, [userAddress]);
  
  return { battles, loading };
}
```

## 🛠️ Development & Testing

### **Test Scripts**
```bash
# Deploy contract
forge script script/DeployLPBattleVault-Monad.s.sol --broadcast

# Create battle with cast
./create-battle-cast.sh <TOKEN_ID> <DURATION_SECONDS>

# Join battle
./join-battle-cast.sh <BATTLE_ID> <TOKEN_ID>

# Monitor battle
./monitor-battle-cast.sh <BATTLE_ID>

# Resolve battle
./resolve-battle-cast.sh <BATTLE_ID>

# Get battle details
./get-battle-details-cast.sh <BATTLE_ID>
```

### **Frontend Environment Setup**
```bash
# Install dependencies
npm install ethers

# Environment variables
REACT_APP_CONTRACT_ADDRESS=0x1D570D83E56d6791393F5BA407d8d40629C202d4
REACT_APP_POSITION_MANAGER=0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7
REACT_APP_RPC_URL=https://testnet-rpc.monad.xyz
REACT_APP_CHAIN_ID=10143
```

## ⚠️ Important Notes

### **🔒 Security Considerations**
- Always validate LP token ownership before transactions
- Check battle status before joining/resolving
- Implement proper error handling for all contract calls
- Use `canJoinBattle()` before allowing users to join

### **💰 Economic Model**
- **5% Value Tolerance**: Opponents must have similar LP value
- **Resolution Reward**: 1% of collected fees go to resolver
- **Winner Takes All**: Winner gets both positions' collected fees
- **Draw Scenario**: Each player gets their own position's fees back

### **⚡ Gas Optimization**
- Batch multiple read calls when possible
- Use `getCompleteBattleDetails()` instead of multiple separate calls
- Cache battle information to reduce RPC calls
- Consider using multicall for batch operations

### **🎯 Battle Logic**
- **In Range**: Position's current tick is between tickLower and tickUpper
- **Winner Determination**: 
  1. If only one position in range → Winner
  2. If both in range → Higher fees wins
  3. If both out of range → Draw
- **Time Management**: Battles end after specified duration

## 🔗 Key Addresses (Monad Testnet)

| Component | Address |
|-----------|---------|
| **LPBattleVault** | `0x1D570D83E56d6791393F5BA407d8d40629C202d4` |
| **Position Manager** | `0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7` |
| **Uniswap V3 Factory** | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| **USDC** | `0xf817257fed379853cDe0fa4F97AB987181B1E5Ea` |
| **USDT** | `0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D` |
| **WETH** | `0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37` |
| **WBTC** | `0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d` |

## 📊 Battle States Flow

```
CREATE BATTLE → QUEUED → JOINED → ONGOING → READY_TO_RESOLVE → ENDED
     ↑             ↑         ↑        ↑            ↑              ↑
   User A      User B    Battle    Time Up    Anyone can      Winner
  creates     joins     starts              resolve        determined
```

---

**🎯 Ready to integrate?** Use the functions and examples above to build your LP battle frontend!