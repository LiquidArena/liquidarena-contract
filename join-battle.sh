#!/bin/bash

# Join existing battle with different EOA address
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

# Contract addresses
CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Set the private key for joining
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"

echo "🎮 Joining Battle with New EOA Address"
echo "Contract: $CONTRACT_ADDRESS"
echo "Position Manager: $POSITION_MANAGER"
echo ""

# Get your wallet address
YOUR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Your joining address: $YOUR_ADDRESS"
echo ""

# Check your ETH balance
echo "📊 Checking your balance..."
BALANCE=$(cast balance $YOUR_ADDRESS --rpc-url $RPC_URL)
echo "ETH Balance: $(cast --to-ether $BALANCE) ETH"
echo ""

# Check available battles first
echo "🔍 Checking available battles..."
BATTLE_COUNT=$(cast call $CONTRACT_ADDRESS "battleIdCounter()" --rpc-url $RPC_URL)
BATTLE_COUNT_DEC=$(cast --to-dec $BATTLE_COUNT)
echo "Total battles created: $BATTLE_COUNT_DEC"
echo ""

if [ "$BATTLE_COUNT_DEC" -eq 0 ]; then
    echo "❌ No battles available to join!"
    echo "Create a battle first using the other script."
    exit 1
fi

# Show available battles
echo "📋 Available battles:"
for i in $(seq 0 $((BATTLE_COUNT_DEC-1))); do
    echo "Checking Battle ID: $i"
    BATTLE_DETAILS=$(cast call $CONTRACT_ADDRESS "getBattleDetails(uint256)" $i --rpc-url $RPC_URL)
    echo "Battle $i details: $BATTLE_DETAILS"
    echo ""
done

# Check your LP NFTs
echo "🔍 Step 1: Check your LP NFTs"
NFT_BALANCE=$(cast call $POSITION_MANAGER "balanceOf(address)" $YOUR_ADDRESS --rpc-url $RPC_URL)
NFT_COUNT=$(cast --to-dec $NFT_BALANCE)
echo "Your LP NFT balance: $NFT_COUNT"

if [ "$NFT_COUNT" -gt 0 ]; then
    echo ""
    echo "🎯 You have $NFT_COUNT LP NFT(s)! Token IDs:"
    
    for i in $(seq 0 $((NFT_COUNT-1))); do
        TOKEN_ID=$(cast call $POSITION_MANAGER "tokenOfOwnerByIndex(address,uint256)" $YOUR_ADDRESS $i --rpc-url $RPC_URL)
        TOKEN_ID_DEC=$(cast --to-dec $TOKEN_ID)
        echo "  NFT #$i: Token ID $TOKEN_ID_DEC"
    done
else
    echo ""
    echo "❌ You don't have any LP NFTs!"
    echo "You need to create a Uniswap V3 LP position first or get one transferred to you."
    exit 1
fi

echo ""
echo "📝 Commands to join a battle:"
echo ""
echo "Replace BATTLE_ID and TOKEN_ID with actual values:"
echo ""

cat << 'EOF'
# Step 1: Approve your NFT to the contract
export TOKEN_ID=YOUR_TOKEN_ID_HERE  # Replace with your actual token ID
export BATTLE_ID=0  # Replace with the battle ID you want to join

cast send 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7 \
  "approve(address,uint256)" \
  0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  $TOKEN_ID \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \
  --legacy

# Step 2: Join the battle
cast send 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "joinBattle(uint256,uint256)" \
  $BATTLE_ID \
  $TOKEN_ID \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \
  --legacy

# Step 3: Check the battle after joining
cast call 0xca6118BD65778C454B67B11DE39B9BB881915b40 \
  "getBattleDetails(uint256)" \
  $BATTLE_ID \
  --rpc-url https://testnet-rpc.monad.xyz
EOF

echo ""
echo "🎯 Quick execution (if you know your values):"
echo "Would you like to proceed with specific BATTLE_ID and TOKEN_ID? (y/n)"