# LiquidArena Protocol

A PvP DeFi prediction protocol where users duel with Uniswap V3 LP NFTs in battles resolved by price range validity or fee performance, with winners claiming all fees while LP NFTs are returned to both players.

## 🚀 Deployed Contracts (Monad Testnet)

- **LPBattleVault (Range Battles)**: `0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6`
- **LPFeeBattle (Fee Battles)**: `0x18d6b03A4A0499077A2dc8c45fFf8DA10aF16f64`

## 📋 Overview

LiquidArena Protocol enables two types of PvP battles using Uniswap V3 LP NFTs:

### 🎯 Range Battles (LPBattleVault)
- Players compete based on price range validity
- Winner determined by whose LP position stays "in range" longer
- Battle duration: 5 minutes to 7 days
- Uses Chainlink price feeds for accurate valuation

### 💰 Fee Battles (LPFeeBattle)  
- Players compete based on fee accumulation rates
- Winner determined by highest fee generation relative to liquidity
- Minimum battle duration: 1 hour
- Real-time fee performance tracking

## 🔧 Key Features

- **PvP LP NFT Battles**: Stake Uniswap V3 LP NFTs in competitive battles
- **Dual Battle Types**: Range-based and fee-based competition modes
- **Fair Matching**: LP values must be within 5% tolerance to join battles
- **Resolver Rewards**: Anyone can resolve battles and earn 1% reward
- **Emergency Safety**: Pausable contracts with emergency withdrawal
- **Real-time Tracking**: Live battle status and performance monitoring

## 📚 Documentation

### For Frontend Developers
- **[Frontend Integration Guide](./FRONTEND_DOCS.md)** - Comprehensive integration documentation
- **[Quick Start Guide](./QUICK_START.md)** - Get started in minutes
- **[Contract ABIs](./CONTRACT_ABIS.ts)** - Ready-to-use TypeScript ABIs

### For Smart Contract Developers
- **[Contract Source Code](./src/)** - Full Solidity implementation
- **[Test Suite](./test/)** - Comprehensive test coverage
- **[Deployment Scripts](./script/)** - Deployment and setup scripts

## 🎮 How It Works

### Battle Lifecycle

1. **Create**: Player deposits LP NFT and sets battle duration
2. **Queue**: Battle waits for opponent with similar-value LP NFT
3. **Join**: Opponent deposits LP NFT, battle begins
4. **Ongoing**: Battle runs for specified duration
5. **Resolve**: Anyone can resolve and earn 1% reward
6. **Complete**: Winner gets all fees, both get LP NFTs back

### Range Battle Rules
- Winner: LP position that stays in range longer
- Tie: Both positions equally in/out of range
- Resolution: Based on current tick vs position ranges

### Fee Battle Rules  
- Winner: Higher fee accumulation rate (fees/hour)
- Tracking: Real-time fee growth monitoring
- Resolution: Based on total fee performance

## 🛠️ Quick Integration

```typescript
import { useWriteContract, useReadContract } from 'wagmi';
import { RANGE_BATTLE_ADDRESS, RANGE_BATTLE_ABI } from './CONTRACT_ABIS';

// Create a battle
const { writeContract } = useWriteContract();
writeContract({
  address: RANGE_BATTLE_ADDRESS,
  abi: RANGE_BATTLE_ABI,
  functionName: 'createBattle',
  args: [tokenId, duration],
});

// Get battle details
const { data: battle } = useReadContract({
  address: RANGE_BATTLE_ADDRESS,
  abi: RANGE_BATTLE_ABI,
  functionName: 'getBattleDetails',
  args: [battleId],
});
```

## 🔒 Security Features

- **Reentrancy Protection**: All state-changing functions protected
- **Access Control**: Owner-only administrative functions
- **Price Feed Validation**: Staleness checks on Chainlink feeds
- **Emergency Mechanisms**: Pausable with emergency withdrawals
- **Battle Validation**: Comprehensive input and state validation

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Install dependencies
forge install

# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract LiquidArenaTests
```

## 🚀 Deployment

Deploy to Monad Testnet:

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export RPC_URL=https://testnet-monad-rpc.com

# Deploy Range Battle contract
forge script script/DeployLPBattleVault.s.sol --rpc-url $RPC_URL --broadcast

# Deploy Fee Battle contract  
forge script script/DeployLPFeeBattle.s.sol --rpc-url $RPC_URL --broadcast
```

## 📊 Contract Architecture

```
LiquidArena Protocol
├── LPBattleVault.sol      # Range-based battles
├── LPFeeBattle.sol        # Fee-based battles
├── interfaces/
│   └── IShared.sol        # Shared interfaces & errors
└── libraries/
    ├── PoolUtils.sol      # Uniswap V3 utilities
    ├── StringUtils.sol    # String formatting
    └── TransferUtils.sol  # Token transfer utilities
```

## 🔗 Dependencies

- **OpenZeppelin**: Security and utility contracts
- **Uniswap V3**: LP NFT position management
- **Chainlink**: Price feed oracles
- **Foundry**: Development and testing framework

## 📈 Battle Statistics

Track battle performance with built-in analytics:

- Total battles created
- Battle resolution rates  
- Average battle duration
- Fee performance metrics
- Winner distribution

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Documentation**: [Frontend Docs](./FRONTEND_DOCS.md)
- **Quick Start**: [Quick Start Guide](./QUICK_START.md)
- **Contract ABIs**: [TypeScript ABIs](./CONTRACT_ABIS.ts)
- **Discord**: [Join our community (Soon)](#)
- **Twitter**: [@LiquidArena](https://x.com/liqarenadotfun)

Built with ❤️ by the Femboy Fam Team
