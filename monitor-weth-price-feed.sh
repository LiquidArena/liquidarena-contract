#!/bin/bash

# Monitor WETH Price Feed for Staleness Updates
# This script will continuously check when WETH price feed becomes fresh again

echo "📡 WETH Price Feed Monitor"
echo "========================="
echo "Monitoring WETH price feed for freshness updates..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
WETH_PRICE_FEED="0x0c76859E85727683Eeba0C70Bc2e0F5781337818"
RPC_URL="https://testnet-rpc.monad.xyz"
STALENESS_THRESHOLD=3600  # 1 hour

# Token details for testing
BATTLE_ID="1"
TOKEN_ID_WETH="67082"  # WETH/USDC pair
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"

echo "🎯 Target: Token ID $TOKEN_ID_WETH (WETH/USDC) to join Battle ID $BATTLE_ID"
echo "📊 WETH Price Feed: $WETH_PRICE_FEED"
echo "⏰ Staleness Threshold: $STALENESS_THRESHOLD seconds (60 minutes)"
echo ""

# Function to check WETH price feed
check_weth_feed() {
    local current_time=$(date +%s)
    local feed_data=$(cast call $WETH_PRICE_FEED "latestRoundData()" --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error fetching price feed data"
        return 1
    fi
    
    # Extract timestamp (4th 32-byte chunk, bytes 194-258)
    local timestamp_hex=${feed_data:194:64}
    local updated_at=$((16#$timestamp_hex))
    local age=$((current_time - updated_at))
    
    # Extract price (2nd 32-byte chunk, bytes 66-130)
    local price_hex=${feed_data:66:64}
    local price_raw=$((16#$price_hex))
    local price=$(echo "scale=2; $price_raw / 100000000" | bc -l)
    
    echo "📅 $(date '+%H:%M:%S') | Age: ${age}s ($(echo "scale=1; $age/60" | bc -l)min) | Price: \$${price} | Status: $([ $age -le $STALENESS_THRESHOLD ] && echo "✅ FRESH" || echo "❌ STALE")"
    
    # Check if fresh
    if [ $age -le $STALENESS_THRESHOLD ]; then
        return 0  # Fresh
    else
        return 1  # Stale
    fi
}

# Function to test joining battle
test_join_battle() {
    echo ""
    echo "🧪 Testing if token $TOKEN_ID_WETH can now join battle..."
    
    local result=$(cast call $VAULT_CONTRACT "canJoinBattle(uint256,uint256)" $BATTLE_ID $TOKEN_ID_WETH --rpc-url $RPC_URL 2>&1)
    
    if [[ $result == *"StalePrice"* ]] || [[ $result == *"0x19abf40e"* ]]; then
        echo "❌ Still getting StalePrice error"
        return 1
    elif [[ $result == *"error"* ]]; then
        echo "❌ Other error: $result"
        return 1
    else
        echo "✅ SUCCESS! Token can now join the battle!"
        echo "📊 Result: $result"
        return 0
    fi
}

# Main monitoring loop
iteration=0
while true; do
    iteration=$((iteration + 1))
    
    echo -n "[$iteration] "
    
    if check_weth_feed; then
        echo ""
        echo "🎉 WETH PRICE FEED IS NOW FRESH!"
        echo "================================"
        
        # Test if we can join the battle
        if test_join_battle; then
            echo ""
            echo "🚀 READY TO JOIN BATTLE!"
            echo "======================="
            echo "You can now run: ./join-battle-67082.sh"
            echo ""
            echo "Or manually join with:"
            echo "cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \\"
            echo "  \"joinBattle(uint256,uint256)\" \\"
            echo "  1 67082 \\"
            echo "  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \\"
            echo "  --rpc-url https://testnet-rpc.monad.xyz"
            break
        fi
    fi
    
    # Wait 30 seconds before next check
    sleep 30
done

echo ""
echo "🏁 Monitoring stopped. WETH price feed is fresh and ready for cross-pool battle!"