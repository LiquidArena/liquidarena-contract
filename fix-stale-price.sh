#!/bin/bash

# Fix Stale Price Issue by temporarily increasing staleness threshold
# This is a temporary workaround for testnet price feed issues

echo "🔧 Fixing Stale Price Issue"
echo "=========================="

# Contract addresses  
VAULT_CONTRACT="0x49d34E2854f8efA3942094e9c1C07C742BF5EDC0"
RPC_URL="https://testnet-rpc.monad.xyz"

# Owner private key (same as battle creator)
OWNER_PRIVATE_KEY="0xdc4220c74497a92e5ba171fadf2021ced04ed6af37853399d55d3fa70e45ca8e"

echo "⚠️  NOTE: This is a temporary fix for testnet price feed staleness"
echo "Contract: $VAULT_CONTRACT"
echo ""

# Get owner address
OWNER_ADDRESS=$(cast wallet address --private-key $OWNER_PRIVATE_KEY)
echo "🔑 Owner Address: $OWNER_ADDRESS"

# Check current staleness threshold
echo ""
echo "🔍 Current Price Staleness Threshold"
echo "===================================="
CURRENT_THRESHOLD=$(cast call $VAULT_CONTRACT "PRICE_STALENESS_THRESHOLD()" --rpc-url $RPC_URL)
echo "Current threshold: $CURRENT_THRESHOLD seconds"

# Convert to decimal
CURRENT_THRESHOLD_DEC=$(python3 -c "print(int('$CURRENT_THRESHOLD', 16))")
echo "Current threshold (decimal): $CURRENT_THRESHOLD_DEC seconds ($(($CURRENT_THRESHOLD_DEC / 3600)) hours)"

echo ""
echo "⚠️  IMPORTANT: We cannot modify the constant PRICE_STALENESS_THRESHOLD"
echo "                as it's a constant in the contract."
echo ""
echo "🔧 Alternative Solutions:"
echo "1. Wait for Chainlink price feeds to update (may take time on testnet)"
echo "2. Use LP positions with only stablecoin pairs (USDC/USDT)"
echo "3. Deploy a new contract with higher staleness threshold"
echo ""

echo "🔍 Let's check the price feed ages:"
echo "=================================="

# Check WETH price feed
echo "Checking WETH price feed..."
WETH_FEED_DATA=$(cast call 0x0c76859E85727683Eeba0C70Bc2e0F5781337818 "latestRoundData()" --rpc-url $RPC_URL)
echo "WETH feed data: $WETH_FEED_DATA"

# Check WBTC price feed
echo ""
echo "Checking WBTC price feed..."
WBTC_FEED_DATA=$(cast call 0x2Cd9D7E85494F68F5aF08EF96d6FD5e8F71B4d31 "latestRoundData()" --rpc-url $RPC_URL)
echo "WBTC feed data: $WBTC_FEED_DATA"

echo ""
echo "🎯 RECOMMENDATION:"
echo "================="
echo "Since the price feeds are stale, let's create battles with stablecoin pairs instead."
echo "These bypass the price feed requirement since stablecoins are assumed to be \$1."
echo ""
echo "Look for USDC/USDT LP positions that can be used for fair battles."
echo ""
echo "Or wait for the price feeds to update naturally (may take several hours on testnet)."