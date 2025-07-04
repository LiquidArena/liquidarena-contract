#!/bin/bash

# Quick fix for LP value tolerance issue
# This will temporarily modify the contract tolerance for your cross-pool battle

echo "🔧 TEMPORARY FIX FOR LP VALUE TOLERANCE"
echo "======================================"
echo "Your LP positions:"
echo "  Token 67327 (WBTC/USDC): ~\$1.58 USD" 
echo "  Token 67082 (WETH/USDC): ~\$0.11 USD"
echo "  Difference: 93.09% (way above 5% tolerance)"
echo ""

echo "💡 QUICK SOLUTIONS:"
echo "=================="
echo ""

echo "Option 1: CREATE NEW BATTLE WITH SMALLER TOKEN"
echo "----------------------------------------------"
echo "Instead of joining battle 1, create a new battle with token 67082:"
echo ""
echo "# Create battle with token 67082 (smaller value)"
echo "cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \\"
echo "  \"createBattle(uint256,uint256)\" \\"
echo "  67082 3600 \\"
echo "  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \\"
echo "  --rpc-url https://testnet-rpc.monad.xyz"
echo ""
echo "# Then join with token 67327 using the creator's key"
echo "cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \\"
echo "  \"joinBattle(uint256,uint256)\" \\"
echo "  2 67327 \\"
echo "  --private-key 0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e \\"
echo "  --rpc-url https://testnet-rpc.monad.xyz"
echo ""

echo "Option 2: DEPLOY NEW CONTRACT WITH RELAXED TOLERANCE"
echo "---------------------------------------------------"
echo "Modify LPBattleVault.sol lines 270-271 to allow larger differences:"
echo ""
echo "# Current (5% tolerance):"
echo "uint256 minValue = (creatorValue * 95) / 100;"
echo "uint256 maxValue = (creatorValue * 105) / 100;"
echo ""
echo "# Modified (50% tolerance for testing):"
echo "uint256 minValue = (creatorValue * 50) / 100;"
echo "uint256 maxValue = (creatorValue * 150) / 100;"
echo ""

echo "Option 3: ADD MORE LIQUIDITY TO BALANCE VALUES"
echo "--------------------------------------------"
echo "Add liquidity to make the positions more similar in value:"
echo "- Add more liquidity to token 67082 (WETH/USDC) to increase its value"
echo "- Or reduce liquidity from token 67327 (WBTC/USDC) to decrease its value"
echo ""

echo "🚀 RECOMMENDED: Option 1 (Swap Battle Order)"
echo "==========================================="
echo "This is the quickest solution - just reverse who creates vs joins:"
echo ""
echo "1. Create battle with your smaller token (67082)"
echo "2. Join with your larger token (67327)" 
echo "3. Cross-pool battle works with same tokens!"
echo ""

read -p "Would you like me to create the script for Option 1? (y/n): " choice

if [[ $choice == "y" || $choice == "Y" ]]; then
    echo ""
    echo "Creating scripts for reversed battle order..."
    
    # Create battle script with token 67082
    cat > create-battle-67082.sh << 'EOF'
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
EOF

    # Create join script with token 67327
    cat > join-battle-with-67327.sh << 'EOF'
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
EOF

    chmod +x create-battle-67082.sh
    chmod +x join-battle-with-67327.sh
    
    echo "✅ Scripts created!"
    echo ""
    echo "🚀 RUN THESE IN ORDER:"
    echo "1. ./create-battle-67082.sh"
    echo "2. ./join-battle-with-67327.sh"
    echo ""
    echo "This will create your cross-pool battle with the same tokens,"
    echo "just in reverse order (smaller creates, larger joins)!"
fi