#!/bin/bash

# Join Battle with Token ID 67327 (WBTC/USDC)
# This joins the battle created with token 67082

echo "⚔️ Joining Battle with Token ID 67327 (WBTC/USDC)"
echo "==============================================="

# Contract addresses
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Join parameters
PRIVATE_KEY="0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e"
TOKEN_ID="67327"

# Get latest battle ID
BATTLE_COUNTER=$(cast call $VAULT_CONTRACT "battleIdCounter()" --rpc-url $RPC_URL)
BATTLE_ID=$((BATTLE_COUNTER - 1))

echo "📋 Join Parameters:"
echo "  Battle ID: $BATTLE_ID"
echo "  Token ID: $TOKEN_ID (WBTC/USDC)"

# Get opponent address
OPPONENT_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "🔑 Opponent Address: $OPPONENT_ADDRESS"

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

# Join battle
echo "⚔️ Joining battle..."
JOIN_TX=$(cast send $VAULT_CONTRACT \
    "joinBattle(uint256,uint256)" \
    $BATTLE_ID \
    $TOKEN_ID \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL)

echo "Join Battle Transaction: $JOIN_TX"

if [ $? -eq 0 ]; then
    echo "✅ Cross-pool battle joined successfully!"
    echo ""
    echo "🎯 BATTLE ACTIVE:"
    echo "  Creator: WETH/USDC (~\$0.11 USD)"
    echo "  Opponent: WBTC/USDC (~\$1.58 USD)"
    echo "  Status: Cross-pool battle in progress!"
else
    echo "❌ Battle join failed!"
fi
