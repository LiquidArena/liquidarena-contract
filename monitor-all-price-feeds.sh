#!/bin/bash

# Monitor All Price Feeds (WETH + WBTC) for Cross-Pool Battle
# This script monitors both price feeds needed for the cross-pool battle

echo "📡 CROSS-POOL BATTLE PRICE FEED MONITOR"
echo "======================================="
echo "Monitoring WETH + WBTC price feeds for cross-pool battle readiness..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
WETH_PRICE_FEED="0x0c76859E85727683Eeba0C70Bc2e0F5781337818"
WBTC_PRICE_FEED="0x2Cd9D7E85494F68F5aF08EF96d6FD5e8F71B4d31"
RPC_URL="https://testnet-rpc.monad.xyz"
STALENESS_THRESHOLD=3600  # 1 hour

# Battle details
BATTLE_ID="1"
TOKEN_ID_WETH="67082"  # WETH/USDC pair (opponent)
TOKEN_ID_WBTC="67327"  # WBTC/USDC pair (creator)
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"

echo "🎯 CROSS-POOL BATTLE SETUP:"
echo "  Battle ID: $BATTLE_ID"
echo "  Creator Token: $TOKEN_ID_WBTC (WBTC/USDC) - needs WBTC price"
echo "  Opponent Token: $TOKEN_ID_WETH (WETH/USDC) - needs WETH price"
echo ""
echo "📊 PRICE FEEDS:"
echo "  WETH: $WETH_PRICE_FEED"
echo "  WBTC: $WBTC_PRICE_FEED"
echo "⏰ Staleness Threshold: $STALENESS_THRESHOLD seconds (60 minutes)"
echo ""

# Function to check a specific price feed
check_price_feed() {
    local feed_name=$1
    local feed_address=$2
    local current_time=$(date +%s)
    
    local feed_data=$(cast call $feed_address "latestRoundData()" --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ $feed_name: Error fetching data"
        return 1
    fi
    
    # Extract data from the response
    local round_id_hex=${feed_data:2:64}
    local price_hex=${feed_data:66:64}
    local started_at_hex=${feed_data:130:64}
    local updated_at_hex=${feed_data:194:64}
    local answered_in_round_hex=${feed_data:258:64}
    
    # Convert to decimal
    local round_id=$((16#$round_id_hex))
    local price_raw=$((16#$price_hex))
    local started_at=$((16#$started_at_hex))
    local updated_at=$((16#$updated_at_hex))
    local answered_in_round=$((16#$answered_in_round_hex))
    
    # Calculate age and price
    local age=$((current_time - updated_at))
    local price=$(echo "scale=2; $price_raw / 100000000" | bc -l)
    local age_minutes=$(echo "scale=1; $age / 60" | bc -l)
    local age_hours=$(echo "scale=2; $age / 3600" | bc -l)
    
    # Determine status
    local status
    if [ $age -le $STALENESS_THRESHOLD ]; then
        status="✅ FRESH"
        echo "$feed_name: Age ${age}s (${age_minutes}m) | \$${price} | $status"
        return 0  # Fresh
    else
        local stale_by=$((age - STALENESS_THRESHOLD))
        local stale_minutes=$(echo "scale=1; $stale_by / 60" | bc -l)
        status="❌ STALE (by ${stale_by}s / ${stale_minutes}m)"
        echo "$feed_name: Age ${age}s (${age_minutes}m) | \$${price} | $status"
        return 1  # Stale
    fi
}

# Function to test token USD value
test_token_value() {
    local token_name=$1
    local token_id=$2
    
    local result=$(cast call $VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $token_id --rpc-url $RPC_URL 2>&1)
    
    if [[ $result == *"StalePrice"* ]] || [[ $result == *"0x19abf40e"* ]]; then
        echo "  🧪 $token_name (ID:$token_id): ❌ StalePrice error"
        return 1
    elif [[ $result == *"error"* ]]; then
        echo "  🧪 $token_name (ID:$token_id): ❌ Error: $result"
        return 1
    else
        # Decode the USD value (3rd 32-byte chunk)
        local usd_hex=${result:130:64}
        local usd_raw=$((16#$usd_hex))
        local usd_value=$(echo "scale=6; $usd_raw / 1000000000000000000" | bc -l)
        echo "  🧪 $token_name (ID:$token_id): ✅ \$${usd_value} USD"
        return 0
    fi
}

# Function to test battle join capability
test_battle_join() {
    echo ""
    echo "🎯 Testing Battle Join Capability:"
    echo "=================================="
    
    local can_join_result=$(cast call $VAULT_CONTRACT "canJoinBattle(uint256,uint256)" $BATTLE_ID $TOKEN_ID_WETH --rpc-url $RPC_URL 2>&1)
    
    if [[ $can_join_result == *"StalePrice"* ]] || [[ $can_join_result == *"0x19abf40e"* ]]; then
        echo "❌ Cannot join battle: StalePrice error"
        return 1
    elif [[ $can_join_result == *"LPValueNotWithinTolerance"* ]] || [[ $can_join_result == *"0x7510d5f5"* ]]; then
        echo "❌ Cannot join battle: LP value not within 5% tolerance"
        echo "  💡 This means price feeds work, but token values are too different"
        return 2
    elif [[ $can_join_result == *"error"* ]]; then
        echo "❌ Cannot join battle: Other error"
        echo "  📄 Details: $can_join_result"
        return 1
    else
        echo "✅ CAN JOIN BATTLE! All conditions met"
        echo "  📊 Result: $can_join_result"
        return 0
    fi
}

# Function to show battle readiness summary
show_battle_status() {
    local weth_fresh=$1
    local wbtc_fresh=$2
    
    echo ""
    echo "📊 BATTLE READINESS SUMMARY:"
    echo "============================"
    echo "WETH Price Feed: $([ $weth_fresh -eq 0 ] && echo "✅ FRESH" || echo "❌ STALE")"
    echo "WBTC Price Feed: $([ $wbtc_fresh -eq 0 ] && echo "✅ FRESH" || echo "❌ STALE")"
    
    if [ $weth_fresh -eq 0 ] && [ $wbtc_fresh -eq 0 ]; then
        echo "🎉 BOTH FEEDS FRESH - READY FOR CROSS-POOL BATTLE!"
    elif [ $weth_fresh -eq 0 ]; then
        echo "🔄 WETH ready, WBTC stale - Creator token may have issues"
    elif [ $wbtc_fresh -eq 0 ]; then
        echo "🔄 WBTC ready, WETH stale - Opponent token blocked"
    else
        echo "⏳ BOTH FEEDS STALE - Need to wait for updates"
    fi
}

# Main monitoring loop
iteration=0
echo "Starting monitoring... (Updates every 30 seconds)"
echo ""

while true; do
    iteration=$((iteration + 1))
    current_time=$(date '+%H:%M:%S')
    
    echo "[$iteration] 📅 $current_time"
    echo "----------------------------------------"
    
    # Check both price feeds
    check_price_feed "WETH" $WETH_PRICE_FEED
    weth_status=$?
    
    check_price_feed "WBTC" $WBTC_PRICE_FEED
    wbtc_status=$?
    
    # Test token values
    echo ""
    echo "🧪 Token Value Tests:"
    test_token_value "WBTC/USDC" $TOKEN_ID_WBTC
    test_token_value "WETH/USDC" $TOKEN_ID_WETH
    
    # Show battle readiness
    show_battle_status $weth_status $wbtc_status
    
    # If both feeds are fresh, test battle join
    if [ $weth_status -eq 0 ] && [ $wbtc_status -eq 0 ]; then
        test_battle_join
        join_result=$?
        
        if [ $join_result -eq 0 ]; then
            echo ""
            echo "🚀 CROSS-POOL BATTLE IS READY!"
            echo "=============================="
            echo "Both price feeds are fresh and battle can proceed!"
            echo ""
            echo "Ready-to-use command:"
            echo "./join-battle-67082.sh"
            echo ""
            echo "Or manual command:"
            echo "cast send 0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0 \\"
            echo "  \"joinBattle(uint256,uint256)\" \\"
            echo "  1 67082 \\"
            echo "  --private-key 0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419 \\"
            echo "  --rpc-url https://testnet-rpc.monad.xyz"
            break
        elif [ $join_result -eq 2 ]; then
            echo ""
            echo "⚠️  Price feeds are fresh but tokens have different values"
            echo "This is expected - continue monitoring for value convergence"
        fi
    fi
    
    echo ""
    echo "========================================================"
    echo ""
    
    # Wait 30 seconds before next check
    sleep 30
done

echo ""
echo "🏁 Monitoring stopped. Cross-pool battle is ready to proceed!"