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

# Function to get position details
get_position_summary() {
    echo "🎯 POSITION SUMMARY:"
    echo "==================="
    echo "Token ID: $TOKEN_ID"
    echo "Pair: WETH/USDC"
    echo "Fee Tier: 0.05%"
    echo "Owner: $OWNER_ADDRESS"
    echo "Contract: $VAULT_CONTRACT"
    echo ""
}

# Initial position summary
get_position_summary

echo "🚀 Starting USD value monitoring..."
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
    else
        echo "❌ USD valuation failed - likely price feed issue"
    fi
    
    echo ""
    echo "========================================"
    echo ""
    
    # Wait 30 seconds before next check
    sleep 30
done