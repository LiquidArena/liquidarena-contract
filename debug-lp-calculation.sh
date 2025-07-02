#!/bin/bash

# Debug LP calculation issues
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

echo "🐛 Debug LP Value Calculation Issues"
echo ""

# Get creator token ID from battle
BATTLE_DATA=$(cast call $CONTRACT_ADDRESS "battles(uint256)" 0 --rpc-url $RPC_URL)
CREATOR_TOKEN_ID="0x$(echo $BATTLE_DATA | cut -c539-578)"
CREATOR_TOKEN_DEC=$(cast --to-dec $CREATOR_TOKEN_ID)

echo "Creator Token ID: $CREATOR_TOKEN_DEC"
echo ""

# Get raw position data directly from Uniswap
echo "📍 Raw Position Data from Uniswap:"
POSITION_DATA=$(cast call $POSITION_MANAGER "positions(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL)
echo "Raw: $POSITION_DATA"
echo ""

# Parse position data
TOKEN0="0x$(echo $POSITION_DATA | cut -c107-146)"
TOKEN1="0x$(echo $POSITION_DATA | cut -c147-186)"
FEE_HEX="0x$(echo $POSITION_DATA | cut -c191-194)"
FEE_DEC=$(cast --to-dec $FEE_HEX)
LIQUIDITY_HEX="0x$(echo $POSITION_DATA | cut -c323-386)"
LIQUIDITY_DEC=$(cast --to-dec $LIQUIDITY_HEX)

echo "Token0: $TOKEN0"
echo "Token1: $TOKEN1" 
echo "Fee: $FEE_DEC"
echo "Liquidity: $LIQUIDITY_DEC"
echo ""

# Get pool data
echo "🏊 Pool Information:"
POOL=$(cast call "0x961235a9020B05C44DF1026D956D1F4D78014276" "getPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE_DEC --rpc-url $RPC_URL)
echo "Pool address: $POOL"

if [ "$POOL" != "0x0000000000000000000000000000000000000000" ]; then
    # Get current price from pool
    SLOT0=$(cast call $POOL "slot0()" --rpc-url $RPC_URL)
    SQRT_PRICE_X96="0x$(echo $SLOT0 | cut -c3-66)"
    SQRT_PRICE_DEC=$(cast --to-dec $SQRT_PRICE_X96)
    
    echo "sqrtPriceX96: $SQRT_PRICE_X96"
    echo "sqrtPriceX96 (decimal): $SQRT_PRICE_DEC"
    echo ""
    
    # Calculate actual price (price = (sqrtPriceX96 / 2^96)^2)
    echo "🧮 Price Calculation Debug:"
    echo "Q96 = 2^96 = 79228162514264337593543950336"
    
    # This is what the contract does (WRONG):
    echo ""
    echo "❌ Contract's Wrong Calculation:"
    echo "amount0 = liquidity * 1e18 / sqrtPriceX96"
    echo "amount1 = liquidity * sqrtPriceX96 / 1e18"
    WRONG_AMOUNT0=$(echo "scale=0; $LIQUIDITY_DEC * 1000000000000000000 / $SQRT_PRICE_DEC" | bc)
    WRONG_AMOUNT1=$(echo "scale=0; $LIQUIDITY_DEC * $SQRT_PRICE_DEC / 1000000000000000000" | bc)
    echo "Wrong amount0: $WRONG_AMOUNT0"
    echo "Wrong amount1: $WRONG_AMOUNT1"
    echo ""
    
    echo "✅ What it should be (simplified):"
    echo "For current tick range, proper Uniswap V3 math would be:"
    echo "amount0 = liquidity * (sqrt(upper) - sqrt(current)) / (sqrt(current) * sqrt(upper))"
    echo "amount1 = liquidity * (sqrt(current) - sqrt(lower))"
    echo "(This requires tick math and is complex)"
    
fi

echo ""
echo "🎯 The Problem:"
echo "1. Contract uses wrong formulas for liquidity → token amounts"
echo "2. Wrong price calculations with arbitrary 1e18/1e36 scaling"
echo "3. No decimal normalization between different tokens"
echo "4. Results in astronomical USD values like \$300B"
echo ""

echo "💡 Solutions:"
echo "1. Fix the contract's math (requires contract upgrade)"
echo "2. Use external price feeds instead of pool-based calculation"
echo "3. Create manual tolerance override for testing"
echo ""

echo "🚨 Current Status:"
echo "The tolerance check will always fail because the USD calculations are meaningless"
echo "Your LP positions likely have similar actual values, but the contract calculates them wrong"