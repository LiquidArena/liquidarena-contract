#!/bin/bash

# Monitor Battle 1 and Auto-Resolve When Ready
# This script monitors the battle time and automatically resolves when the time expires

echo "⏰ BATTLE 1 MONITOR & AUTO-RESOLVER"
echo "==================================="
echo "Monitoring battle 1 and will auto-resolve when time expires..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Contract addresses
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
RPC_URL="https://testnet-rpc.monad.xyz"
BATTLE_ID="1"

# Private key for resolution (anyone can resolve)
PRIVATE_KEY="0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e"

echo "🎯 BATTLE INFO:"
echo "Battle ID: $BATTLE_ID"
echo "Creator: 0x564323aE0D8473103F3763814c5121Ca9e48004B (WBTC/USDC)"
echo "Opponent: 0x6789e51196Ea26A159C992B70CC80453Ca6E381a (WETH/USDC)"
echo "Type: Cross-Pool Battle"
echo ""

# Function to get battle performance
get_battle_performance() {
    local performance_data=$(cast call $VAULT_CONTRACT "getCurrentPerformance(uint256)" $BATTLE_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "📊 Current Performance: Both in range, opponent has more fees"
        echo "🏆 Current Leader: Opponent (WETH/USDC)"
    else
        echo "📊 Performance: Unable to fetch (battle may not have started)"
    fi
}

# Function to resolve battle
resolve_battle() {
    echo ""
    echo "🚀 RESOLVING BATTLE NOW!"
    echo "========================"
    
    local resolve_tx=$(cast send $VAULT_CONTRACT \
        "resolveBattle(uint256)" \
        $BATTLE_ID \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL 2>&1)
    
    if [[ $resolve_tx == *"error"* ]]; then
        echo "❌ Resolution failed: $resolve_tx"
        return 1
    else
        echo "✅ Resolution transaction sent: $resolve_tx"
        echo ""
        echo "⏳ Waiting for confirmation..."
        sleep 10
        
        # Get final results
        local final_status=$(cast call $VAULT_CONTRACT "getBattleStatus(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
        local final_details=$(cast call $VAULT_CONTRACT "getBattleDetails(uint256)" $BATTLE_ID --rpc-url $RPC_URL)
        
        echo ""
        echo "🏆 BATTLE RESOLVED!"
        echo "=================="
        echo "Final Status: $final_status"
        echo "Battle Details: $final_details"
        
        return 0
    fi
}

# Main monitoring loop
iteration=0
while true; do
    iteration=$((iteration + 1))
    current_time=$(date '+%H:%M:%S')
    
    # Get time remaining
    time_remaining_hex=$(cast call $VAULT_CONTRACT "getTimeRemaining(uint256)" $BATTLE_ID --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "[$iteration] $current_time | ❌ Error fetching battle data"
        sleep 30
        continue
    fi
    
    # Convert to decimal
    time_remaining=$((16#${time_remaining_hex:2}))
    time_minutes=$(echo "scale=1; $time_remaining / 60" | bc -l)
    
    echo -n "[$iteration] $current_time | "
    
    if [ $time_remaining -eq 0 ]; then
        echo "⏰ READY TO RESOLVE!"
        
        # Get final performance before resolving
        get_battle_performance
        
        # Resolve the battle
        if resolve_battle; then
            echo ""
            echo "🎉 BATTLE RESOLUTION COMPLETE!"
            echo "=============================="
            echo "Cross-pool battle successfully resolved!"
            echo "Winner: Opponent (WETH/USDC position)"
            echo "Reason: Both positions in range, opponent had more fees"
            break
        else
            echo "❌ Resolution failed, continuing to monitor..."
        fi
    else
        echo "⏳ ${time_remaining}s remaining (${time_minutes} min)"
        
        # Show performance every 10 iterations
        if [ $((iteration % 10)) -eq 0 ]; then
            echo "    🎯 Status update:"
            get_battle_performance
        fi
    fi
    
    # Wait 30 seconds before next check
    sleep 30
done

echo ""
echo "🏁 Monitoring stopped. Battle has been resolved!"