#!/bin/bash

# Decode battle data and calculate NFT values
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

echo "🔍 Decoding Battle Data and NFT Values"
echo ""

# Your NFT data
YOUR_TOKEN_ID="66760"
echo "📍 Your NFT Token ID: $YOUR_TOKEN_ID"
echo ""

# Decode your position data
echo "🧮 Your NFT Position Data:"
POSITION_DATA="0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ca6118bd65778c454b67b11de39b9bb881915b40000000000000000000000000760afe86e5de5fa0ee542fc7b7b713e1c5425701000000000000000000000000f817257fed379853cde0fa4f97ab987181b1e5ea00000000000000000000000000000000000000000000000000000000000001f4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbd098fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbdafc0000000000000000000000000000000000000000000000000000027a8d9c487e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

echo "Raw position data: $POSITION_DATA"
echo ""

# Parse position data (each field is 32 bytes = 64 hex chars)
echo "📊 Decoded Position Fields:"
echo "nonce: $(echo $POSITION_DATA | cut -c3-66)"
echo "operator: 0x$(echo $POSITION_DATA | cut -c67-106)"
echo "token0: 0x$(echo $POSITION_DATA | cut -c107-146)"
echo "token1: 0x$(echo $POSITION_DATA | cut -c147-186)"
echo "fee: 0x$(echo $POSITION_DATA | cut -c187-194)"
echo "tickLower: $(echo $POSITION_DATA | cut -c195-258)"
echo "tickUpper: $(echo $POSITION_DATA | cut -c259-322)"
echo "liquidity: 0x$(echo $POSITION_DATA | cut -c323-386)"
echo ""

# Convert key values
FEE_HEX="0x$(echo $POSITION_DATA | cut -c191-194)"
FEE_DEC=$(cast --to-dec $FEE_HEX)
LIQUIDITY_HEX="0x$(echo $POSITION_DATA | cut -c323-386)"
LIQUIDITY_DEC=$(cast --to-dec $LIQUIDITY_HEX)

echo "Fee Tier: $FEE_DEC (0.$(printf "%04d" $((FEE_DEC/100)))%)"
echo "Liquidity: $LIQUIDITY_DEC"
echo ""

# Decode battle creator data
echo "⚔️ Battle Creator Data:"
BATTLE_DATA="0x000000000000000000000000564323ae0d8473103f3763814c5121ca9e48004b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbd08efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbdd2c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000104cc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e100000000000000000000000000000000000000000000000000470e8c5c3827635"

echo "Raw battle data: $BATTLE_DATA"
echo ""

echo "📊 Decoded Battle Fields:"
echo "creator: 0x$(echo $BATTLE_DATA | cut -c27-66)"
echo "tokenId: 0x$(echo $BATTLE_DATA | cut -c67-130)"
echo "opponent: 0x$(echo $BATTLE_DATA | cut -c131-170)"
echo "opponentTokenId: 0x$(echo $BATTLE_DATA | cut -c171-234)"
echo "tickLower: $(echo $BATTLE_DATA | cut -c235-298)"
echo "tickUpper: $(echo $BATTLE_DATA | cut -c299-362)"
echo "liquidity: 0x$(echo $BATTLE_DATA | cut -c363-426)"
echo "startTime: 0x$(echo $BATTLE_DATA | cut -c427-490)"
echo "duration: 0x$(echo $BATTLE_DATA | cut -c491-554)"
echo "status: 0x$(echo $BATTLE_DATA | cut -c555-618)"
echo "winner: 0x$(echo $BATTLE_DATA | cut -c619-682)"
echo "endTime: 0x$(echo $BATTLE_DATA | cut -c683-746)"

CREATOR_TOKEN_ID="0x$(echo $BATTLE_DATA | cut -c67-130)"
CREATOR_TOKEN_DEC=$(cast --to-dec $CREATOR_TOKEN_ID)
CREATOR_LIQUIDITY="0x$(echo $BATTLE_DATA | cut -c363-426)"
CREATOR_LIQUIDITY_DEC=$(cast --to-dec $CREATOR_LIQUIDITY)

echo ""
echo "Creator Token ID: $CREATOR_TOKEN_DEC"
echo "Creator Liquidity: $CREATOR_LIQUIDITY_DEC"
echo ""

# Calculate USD values using helper functions
echo "💰 Calculating USD Values:"
echo ""

# Get your NFT USD value using contract helper
echo "Your NFT ($YOUR_TOKEN_ID) USD Value:"
YOUR_USD_DATA=$(cast call $CONTRACT_ADDRESS "getLPTokenValueUSD(uint256)" $YOUR_TOKEN_ID --rpc-url $RPC_URL)
echo "Raw data: $YOUR_USD_DATA"

# Parse the returned data (amount0, amount1, usdValue)
YOUR_USD_VALUE="0x$(echo $YOUR_USD_DATA | cut -c131-194)"
YOUR_USD_DEC=$(cast --to-dec $YOUR_USD_VALUE)
echo "USD Value raw: $YOUR_USD_VALUE"
echo "USD Value decimal: $YOUR_USD_DEC"
echo "USD Value: \$$(echo "scale=6; $YOUR_USD_DEC / 1000000" | bc)"
echo ""

# Get creator's NFT USD value
echo "Creator's NFT ($CREATOR_TOKEN_DEC) USD Value:"
CREATOR_USD_DATA=$(cast call $CONTRACT_ADDRESS "getLPTokenValueUSD(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL)
echo "Raw data: $CREATOR_USD_DATA"

# Parse the returned data (amount0, amount1, usdValue)
CREATOR_USD_VALUE="0x$(echo $CREATOR_USD_DATA | cut -c131-194)"
CREATOR_USD_DEC=$(cast --to-dec $CREATOR_USD_VALUE)
echo "USD Value raw: $CREATOR_USD_VALUE"
echo "USD Value decimal: $CREATOR_USD_DEC"
echo "USD Value: \$$(echo "scale=6; $CREATOR_USD_DEC / 1000000" | bc)"
echo ""

# Calculate tolerance
echo "📏 Tolerance Check:"
TOLERANCE_5_PERCENT=$(echo "scale=0; $CREATOR_USD_DEC * 0.05" | bc)
MIN_VALUE=$(echo "scale=0; $CREATOR_USD_DEC - $TOLERANCE_5_PERCENT" | bc)
MAX_VALUE=$(echo "scale=0; $CREATOR_USD_DEC + $TOLERANCE_5_PERCENT" | bc)

echo "Required range (5% tolerance):"
echo "Min: \$$(echo "scale=2; $MIN_VALUE / 1000000" | bc) (raw: $MIN_VALUE)"
echo "Max: \$$(echo "scale=2; $MAX_VALUE / 1000000" | bc) (raw: $MAX_VALUE)"
echo ""
echo "Your value: \$$(echo "scale=2; $YOUR_USD_DEC / 1000000" | bc) (raw: $YOUR_USD_DEC)"
echo ""

if [ "$YOUR_USD_DEC" -ge "$MIN_VALUE" ] && [ "$YOUR_USD_DEC" -le "$MAX_VALUE" ]; then
    echo "✅ Your NFT IS within tolerance!"
else
    echo "❌ Your NFT is NOT within tolerance"
    DIFFERENCE=$(echo "scale=2; ($YOUR_USD_DEC - $CREATOR_USD_DEC) / $CREATOR_USD_DEC * 100" | bc)
    echo "Difference: ${DIFFERENCE}% (needs to be within ±5%)"
fi

echo ""
echo "🎯 Summary:"
echo "- Your NFT value: \$$(echo "scale=2; $YOUR_USD_DEC / 1000000" | bc)"
echo "- Creator NFT value: \$$(echo "scale=2; $CREATOR_USD_DEC / 1000000" | bc)" 
echo "- Required range: \$$(echo "scale=2; $MIN_VALUE / 1000000" | bc) - \$$(echo "scale=2; $MAX_VALUE / 1000000" | bc)"