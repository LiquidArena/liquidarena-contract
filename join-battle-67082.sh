#!/bin/bash

# Join Battle ID 1 with Token ID 67082
# Contract: 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0
# Private Key: b0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419

echo "⚔️  Joining Battle ID 1 with Token ID 67082"
echo "==========================================="

# Contract addresses
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Battle parameters
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"
TOKEN_ID="67082"
BATTLE_ID="1"

echo "📋 Join Parameters:"
echo "  Battle ID: $BATTLE_ID"
echo "  Token ID: $TOKEN_ID"
echo "  Contract: $VAULT_CONTRACT"
echo "  Position Manager: $POSITION_MANAGER"
echo ""

# Get opponent address
OPPONENT_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "🔑 Opponent Address: $OPPONENT_ADDRESS"

# Step 1: Check token ownership
echo ""
echo "🔍 Step 1: Verifying Token Ownership"
echo "====================================="
TOKEN_OWNER_RAW=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
TOKEN_OWNER=$(echo "$TOKEN_OWNER_RAW" | sed 's/0x000000000000000000000000/0x/' | tr '[:upper:]' '[:lower:]')
OPPONENT_ADDRESS_CLEAN=$(echo "$OPPONENT_ADDRESS" | tr '[:upper:]' '[:lower:]')

echo "Token Owner (raw): $TOKEN_OWNER_RAW"
echo "Token Owner (clean): $TOKEN_OWNER"
echo "Your Address: $OPPONENT_ADDRESS_CLEAN"

if [ "$TOKEN_OWNER" != "$OPPONENT_ADDRESS_CLEAN" ]; then
    echo "❌ Error: You don't own token $TOKEN_ID"
    echo "   Token owner: $TOKEN_OWNER"
    echo "   Your address: $OPPONENT_ADDRESS_CLEAN"
    exit 1
fi

echo "✅ Token ownership verified!"

# Step 2: Check if can join battle
echo ""
echo "🔍 Step 2: Checking Battle Eligibility"
echo "======================================"
CAN_JOIN_RESULT=$(cast call $VAULT_CONTRACT "canJoinBattle(uint256,uint256)" $BATTLE_ID $TOKEN_ID --rpc-url $RPC_URL)
echo "Can Join Result: $CAN_JOIN_RESULT"

# Step 3: Get token value
echo ""
echo "🔍 Step 3: Getting Token Value"
echo "=============================="
TOKEN_VALUE=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
echo "Token Value (raw): $TOKEN_VALUE"

# Step 4: Get position details
echo ""
echo "🔍 Step 4: Getting Position Details"
echo "==================================="
POSITION_DETAILS=$(cast call $VAULT_CONTRACT "getPositionDetails(uint256)" $TOKEN_ID --rpc-url $RPC_URL)
echo "Position Details: $POSITION_DETAILS"

# Step 5: Get battle details before joining
echo ""
echo "🔍 Step 5: Getting Current Battle Details"
echo "========================================"
BATTLE_DETAILS=$(cast call $VAULT_CONTRACT "getBattleDetails(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle Details: $BATTLE_DETAILS"

BATTLE_STATUS=$(cast call $VAULT_CONTRACT "getBattleStatus(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle Status: $BATTLE_STATUS"

# Step 6: Approve NFT to battle contract
echo ""
echo "🔐 Step 6: Approving NFT to Battle Contract"
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

# Step 7: Join battle
echo ""
echo "⚔️  Step 7: Joining Battle"
echo "========================="
echo "Joining battle with parameters:"
echo "  Battle ID: $BATTLE_ID"
echo "  Token ID: $TOKEN_ID"

JOIN_TX=$(cast send $VAULT_CONTRACT \
    "joinBattle(uint256,uint256)" \
    $BATTLE_ID \
    $TOKEN_ID \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL)

echo "Join Battle Transaction: $JOIN_TX"

if [ $? -eq 0 ]; then
    echo "✅ Battle join transaction sent!"
else
    echo "❌ Battle join failed!"
    echo "Error: $JOIN_TX"
    exit 1
fi

# Wait for battle join confirmation
echo "⏳ Waiting for battle join confirmation..."
sleep 10

# Step 8: Get updated battle details
echo ""
echo "🔍 Step 8: Getting Updated Battle Information"
echo "============================================"

# Get battle details
UPDATED_BATTLE_DETAILS=$(cast call $VAULT_CONTRACT "getBattleDetails(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Updated Battle Details: $UPDATED_BATTLE_DETAILS"

# Get battle status
UPDATED_BATTLE_STATUS=$(cast call $VAULT_CONTRACT "getBattleStatus(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Updated Battle Status: $UPDATED_BATTLE_STATUS"

# Get time remaining
TIME_REMAINING=$(cast call $VAULT_CONTRACT "getTimeRemaining(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Time Remaining: $TIME_REMAINING seconds"

# Get battle USD value
USD_VALUE=$(cast call $VAULT_CONTRACT "getBattleUSDValue(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
echo "Battle USD Value: $USD_VALUE"

echo ""
echo "🎯 BATTLE JOINED SUCCESSFULLY!"
echo "=============================="
echo "Battle ID: $BATTLE_ID"
echo "Opponent: $OPPONENT_ADDRESS"
echo "Token ID: $TOKEN_ID"
echo "Status: $UPDATED_BATTLE_STATUS"
echo "Time Remaining: $TIME_REMAINING seconds"
echo "USD Value: $USD_VALUE"
echo ""

echo "📋 TRANSACTION SUMMARY"
echo "======================"
echo "Approval TX: $APPROVE_TX"
echo "Join TX: $JOIN_TX"
echo ""

echo "🔗 USEFUL COMMANDS"
echo "=================="
echo "Monitor battle: ./monitor-battle-cast.sh $BATTLE_ID"
echo "Check battle details: cast call $VAULT_CONTRACT \"getBattleDetails(uint256)\" $BATTLE_ID --rpc-url $RPC_URL"
echo "Check battle status: cast call $VAULT_CONTRACT \"getBattleStatus(uint256)\" $BATTLE_ID --rpc-url $RPC_URL"
echo "Get current performance: cast call $VAULT_CONTRACT \"getCurrentPerformance(uint256)\" $BATTLE_ID --rpc-url $RPC_URL"
echo ""

echo "⚔️  BATTLE IS NOW ACTIVE!"
echo "======================="
echo "1. The battle has started and is now 'onGoing'"
echo "2. Monitor the battle progress in real-time"
echo "3. Battle will be ready to resolve after the duration expires"
echo ""
echo "🏆 May the best LP position win!"