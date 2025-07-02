#!/bin/bash

# Check battle values and LP NFT values for joining
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

# Contract addresses
CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Your private key
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"

echo "💰 Checking Battle Values and LP NFT Values"
echo "Contract: $CONTRACT_ADDRESS"
echo ""

# Get your wallet address
YOUR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Your address: $YOUR_ADDRESS"
echo ""

# Check battle 0 details
echo "🎯 Battle ID 0 Details:"
BATTLE_DETAILS=$(cast call $CONTRACT_ADDRESS "getBattleDetails(uint256)" 0 --rpc-url $RPC_URL)
echo "Raw battle details: $BATTLE_DETAILS"
echo ""

# Parse battle details (this returns multiple values)
echo "📊 Getting battle creator's LP value..."
CREATOR_LP_VALUE=$(cast call $CONTRACT_ADDRESS "getLPValue(uint256)" 0 --rpc-url $RPC_URL 2>/dev/null || echo "Function not available")
echo "Creator LP Value: $CREATOR_LP_VALUE"
echo ""

# Get your LP NFTs and their values
echo "🔍 Your LP NFTs and their values:"
NFT_BALANCE=$(cast call $POSITION_MANAGER "balanceOf(address)" $YOUR_ADDRESS --rpc-url $RPC_URL)
NFT_COUNT=$(cast --to-dec $NFT_BALANCE)
echo "Your LP NFT count: $NFT_COUNT"
echo ""

if [ "$NFT_COUNT" -gt 0 ]; then
    for i in $(seq 0 $((NFT_COUNT-1))); do
        TOKEN_ID=$(cast call $POSITION_MANAGER "tokenOfOwnerByIndex(address,uint256)" $YOUR_ADDRESS $i --rpc-url $RPC_URL)
        TOKEN_ID_DEC=$(cast --to-dec $TOKEN_ID)
        echo "📍 NFT #$i: Token ID $TOKEN_ID_DEC"
        
        # Get position details from Uniswap
        echo "  Getting position data..."
        POSITION_DATA=$(cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL)
        echo "  Position data: $POSITION_DATA"
        
        # Try to get LP value from our contract helper functions
        echo "  Checking if you can join battle 0 with this NFT..."
        CAN_JOIN=$(cast call $CONTRACT_ADDRESS "canJoinBattle(uint256,uint256)" 0 $TOKEN_ID_DEC --rpc-url $RPC_URL 2>/dev/null || echo "0x0")
        if [ "$CAN_JOIN" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
            echo "  ✅ This NFT CAN join battle 0"
        else
            echo "  ❌ This NFT CANNOT join battle 0 (value not within 5% tolerance)"
        fi
        echo ""
    done
else
    echo "❌ You don't have any LP NFTs!"
    exit 1
fi

echo "🧮 Value Calculation Details:"
echo ""

# Get battle creator's token ID to compare
echo "Getting battle 0 creator's token ID..."
BATTLE_CREATOR_TOKEN=$(cast call $CONTRACT_ADDRESS "battles(uint256)" 0 --rpc-url $RPC_URL)
echo "Battle creator data: $BATTLE_CREATOR_TOKEN"
echo ""

echo "📋 Summary:"
echo "- Battle 0 exists and has specific LP value requirements"
echo "- Your LP NFTs must be within 5% value tolerance of the creator's LP"
echo "- Use the canJoinBattle() function result above to see which NFTs qualify"
echo ""

echo "💡 Solutions if no NFTs can join:"
echo "1. Create a new battle with your current LP NFT"
echo "2. Modify your LP position to match the required value range"
echo "3. Get a different LP NFT that matches the value requirements"
echo ""

echo "🚀 If you have a qualifying NFT, use these commands:"
echo ""

cat << 'EOF'
# Replace TOKEN_ID with a qualifying token ID from above
export TOKEN_ID=QUALIFYING_TOKEN_ID_HERE

# Approve and join
cast send 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7 \
  "approve(address,uint256)" \
  0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  $TOKEN_ID \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \
  --legacy

cast send 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "joinBattle(uint256,uint256)" \
  0 \
  $TOKEN_ID \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \
  --legacy
EOF