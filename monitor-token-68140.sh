#!/bin/bash

# Monitor Token ID 68140 Price and Position Details
# Contract: 0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6
# Private Key: b0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419

echo "📡 TOKEN 68140 PRICE MONITOR"
echo "==========================="
echo "Monitoring token 68140 price and position details..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
VAULT_CONTRACT="0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"
TOKEN_ID="68140"

# Get owner address
OWNER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)

echo "🎯 MONITORING SETUP:"
echo "==================="
echo "Contract: $VAULT_CONTRACT"
echo "Token ID: $TOKEN_ID"
echo "Owner: $OWNER_ADDRESS"
echo "Position Manager: $POSITION_MANAGER"
echo ""

# Function to check token ownership
check_ownership() {
    echo "🔍 Verifying Token Ownership..."
    local token_owner_raw=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error checking token ownership"
        return 1
    fi
    
    local token_owner=$(echo "$token_owner_raw" | sed 's/0x000000000000000000000000/0x/' | tr '[:upper:]' '[:lower:]')
    local owner_clean=$(echo "$OWNER_ADDRESS" | tr '[:upper:]' '[:lower:]')
    
    echo "Token Owner (raw): $token_owner_raw"
    echo "Token Owner (clean): $token_owner"
    echo "Your Address: $owner_clean"
    
    if [ "$token_owner" = "$owner_clean" ]; then
        echo "✅ Token ownership verified!"
        return 0
    else
        echo "❌ Token not owned by provided private key"
        echo "   Token owner: $token_owner"
        echo "   Your address: $owner_clean"
        return 1
    fi
}

# Function to get position details from Position Manager
get_position_details() {
    echo ""
    echo "🔍 Getting Position Details from Uniswap..."
    
    local position_data=$(cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error fetching position data"
        return 1
    fi
    
    # Decode position data
    python3 -c "
data = '$position_data'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]

if len(chunks) >= 12:
    nonce = int(chunks[0], 16)
    operator = '0x' + chunks[1][24:]
    token0 = '0x' + chunks[2][24:]
    token1 = '0x' + chunks[3][24:]
    fee = int(chunks[4], 16)
    tick_lower = int(chunks[5], 16)
    tick_upper = int(chunks[6], 16)
    liquidity = int(chunks[7], 16)
    fee_growth_inside0 = int(chunks[8], 16)
    fee_growth_inside1 = int(chunks[9], 16)
    tokens_owed0 = int(chunks[10], 16)
    tokens_owed1 = int(chunks[11], 16)
    
    # Convert signed ticks
    if tick_lower > 2**255:
        tick_lower = tick_lower - 2**256
    if tick_upper > 2**255:
        tick_upper = tick_upper - 2**256
    
    print('📊 POSITION DETAILS:')
    print('===================')
    print(f'Token0: {token0}')
    print(f'Token1: {token1}')
    print(f'Fee Tier: {fee} ({fee/10000}%)')
    print(f'Tick Range: {tick_lower:,} to {tick_upper:,}')
    print(f'Liquidity: {liquidity:,}')
    print(f'Tokens Owed0: {tokens_owed0}')
    print(f'Tokens Owed1: {tokens_owed1}')
    print()
    
    # Identify tokens
    token_names = {
        '0xb5a30b0fdc5ea94a52fdc42e3e9760cb8449fb37': 'WETH',
        '0xcf5a6076cfa32686c0df13abada2b40dec133f1d': 'WBTC', 
        '0xf817257fed379853cde0fa4f97ab987181b1e5ea': 'USDC',
        '0x88b8e2161dedc77ef4ab7585569d2415a1c1055d': 'USDT'
    }
    
    token0_name = token_names.get(token0.lower(), 'UNKNOWN')
    token1_name = token_names.get(token1.lower(), 'UNKNOWN')
    
    print(f'🎯 PAIR: {token0_name}/{token1_name}')
    print(f'💰 Fee Tier: {fee/10000}%')
    print()
else:
    print('❌ Invalid position data format')
"
}

# Function to get USD value from contract
get_usd_value() {
    local usd_result=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>&1)
    
    if [[ $usd_result == *"StalePrice"* ]] || [[ $usd_result == *"0x19abf40e"* ]]; then
        echo "❌ StalePrice error - Chainlink price feeds are stale"
        return 1
    elif [[ $usd_result == *"PriceFeedNotSet"* ]] || [[ $usd_result == *"0x085d8450"* ]]; then
        echo "❌ PriceFeedNotSet error - No price feed configured for token"
        return 1
    elif [[ $usd_result == *"error"* ]]; then
        echo "❌ Error getting USD value: $usd_result"
        return 1
    else
        # Decode USD value
        python3 -c "
data = '$usd_result'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]

if len(chunks) >= 3:
    amount0 = int(chunks[0], 16)
    amount1 = int(chunks[1], 16) 
    usd_value = int(chunks[2], 16)
    
    print('💵 USD VALUATION:')
    print('=================')
    print(f'Amount0: {amount0 / 1e18:.6f}')
    print(f'Amount1: {amount1 / 1e18:.6f}')
    print(f'Total USD Value: \${usd_value / 1e18:.6f}')
    print()
else:
    print('❌ Invalid USD value format')
"
        return $?
    fi
}

# Function to compare with token 67083
compare_values() {
    local token_68140_value=$1
    local token_67083_value=10.960883  # Known value from previous check
    
    python3 -c "
token_68140 = $token_68140_value
token_67083 = $token_67083_value

diff = abs(token_68140 - token_67083)
max_val = max(token_68140, token_67083)
percentage = (diff / max_val) * 100

print('🔄 BATTLE COMPATIBILITY CHECK:')
print('==============================')
print(f'Token 68140 Value: \${token_68140:.6f}')
print(f'Token 67083 Value: \${token_67083:.6f}')
print(f'Difference: \${diff:.6f} ({percentage:.2f}%)')
print(f'Within 5% tolerance: {percentage <= 5}')
print()

if percentage <= 5:
    print('✅ THESE TOKENS CAN BATTLE EACH OTHER!')
    print('🎮 Ready for cross-pool battle setup')
else:
    print('❌ Values too different for battle (need ≤5%)')
    print(f'💡 Need opponent with value between \${token_68140*0.95:.2f}-\${token_68140*1.05:.2f}')
print()
"
}

# Initial setup check
echo "🔍 Initial Setup Check"
echo "======================"
if ! check_ownership; then
    echo "❌ Ownership verification failed. Exiting."
    exit 1
fi

# Get initial position details
get_position_details

echo ""
echo "🚀 Starting continuous monitoring..."
echo "Updates every 30 seconds"
echo ""

# Main monitoring loop
iteration=0
while true; do
    iteration=$((iteration + 1))
    current_time=$(date '+%H:%M:%S')
    
    echo "[$iteration] 📅 $current_time - Token $TOKEN_ID"
    echo "================================"
    
    # Check USD value
    if get_usd_value; then
        echo "✅ USD valuation successful"
        
        # Every 5 iterations, compare with token 67083
        if [ $((iteration % 5)) -eq 0 ]; then
            # Extract USD value for comparison
            usd_val=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
            if [ $? -eq 0 ]; then
                usd_decimal=$(python3 -c "
data = '$usd_val'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]
if len(chunks) >= 3:
    usd_value = int(chunks[2], 16)
    print(usd_value / 1e18)
")
                compare_values $usd_decimal
            fi
        fi
    else
        echo "❌ USD valuation failed - likely price feed issue"
    fi
    
    echo ""
    echo "========================================"
    echo ""
    
    # Wait 30 seconds before next check
    sleep 30
done