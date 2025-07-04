# 🎮 LP Battle Vault - Simple User Workflow

## 🎯 What is LP Battle Vault?

**LP Battle Vault** lets you compete with your Uniswap V3 LP positions! Two players stake their LP NFTs, and after a time period, the winner is determined based on performance and takes all the rewards.

---

## 🔄 Simple Workflow

### **👤 Step 1: Create Battle (Player A)**

```
Player A has: WETH/USDC LP NFT worth $100
```

1. **Approve** your LP NFT to the battle contract
2. **Create Battle** with your NFT + set duration (e.g., 1 hour)
3. **Wait** for an opponent to join

```
✅ Battle Created!
Status: "Waiting for opponent"
```

---

### **⚔️ Step 2: Join Battle (Player B)**

```
Player B has: WBTC/USDC LP NFT worth $95-105
(Must be within 5% of Player A's value)
```

1. **Find** an open battle you want to join
2. **Check** if your LP value is close enough (±5%)
3. **Approve** your LP NFT to the battle contract  
4. **Join Battle** with your NFT

```
🎮 Battle Started!
Status: "Battle in progress"
Timer: 1 hour countdown begins
```

---

### **⏰ Step 3: Battle Period (Automatic)**

During the battle, the system tracks:

```
📊 Real-time Performance:
- Is your LP position "in range"? (earning fees)
- How much fees did you collect?
- Who's currently winning?
```

**Winner Logic:**
- 🎯 **Only you in range** → You win
- ⚔️ **Both in range** → Most fees wins  
- 🎲 **Both out of range** → Random winner
- 💤 **Neither in range** → Draw (rare)

---

### **🏆 Step 4: Resolve Battle (Anyone)**

After time expires, anyone can resolve:

```
⏱️ Time's up! Battle ready to resolve
```

1. **Anyone calls** `resolveBattle()`
2. **System determines** winner based on performance
3. **Rewards distributed:**
   - 🏆 **Winner**: Gets ALL collected fees from both positions
   - 🔧 **Resolver**: Gets 1% of total fees as reward
   - 📤 **NFTs returned** to original owners

```
🎉 Battle Complete!
Winner: Player B (WBTC/USDC)
Reason: "Both in range, Player B had more fees"
```

---

## 🎮 Example Battle Flow

### **Real Example:**

```
1. CREATE BATTLE
   Player A: "I'll battle my WETH/USDC LP worth $1.58"
   ⏳ Waiting for opponent...

2. JOIN BATTLE  
   Player B: "I'll join with my WBTC/USDC LP worth $0.39"
   ❌ Error: "Values too different (93% ≠ 5%)"
   
3. FIND BETTER MATCH
   Player C: "I'll join with my USDC/USDT LP worth $1.61" 
   ✅ Success: "Within 5% tolerance!"
   
4. BATTLE STARTS
   ⏰ 1 hour timer begins
   📊 Both positions start earning fees
   
5. DURING BATTLE
   - WETH price moves → Player A goes out of range
   - USDC/USDT stable → Player C stays in range
   - Player C accumulates more fees
   
6. RESOLVE
   🏆 Player C wins! 
   💰 Gets all fees from both positions
   📤 Both players get their NFTs back
```

---

## 🛡️ Safety Features

### **Price Protection**
- ✅ Uses **Chainlink price feeds** for accurate valuations
- ⏰ Rejects **stale price data** (older than 1 hour)
- 🎯 Only allows **fair battles** (±5% value difference)

### **Cross-Pool Battles**
- 🔄 Different pools can battle each other
- 📊 Examples: WETH/USDC vs WBTC/USDC vs USDC/USDT
- ⚖️ Fair comparison using USD values

### **Ownership Security**  
- 🔒 Must own the LP NFT to battle
- 🔄 NFTs held safely during battle
- 📤 Automatically returned after resolution

---

## 🎯 Key Benefits

### **For LP Providers:**
- 🎮 **Gamify** your LP positions
- 💰 **Earn extra rewards** from winning battles
- 🏆 **Compete** with different strategies
- 📊 **Cross-pool** flexibility

### **For DeFi Ecosystem:**
- 🔥 **Increased engagement** with LP positions
- 💧 **More liquidity** staying in pools longer
- 🎲 **New DeFi primitive** for competition
- ⚡ **Gas-efficient** reward distribution

---

## 📋 Supported Tokens (Monad Testnet)

| Token | Price Feed | Status |
|-------|------------|---------|
| **USDC** | ✅ USD/USD | Stablecoin |
| **USDT** | ✅ USD/USD | Stablecoin |
| **WETH** | ✅ ETH/USD | Supported |
| **WBTC** | ✅ BTC/USD | Supported |

**Supported Pairs:** All combinations of above tokens

---

## 🚀 Quick Start Commands

### **Create Battle:**
```bash
cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \
  "createBattle(uint256,uint256)" \
  [YOUR_TOKEN_ID] 3600 \
  --private-key [YOUR_KEY] \
  --rpc-url https://testnet-rpc.monad.xyz
```

### **Join Battle:**
```bash
cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \
  "joinBattle(uint256,uint256)" \
  [BATTLE_ID] [YOUR_TOKEN_ID] \
  --private-key [YOUR_KEY] \
  --rpc-url https://testnet-rpc.monad.xyz
```

### **Resolve Battle:**
```bash
cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \
  "resolveBattle(uint256)" \
  [BATTLE_ID] \
  --private-key [ANY_KEY] \
  --rpc-url https://testnet-rpc.monad.xyz
```

---

## 🎊 Ready to Battle?

1. 🏗️ Get some LP positions on Uniswap V3
2. 🎮 Create or join a battle
3. 📊 Monitor your performance
4. 🏆 Win rewards and glory!

**May the best LP position win!** ⚔️