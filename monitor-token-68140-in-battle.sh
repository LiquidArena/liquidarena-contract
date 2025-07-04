#!/bin/bash

# Monitor Token ID 68140 (Currently in Battle)
# Contract: 0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6
# Expected Owner: 0x6789e51196Ea26A159C992B70CC80453Ca6E381a

echo "📡 TOKEN 68140 BATTLE MONITOR"
echo "============================="
echo "Monitoring token 68140 (currently staked in battle)..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
VAULT_CONTRACT="0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"
TOKEN_ID="68140"

# Get expected owner address
EXPECTED_OWNER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "🎯 BATTLE MONITORING SETUP:"
echo "=========================="
echo "Contract: $VAULT_CONTRACT"
echo "Token ID: $TOKEN_ID (WETH/USDC)"
echo "Expected Owner: $EXPECTED_OWNER"
echo "Current Status: Token staked in battle"
echo ""

# Function to check current ownership status
check_ownership_status() {
    local token_owner_raw=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error checking token ownership"
        return 1
    fi
    
    local token_owner=$(echo "$token_owner_raw" | sed 's/0x000000000000000000000000/0x/' | tr '[:upper:]' '[:lower:]')
    local expected_clean=$(echo "$EXPECTED_OWNER" | tr '[:upper:]' '[:lower:]')
    local contract_clean=$(echo "$VAULT_CONTRACT" | tr '[:upper:]' '[:lower:]')
    
    if [ "$token_owner" = "$contract_clean" ]; then
        echo "🎮 Status: Token is staked in battle (owned by contract)"
        return 0
    elif [ "$token_owner" = "$expected_clean" ]; then
        echo "📤 Status: Token returned to owner (battle ended)"
        return 1
    else
        echo "❓ Status: Token owned by unknown address: $token_owner"
        return 2
    fi
}

# Function to find which battle contains this token
find_battle_with_token() {
    echo "🔍 Searching for battle containing token $TOKEN_ID..."
    
    # Check battle counter
    local battle_counter=$(cast call $VAULT_CONTRACT "battleIdCounter()" --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error getting battle counter"
        return 1
    fi
    
    local max_battles=$((16#${battle_counter:2}))
    echo "📊 Total battles created: $max_battles"
    
    # Search through recent battles
    for ((i=max_battles-1; i>=0 && i>=max_battles-10; i--)); do
        local battle_details=$(cast call $VAULT_CONTRACT "getBattleDetails(uint256)" $i --rpc-url $RPC_URL 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            # Check if this battle contains our token
            python3 -c "
import sys
try:
    data = '$battle_details'
    chunks = [data[i:i+64] for i in range(2, len(data), 64)]
    
    if len(chunks) >= 4:
        creator = '0x' + chunks[0][24:]
        opponent = '0x' + chunks[1][24:] if chunks[1] != '0' * 64 else 'None'
        creator_token = int(chunks[2], 16) if chunks[2] != '0' * 64 else 0
        opponent_token = int(chunks[3], 16) if chunks[3] != '0' * 64 else 0
        
        if creator_token == $TOKEN_ID or opponent_token == $TOKEN_ID:
            print(f'🎯 FOUND! Battle {$i} contains token $TOKEN_ID')
            print(f'Creator: {creator} (Token: {creator_token})')
            print(f'Opponent: {opponent} (Token: {opponent_token})')
            
            if creator_token == $TOKEN_ID:
                print(f'📍 Your token is the CREATOR in this battle')
            else:
                print(f'📍 Your token is the OPPONENT in this battle')
            
            sys.exit(0)
except Exception as e:
    pass
" && return 0
        fi
    done
    
    echo "❓ Token not found in recent battles"
    return 1
}

# Function to get USD value
get_usd_value() {
    local usd_result=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>&1)
    
    if [[ $usd_result == *"error"* ]]; then
        echo "❌ Error getting USD value: $usd_result"
        return 1
    else
        python3 -c "
data = '$usd_result'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]

if len(chunks) >= 3:
    amount0 = int(chunks[0], 16)
    amount1 = int(chunks[1], 16) 
    usd_value = int(chunks[2], 16)
    
    print('💵 CURRENT USD VALUE:')
    print('====================')
    print(f'Amount0 (WETH): {amount0 / 1e18:.6f}')
    print(f'Amount1 (USDC): {amount1 / 1e18:.6f}')
    print(f'Total USD Value: \${usd_value / 1e18:.6f}')
    print()
else:
    print('❌ Invalid USD value format')
"
        return $?
    fi
}

# Initial setup
echo "🔍 Initial Battle Search"
echo "========================"
find_battle_with_token

echo ""
echo "🚀 Starting continuous monitoring..."
echo "Updates every 30 seconds"
echo ""

# Main monitoring loop
iteration=0
while true; do
    iteration=$((iteration + 1))
    current_time=$(date '+%H:%M:%S')
    
    echo "[$iteration] 📅 $current_time - Token $TOKEN_ID Battle Monitor"
    echo "================================================"
    
    # Check ownership status
    ownership_status=$(check_ownership_status)
    ownership_code=$?
    echo "$ownership_status"
    
    # Get current USD value
    echo ""
    if get_usd_value; then
        echo "✅ USD valuation successful"
    else
        echo "❌ USD valuation failed"
    fi
    
    # If token is returned to owner, find new battle or exit
    if [ $ownership_code -eq 1 ]; then
        echo ""
        echo "🎉 TOKEN RETURNED TO OWNER!"
        echo "=========================="
        echo "Token $TOKEN_ID is now back in your wallet"
        echo "You can create new battles or join existing ones"
        break
    fi
    
    # Search for battle every 10 iterations
    if [ $((iteration % 10)) -eq 0 ]; then
        echo ""
        echo "🔄 Refreshing battle search..."
        find_battle_with_token
    fi
    
    echo ""
    echo "=============================================="
    echo ""
    
    # Wait 30 seconds before next check
    sleep 30
done

echo ""
echo "🏁 Monitoring completed. Token is available for new battles!"