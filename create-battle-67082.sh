#!/bin/bash

# Create Battle with Token ID 67082 (WETH/USDC)
# This reverses the battle order to work around tolerance issues

echo "🚀 Creating Battle with Token ID 67082 (WETH/USDC)"
echo "================================================="

# Contract addresses
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Battle parameters
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"
TOKEN_ID="67082"
DURATION="3600"

echo "📋 Battle Parameters:"
echo "  Token ID: $TOKEN_ID (WETH/USDC)"
echo "  Duration: $DURATION seconds (1 hour)"
echo "  Creator will be the smaller value position"

# Get creator address
CREATOR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "🔑 Creator Address: $CREATOR_ADDRESS"

# Approve NFT
echo "🔐 Approving NFT..."
cast send $POSITION_MANAGER \
    "approve(address,uint256)" \
    $VAULT_CONTRACT \
    $TOKEN_ID \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL

echo "⏳ Waiting for approval..."
sleep 5

# Create battle
echo "🚀 Creating battle..."
CREATE_TX=$(cast send $VAULT_CONTRACT \
    "createBattle(uint256,uint256)" \
    $TOKEN_ID \
    $DURATION \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL)

echo "Create Battle Transaction: $CREATE_TX"

if [ $? -eq 0 ]; then
    echo "✅ Battle created successfully!"
    echo ""
    echo "🎯 NEXT STEP:"
    echo "Run: ./join-battle-with-67327.sh"
else
    echo "❌ Battle creation failed!"
fi
