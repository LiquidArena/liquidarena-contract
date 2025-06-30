# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
- `forge build` - Compile smart contracts
- `forge test` - Run all tests
- `forge test --fork-url https://testnet-rpc.monad.xyz` - Run tests on Monad testnet fork
- `forge test --match-test testCreateBattle` - Run specific test
- `forge fmt` - Format Solidity code
- `forge snapshot` - Generate gas snapshots

### Deployment Commands
- `forge create src/LPBattleVault.sol:LPBattleVault --account monad-deployer --broadcast --constructor-args <positionManager> <factory>` - Deploy to Monad testnet
- `forge script script/LPBattleVault.s.sol --account monad-deployer --broadcast` - Run deployment script
- Verification: `forge verify-contract <address> src/LPBattleVault.sol:LPBattleVault --chain 10143 --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org`

### Keystore Management
- `cast wallet import monad-deployer --private-key <key>` - Import deployment wallet
- `cast wallet address --account monad-deployer` - Get wallet address

## Architecture

This is a Foundry-based DeFi protocol for LP (Liquidity Provider) battles on Uniswap V3 positions, deployed on Monad testnet.

### Core Contracts
- **LPBattleVault.sol** - Price range battle contract where users compete based on whether their LP positions remain in-range
- **LPFeeBattle.sol** - Fee accumulation battle contract where users compete based on fee growth over time

### Battle Mechanics
Both contracts implement similar patterns:
- Users deposit LP NFTs to create/join battles
- 5% value tolerance required for joining battles
- Winner determined by different strategies:
  - **LPBattleVault**: Price range containment at battle end
  - **LPFeeBattle**: Highest fee accumulation during battle period
- Winner receives collected fees from both positions

### Key Interfaces
- `INonfungiblePositionManager` - Uniswap V3 position management
- `IUniswapV3Factory` - Pool factory for price/tick data
- `IUniswapV3Pool` - Pool state (slot0, current tick)
- `IOracle` - Price oracle integration for USD valuations

### Testing Architecture
Tests use comprehensive mock contracts that simulate:
- Position manager with configurable position data
- Factory with pool mappings
- Pool with controllable tick/price state
- Oracle with settable prices

### Network Configuration
- **Target**: Monad Testnet (Chain ID: 10143)
- **RPC**: https://testnet-rpc.monad.xyz  
- **Deployed Addresses**:
  - Position Manager: `0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7`
  - Vault: `0xde196Dd5e1ce9a9872b6d44794eEB3F1B4AF28b4`
  - Factory: `0x961235a9020B05C44DF1026D956D1F4D78014276`

### Dependencies
- OpenZeppelin: ERC721 receiver functionality
- Forge Standard Library: Testing utilities and console logging
- Uniswap V3 Core: Position and pool interfaces