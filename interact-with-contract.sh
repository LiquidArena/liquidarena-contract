#!/bin/bash

# Interact with LPBattleVault contract on Monad Testnet using cast
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

# Contract addresses
CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

echo "🎮 Interacting with LPBattleVault on Monad Testnet"
echo "Contract: $CONTRACT_ADDRESS"
echo "Position Manager: $POSITION_MANAGER"
echo ""

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable is not set"
    echo "Please set it with: export PRIVATE_KEY=0x_your_private_key"
    exit 1
fi

# Get your wallet address
YOUR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Your address: $YOUR_ADDRESS"
echo ""

# Check your ETH balance
echo "📊 Checking your balance..."
BALANCE=$(cast balance $YOUR_ADDRESS --rpc-url $RPC_URL)
echo "ETH Balance: $(cast --to-ether $BALANCE) ETH"
echo ""

# Function to get your LP NFTs
echo "🔍 Step 1: Check your LP NFTs"
echo "You need to find your Uniswap V3 LP NFT token ID first."
echo ""
echo "Commands to find your NFTs:"
echo "1. Check your NFT balance:"
echo "   cast call $POSITION_MANAGER \"balanceOf(address)\" $YOUR_ADDRESS --rpc-url $RPC_URL"
echo ""
echo "2. If you have NFTs, get token IDs (replace 0 with index):"
echo "   cast call $POSITION_MANAGER \"tokenOfOwnerByIndex(address,uint256)\" $YOUR_ADDRESS 0 --rpc-url $RPC_URL"
echo ""

# Check NFT balance
NFT_BALANCE=$(cast call $POSITION_MANAGER "balanceOf(address)" $YOUR_ADDRESS --rpc-url $RPC_URL)
NFT_COUNT=$(cast --to-dec $NFT_BALANCE)
echo "Your LP NFT balance: $NFT_COUNT"

if [ "$NFT_COUNT" -gt 0 ]; then
    echo ""
    echo "🎯 You have $NFT_COUNT LP NFT(s)! Let's get their token IDs:"
    
    for i in $(seq 0 $((NFT_COUNT-1))); do
        TOKEN_ID=$(cast call $POSITION_MANAGER "tokenOfOwnerByIndex(address,uint256)" $YOUR_ADDRESS $i --rpc-url $RPC_URL)
        TOKEN_ID_DEC=$(cast --to-dec $TOKEN_ID)
        echo "  NFT #$i: Token ID $TOKEN_ID_DEC"
        
        # Get position details
        echo "    Getting position details..."
        cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL | head -3
        echo ""
    done
else
    echo ""
    echo "❌ You don't have any LP NFTs!"
    echo "You need to create a Uniswap V3 LP position first."
    echo ""
    echo "Options:"
    echo "1. Use Uniswap V3 interface to create an LP position"
    echo "2. Use a testnet faucet to get test tokens"
    echo "3. Ask someone to send you a test LP NFT"
    exit 1
fi

echo ""
echo "📝 Next steps (manual execution required):"
echo ""
echo "Replace TOKEN_ID_HERE with your actual token ID from above:"
echo ""

# Template commands for user to execute
cat << 'EOF'
# Step 2: Approve your NFT to the contract
export TOKEN_ID=TOKEN_ID_HERE  # Replace with your actual token ID
cast send 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7 \
  "approve(address,uint256)" \
  0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  $TOKEN_ID \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key $PRIVATE_KEY \
  --legacy

# Step 3: Create a battle (duration in seconds, e.g., 3600 = 1 hour)
cast send 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "createBattle(uint256,uint256)" \
  $TOKEN_ID \
  3600 \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key $PRIVATE_KEY \
  --legacy

# Step 4: Check the battle was created
cast call 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "battleIdCounter()" \
  --rpc-url https://testnet-rpc.monad.xyz

# Step 5: Get battle details (replace 0 with actual battle ID)
cast call 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "getBattleDetails(uint256)" \
  0 \
  --rpc-url https://testnet-rpc.monad.xyz
EOF

echo ""
echo "🎯 Interactive mode:"
echo "Would you like to proceed with a specific token ID? (y/n)"