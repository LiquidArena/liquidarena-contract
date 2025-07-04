#!/bin/bash

# Check Token Values for 67083 and 66760
# New Contract: 0xDAC45c475b8446810ED89281773763c628c2e103

echo "🔍 TOKEN VALUE CHECKER"
echo "====================="
echo "Checking token values for tokens 67083 and 66760..."
echo ""

# Contract addresses
VAULT_CONTRACT="0xDAC45c475b8446810ED89281773763c628c2e103"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Token IDs to check
TOKEN_IDS=("67083" "68140")

# Function to get USD value from contract
get_usd_value() {
    local token_id=$1
    echo "💰 Getting USD value for token $token_id..."
    
    local usd_result=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $token_id --rpc-url $RPC_URL 2>&1)
    
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
        
        print("💵 TOKEN $token_id USD VALUATION:")
        print("=================================")
        print(f"Amount0: {amount0 / 1e18:.6f}")
        print(f"Amount1: {amount1 / 1e18:.6f}")
        print(f"Total USD Value: \${usd_value / 1e18:.6f}")
        print()
        
    else:
        print("❌ Invalid USD value format")
        
except Exception as e:
    print(f"❌ Error decoding USD value: {e}")
EOF
        return $?
    fi
}

# Function to get position details
get_position_details() {
    local token_id=$1
    echo "🔍 Getting position details for token $token_id..."
    
    local position_data=$(cast call $POSITION_MANAGER "positions(uint256)" $token_id --rpc-url $RPC_URL 2>/dev/null)
    
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
        token0 = '0x' + chunks[2][24:]
        token1 = '0x' + chunks[3][24:]
        fee = int(chunks[4], 16)
        tick_lower = int(chunks[5], 16)
        tick_upper = int(chunks[6], 16)
        liquidity = int(chunks[7], 16)
        
        # Convert signed ticks
        if tick_lower > 2**255:
            tick_lower = tick_lower - 2**256
        if tick_upper > 2**255:
            tick_upper = tick_upper - 2**256
        
        print("📊 TOKEN $token_id POSITION DETAILS:")
        print("====================================")
        print(f"Token0: {token0}")
        print(f"Token1: {token1}")
        print(f"Fee Tier: {fee} ({fee/10000}%)")
        print(f"Tick Range: {tick_lower:,} to {tick_upper:,}")
        print(f"Liquidity: {liquidity:,}")
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
        print()
        
except Exception as e:
    print(f"❌ Error decoding position: {e}")
EOF
}

echo "🎯 CHECKING SETUP:"
echo "=================="
echo "Contract: $VAULT_CONTRACT"
echo "Position Manager: $POSITION_MANAGER"
echo ""

# Check each token
for TOKEN_ID in "${TOKEN_IDS[@]}"; do
    echo "=========================================="
    echo "🔍 CHECKING TOKEN ID: $TOKEN_ID"
    echo "=========================================="
    
    # Get position details
    get_position_details $TOKEN_ID
    
    # Get USD value
    get_usd_value $TOKEN_ID
    
    echo ""
done

echo "✅ Token value check completed!"