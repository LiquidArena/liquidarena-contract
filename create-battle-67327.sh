#!/bin/bash

# Create Battle with Token ID 67327
# Contract: 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0
# Private Key: dc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e

echo "🚀 Creating Battle with Token ID 67327"
echo "======================================"

# Contract addresses
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Battle parameters
PRIVATE_KEY="0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e"
TOKEN_ID="67327"
DURATION="300"  # 1 hour = 3600 seconds

echo "📋 Battle Parameters:"
echo "  Token ID: $TOKEN_ID"
echo "  Duration: $DURATION seconds (1 hour)"
echo "  Contract: $VAULT_CONTRACT"
echo "  Position Manager: $POSITION_MANAGER"
echo ""

# Get creator address
CREATOR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "🔑 Creator Address: $CREATOR_ADDRESS"

# Step 1: Check token ownership
echo ""
echo "🔍 Step 1: Verifying Token Ownership"
echo "===================================="
TOKEN_OWNER_RAW=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
TOKEN_OWNER=$(echo "$TOKEN_OWNER_RAW" | sed 's/0x000000000000000000000000/0x/' | tr '[:upper:]' '[:lower:]')
CREATOR_ADDRESS_CLEAN=$(echo "$CREATOR_ADDRESS" | tr '[:upper:]' '[:lower:]')

echo "Token Owner (raw): $TOKEN_OWNER_RAW"
echo "Token Owner (clean): $TOKEN_OWNER"
echo "Your Address: $CREATOR_ADDRESS_CLEAN"

if [ "$TOKEN_OWNER" != "$CREATOR_ADDRESS_CLEAN" ]; then
    echo "❌ Error: You don't own token $TOKEN_ID"
    echo "   Token owner: $TOKEN_OWNER"
    echo "   Your address: $CREATOR_ADDRESS_CLEAN"
    exit 1
fi

echo "✅ Token ownership verified!"

# Step 2: Check token value
echo ""
echo "🔍 Step 2: Getting Token Value"
echo "=============================="
TOKEN_VALUE=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
echo "Token Value (raw): $TOKEN_VALUE"

# Step 3: Get position details
echo ""
echo "🔍 Step 3: Getting Position Details"
echo "==================================="
POSITION_DETAILS=$(cast call $VAULT_CONTRACT "getPositionDetails(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
echo "Position Details: $POSITION_DETAILS"

# Step 4: Approve NFT to battle contract
echo ""
echo "🔐 Step 4: Approving NFT to Battle Contract"
echo "==========================================="
echo "Approving token $TOKEN_ID to battle contract..."

APPROVE_TX=$(cast send $POSITION_MANAGER \
    "approve(address,uint256)" \
    $VAULT_CONTRACT \
    $TOKEN_ID \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL)

echo "Approval Transaction: $APPROVE_TX"

if [ $? -eq 0 ]; then
    echo "✅ NFT approved successfully!"
else
    echo "❌ NFT approval failed!"
    exit 1
fi

# Wait for approval confirmation
echo "⏳ Waiting for approval confirmation..."
sleep 5

# Step 5: Create battle
echo ""
echo "🚀 Step 5: Creating Battle"
echo "=========================="
echo "Creating battle with parameters:"
echo "  Token ID: $TOKEN_ID"
echo "  Duration: $DURATION seconds"

CREATE_TX=$(cast send $VAULT_CONTRACT \
    "createBattle(uint256,uint256)" \
    $TOKEN_ID \
    $DURATION \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL)

echo "Create Battle Transaction: $CREATE_TX"

if [ $? -eq 0 ]; then
    echo "✅ Battle creation transaction sent!"
else
    echo "❌ Battle creation failed!"
    echo "Error: $CREATE_TX"
    exit 1
fi

# Wait for battle creation confirmation
echo "⏳ Waiting for battle creation confirmation..."
sleep 10

# Step 6: Get battle ID and details
echo ""
echo "🔍 Step 6: Getting Battle Information"
echo "===================================="

# Get latest battle ID
BATTLE_COUNTER=$(cast call $VAULT_CONTRACT "battleIdCounter()" --rpc-url $RPC_URL)
BATTLE_ID=$((BATTLE_COUNTER - 1))
echo "Latest Battle ID: $BATTLE_ID"

# Get battle details
BATTLE_DETAILS=$(cast call $VAULT_CONTRACT "getBattleDetails(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle Details: $BATTLE_DETAILS"

# Get battle status
BATTLE_STATUS=$(cast call $VAULT_CONTRACT "getBattleStatus(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle Status: $BATTLE_STATUS"

# Get battle USD value
USD_VALUE=$(cast call $VAULT_CONTRACT "getBattleUSDValue(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle USD Value: $USD_VALUE"

echo ""
echo "🎯 BATTLE CREATED SUCCESSFULLY!"
echo "==============================="
echo "Battle ID: $BATTLE_ID"
echo "Creator: $CREATOR_ADDRESS"
echo "Token ID: $TOKEN_ID"
echo "Duration: $DURATION seconds (1 hour)"
echo "Status: $BATTLE_STATUS"
echo "USD Value: $USD_VALUE"
echo ""

echo "📋 TRANSACTION SUMMARY"
echo "======================"
echo "Approval TX: $APPROVE_TX"
echo "Create TX: $CREATE_TX"
echo ""

echo "🔗 USEFUL COMMANDS"
echo "=================="
echo "Monitor battle: ./3-monitor-battle-demo.sh $BATTLE_ID"
echo "Check battle details: cast call $VAULT_CONTRACT \"getBattleDetails(uint256)\" $BATTLE_ID --rpc-url $RPC_URL"
echo "Check battle status: cast call $VAULT_CONTRACT \"getBattleStatus(uint256)\" $BATTLE_ID --rpc-url $RPC_URL"
echo ""

echo "⚔️  NEXT STEPS"
echo "============="
echo "1. Wait for an opponent to join the battle"
echo "2. Monitor the battle progress"
echo "3. Resolve the battle after $DURATION seconds"
echo ""
echo "Share this battle ID with opponents: $BATTLE_ID"