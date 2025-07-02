#!/bin/bash

# Create a new battle instead of joining the broken one
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Your private key
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"

echo "🎮 Create New Battle (Bypass Broken Battle 0)"
echo "Contract: $CONTRACT_ADDRESS"
echo ""

# Get your wallet address
YOUR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Your address: $YOUR_ADDRESS"
echo ""

# Check your NFTs
echo "🔍 Finding your valid LP NFTs..."
NFT_BALANCE=$(cast call $POSITION_MANAGER "balanceOf(address)" $YOUR_ADDRESS --rpc-url $RPC_URL)
NFT_COUNT=$(cast --to-dec $NFT_BALANCE)
echo "Your LP NFT count: $NFT_COUNT"
echo ""

if [ "$NFT_COUNT" -eq 0 ]; then
    echo "❌ You don't have any LP NFTs to create a battle with!"
    echo "You need to create a Uniswap V3 LP position first."
    exit 1
fi

echo "📋 Your LP NFTs:"
VALID_NFTS=()

for i in $(seq 0 $((NFT_COUNT-1))); do
    TOKEN_ID=$(cast call $POSITION_MANAGER "tokenOfOwnerByIndex(address,uint256)" $YOUR_ADDRESS $i --rpc-url $RPC_URL)
    TOKEN_ID_DEC=$(cast --to-dec $TOKEN_ID)
    
    echo "  NFT #$i: Token ID $TOKEN_ID_DEC"
    
    # Check if position has valid data
    POSITION_DATA=$(cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL)
    
    # Parse key fields
    TOKEN0="0x$(echo $POSITION_DATA | cut -c107-146)"
    TOKEN1="0x$(echo $POSITION_DATA | cut -c147-186)"
    LIQUIDITY_HEX="0x$(echo $POSITION_DATA | cut -c323-386)"
    LIQUIDITY_DEC=$(cast --to-dec $LIQUIDITY_HEX)
    
    echo "    Token0: $TOKEN0"
    echo "    Token1: $TOKEN1"
    echo "    Liquidity: $LIQUIDITY_DEC"
    
    # Check if this is a valid position
    if [ "$TOKEN0" != "0x0000000000000000000000000000000000000000" ] && [ "$LIQUIDITY_DEC" != "0" ]; then
        echo "    ✅ Valid position"
        VALID_NFTS+=($TOKEN_ID_DEC)
    else
        echo "    ❌ Invalid position (zero address or no liquidity)"
    fi
    echo ""
done

if [ ${#VALID_NFTS[@]} -eq 0 ]; then
    echo "❌ None of your NFTs have valid positions!"
    echo "You need an LP position with:"
    echo "1. Non-zero token addresses"
    echo "2. Active liquidity > 0"
    exit 1
fi

# Use the first valid NFT
SELECTED_NFT=${VALID_NFTS[0]}
echo "🎯 Using Token ID: $SELECTED_NFT for battle creation"
echo ""

# Create battle commands
echo "📝 Commands to create your battle:"
echo ""

cat << EOF
# Step 1: Approve your NFT to the contract
cast send $POSITION_MANAGER \\
  "approve(address,uint256)" \\
  $CONTRACT_ADDRESS \\
  $SELECTED_NFT \\
  --rpc-url $RPC_URL \\
  --private-key $PRIVATE_KEY \\
  --legacy

# Step 2: Create battle (1 hour = 3600 seconds)
cast send $CONTRACT_ADDRESS \\
  "createBattle(uint256,uint256)" \\
  $SELECTED_NFT \\
  3600 \\
  --rpc-url $RPC_URL \\
  --private-key $PRIVATE_KEY \\
  --legacy

# Step 3: Check the new battle was created
cast call $CONTRACT_ADDRESS \\
  "battleIdCounter()" \\
  --rpc-url $RPC_URL

# Step 4: Get your battle details (replace X with actual battle ID)
cast call $CONTRACT_ADDRESS \\
  "battles(uint256)" \\
  X \\
  --rpc-url $RPC_URL
EOF

echo ""
echo "💡 Benefits of creating your own battle:"
echo "1. ✅ No tolerance check issues"
echo "2. ✅ You control the battle parameters"
echo "3. ✅ Bypasses the corrupted battle 0"
echo "4. ✅ Others can join your battle instead"
echo ""

echo "🚀 Ready to create battle? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🎯 Executing battle creation..."
    
    # Step 1: Approve
    echo "Step 1: Approving NFT..."
    cast send $POSITION_MANAGER \
      "approve(address,uint256)" \
      $CONTRACT_ADDRESS \
      $SELECTED_NFT \
      --rpc-url $RPC_URL \
      --private-key $PRIVATE_KEY \
      --legacy
    
    echo "Approval sent! Waiting 3 seconds..."
    sleep 3
    
    # Step 2: Create battle
    echo "Step 2: Creating battle..."
    cast send $CONTRACT_ADDRESS \
      "createBattle(uint256,uint256)" \
      $SELECTED_NFT \
      3600 \
      --rpc-url $RPC_URL \
      --private-key $PRIVATE_KEY \
      --legacy
    
    echo "Battle creation sent! Waiting 3 seconds..."
    sleep 3
    
    # Step 3: Check result
    echo "Step 3: Checking battle count..."
    NEW_BATTLE_COUNT=$(cast call $CONTRACT_ADDRESS "battleIdCounter()" --rpc-url $RPC_URL)
    NEW_BATTLE_DEC=$(cast --to-dec $NEW_BATTLE_COUNT)
    
    echo "New battle count: $NEW_BATTLE_DEC"
    
    if [ "$NEW_BATTLE_DEC" -gt 1 ]; then
        NEW_BATTLE_ID=$((NEW_BATTLE_DEC-1))
        echo "✅ Battle created successfully! Battle ID: $NEW_BATTLE_ID"
        echo ""
        echo "🎯 Your battle is ready for others to join!"
        echo "Battle ID: $NEW_BATTLE_ID"
        echo "Your Token ID: $SELECTED_NFT"
    else
        echo "❌ Battle creation might have failed. Check transaction status."
    fi
else
    echo "Battle creation cancelled. Run the commands manually when ready."
fi