#!/bin/bash

# Monitor Token ID 67083 Price and Position Details
# Contract: 0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6
# Private Key: dc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e

echo "📡 TOKEN 67083 PRICE MONITOR"
echo "==========================="
echo "Monitoring token 67083 price and position details..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
VAULT_CONTRACT="0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"
PRIVATE_KEY="0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e"
TOKEN_ID="67083"

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
    local token_owner_raw=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error checking token ownership"
        return 1
    fi
    
    local token_owner=$(echo "$token_owner_raw" | sed 's/0x000000000000000000000000/0x/' | tr '[:upper:]' '[:lower:]')
    local owner_clean=$(echo "$OWNER_ADDRESS" | tr '[:upper:]' '[:lower:]')
    
    if [ "$token_owner" = "$owner_clean" ]; then
        echo "✅ Token ownership verified"
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
    echo "🔍 Getting position details from Uniswap Position Manager..."
    
    local position_data=$(cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error fetching position data"
        return 1
    fi
    
    # Decode position data
    python3 << EOF
try:
    data = "$position_data"
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
        
        print("📊 POSITION DETAILS:")
        print("===================")
        print(f"Token0: {token0}")
        print(f"Token1: {token1}")
        print(f"Fee Tier: {fee} ({fee/10000}%)")
        print(f"Tick Range: {tick_lower:,} to {tick_upper:,}")
        print(f"Liquidity: {liquidity:,}")
        print(f"Tokens Owed0: {tokens_owed0}")
        print(f"Tokens Owed1: {tokens_owed1}")
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
        
        print(f"🎯 PAIR: {token0_name}/{token1_name}")
        print(f"💰 Fee Tier: {fee/10000}%")
    else:
        print("❌ Invalid position data format")
        
except Exception as e:
    print(f"❌ Error decoding position: {e}")
EOF
}

# Function to get USD value from contract
get_usd_value() {
    echo "💰 Getting USD value from battle contract..."
    
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
        python3 << EOF
try:
    data = "$usd_result"
    chunks = [data[i:i+64] for i in range(2, len(data), 64)]
    
    if len(chunks) >= 3:
        amount0 = int(chunks[0], 16)
        amount1 = int(chunks[1], 16) 
        usd_value = int(chunks[2], 16)
        
        print("💵 USD VALUATION:")
        print("=================")
        print(f"Amount0: {amount0 / 1e18:.6f}")
        print(f"Amount1: {amount1 / 1e18:.6f}")
        print(f"Total USD Value: \${usd_value / 1e18:.6f}")
        print()
        
        return 0
    else:
        print("❌ Invalid USD value format")
        return 1
        
except Exception as e:
    print(f"❌ Error decoding USD value: {e}")
    return 1
EOF
        return $?
    fi
}

# Function to check position details from contract
get_contract_position_details() {
    echo "🔍 Getting position details from battle contract..."
    
    local position_result=$(cast call $VAULT_CONTRACT "getPositionDetails(uint256)" $TOKEN_ID --rpc-url $RPC_URL 2>&1)
    
    if [[ $position_result == *"error"* ]]; then
        echo "❌ Error getting position details: $position_result"
        return 1
    else
        # Decode position details
        python3 << EOF
try:
    data = "$position_result"
    chunks = [data[i:i+64] for i in range(2, len(data), 64)]
    
    if len(chunks) >= 11:
        token0 = '0x' + chunks[0][24:]
        token1 = '0x' + chunks[1][24:]
        fee = int(chunks[2], 16)
        tick_lower = int(chunks[3], 16)
        tick_upper = int(chunks[4], 16)
        liquidity = int(chunks[5], 16)
        amount0 = int(chunks[6], 16)
        amount1 = int(chunks[7], 16)
        value_usd = int(chunks[8], 16)
        fees0 = int(chunks[9], 16)
        fees1 = int(chunks[10], 16)
        
        # Convert signed ticks
        if tick_lower > 2**255:
            tick_lower = tick_lower - 2**256
        if tick_upper > 2**255:
            tick_upper = tick_upper - 2**256
        
        print("📋 CONTRACT POSITION DETAILS:")
        print("=============================")
        print(f"Token0: {token0}")
        print(f"Token1: {token1}")
        print(f"Fee: {fee} ({fee/10000}%)")
        print(f"Tick Range: {tick_lower:,} to {tick_upper:,}")
        print(f"Liquidity: {liquidity:,}")
        print(f"Amount0: {amount0 / 1e18:.6f}")
        print(f"Amount1: {amount1 / 1e18:.6f}")
        print(f"USD Value: \${value_usd / 1e18:.6f}")
        print(f"Fees0: {fees0 / 1e18:.6f}")
        print(f"Fees1: {fees1 / 1e18:.6f}")
        print()
        
except Exception as e:
    print(f"❌ Error decoding position details: {e}")
EOF
    fi
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
    
    echo "[$iteration] 📅 $current_time"
    echo "================================"
    
    # Check USD value
    if get_usd_value; then
        echo "✅ USD valuation successful"
    else
        echo "❌ USD valuation failed"
    fi
    
    echo ""
    
    # Get contract position details every 5 iterations
    if [ $((iteration % 5)) -eq 0 ]; then
        echo "🔄 Detailed position refresh:"
        get_contract_position_details
    fi
    
    echo "========================================"
    echo ""
    
    # Wait 30 seconds before next check
    sleep 30
done