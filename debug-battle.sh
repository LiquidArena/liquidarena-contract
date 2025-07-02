#!/bin/bash

# Debug battle data parsing
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

echo "🐛 Debug Battle 0 Data"
echo ""

# Get raw battle data
echo "📊 Raw Battle Data:"
BATTLE_DATA=$(cast call $CONTRACT_ADDRESS "battles(uint256)" 0 --rpc-url $RPC_URL)
echo "Raw: $BATTLE_DATA"
echo ""

# Parse according to Battle struct:
# struct Battle {
#     address creator;           // 32 bytes (0-63)
#     address opponent;          // 32 bytes (64-127) 
#     address winner;            // 32 bytes (128-191)
#     bool isResolved;           // 32 bytes (192-255)
#     int24 creatorTickLower;    // 32 bytes (256-319)
#     int24 creatorTickUpper;    // 32 bytes (320-383)
#     int24 opponentTickLower;   // 32 bytes (384-447)
#     int24 opponentTickUpper;   // 32 bytes (448-511)
#     uint256 creatorTokenId;    // 32 bytes (512-575) ← This is what we want!
#     uint256 opponentTokenId;   // 32 bytes (576-639)
#     uint256 startTime;         // 32 bytes (640-703)
#     uint256 duration;          // 32 bytes (704-767)
#     uint256 totalValueUSD;     // 32 bytes (768-831)
# }

echo "📋 Decoded Battle Fields:"
CREATOR="0x$(echo $BATTLE_DATA | cut -c27-66)"
OPPONENT="0x$(echo $BATTLE_DATA | cut -c91-130)"
WINNER="0x$(echo $BATTLE_DATA | cut -c155-194)"
IS_RESOLVED="0x$(echo $BATTLE_DATA | cut -c219-258)"
CREATOR_TICK_LOWER="0x$(echo $BATTLE_DATA | cut -c283-322)"
CREATOR_TICK_UPPER="0x$(echo $BATTLE_DATA | cut -c347-386)"
OPPONENT_TICK_LOWER="0x$(echo $BATTLE_DATA | cut -c411-450)"
OPPONENT_TICK_UPPER="0x$(echo $BATTLE_DATA | cut -c475-514)"
CREATOR_TOKEN_ID="0x$(echo $BATTLE_DATA | cut -c539-578)"  # This should be the real token ID
OPPONENT_TOKEN_ID="0x$(echo $BATTLE_DATA | cut -c603-642)"
START_TIME="0x$(echo $BATTLE_DATA | cut -c667-706)"
DURATION="0x$(echo $BATTLE_DATA | cut -c731-770)"
TOTAL_VALUE_USD="0x$(echo $BATTLE_DATA | cut -c795-834)"

echo "Creator: $CREATOR"
echo "Opponent: $OPPONENT"
echo "Winner: $WINNER"
echo "Is Resolved: $IS_RESOLVED"
echo "Creator Tick Lower: $CREATOR_TICK_LOWER"
echo "Creator Tick Upper: $CREATOR_TICK_UPPER"
echo "Opponent Tick Lower: $OPPONENT_TICK_LOWER"
echo "Opponent Tick Upper: $OPPONENT_TICK_UPPER"
echo "Creator Token ID: $CREATOR_TOKEN_ID"
echo "Opponent Token ID: $OPPONENT_TOKEN_ID"
echo "Start Time: $START_TIME"
echo "Duration: $DURATION"
echo "Total Value USD: $TOTAL_VALUE_USD"
echo ""

# Convert creator token ID to decimal
CREATOR_TOKEN_DEC=$(cast --to-dec $CREATOR_TOKEN_ID)
echo "🎯 Creator Token ID (decimal): $CREATOR_TOKEN_DEC"
echo ""

# Now try to get the creator's USD value with the correct token ID
if [ "$CREATOR_TOKEN_DEC" != "0" ]; then
    echo "💰 Getting Creator's NFT USD Value (Token ID: $CREATOR_TOKEN_DEC):"
    CREATOR_USD_DATA=$(cast call $CONTRACT_ADDRESS "getLPTokenValueUSD(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
    
    if [ "$CREATOR_USD_DATA" != "ERROR" ]; then
        echo "Creator USD data: $CREATOR_USD_DATA"
        
        # Parse USD value (3rd return value)
        CREATOR_USD_VALUE="0x$(echo $CREATOR_USD_DATA | cut -c131-194)"
        CREATOR_USD_DEC=$(cast --to-dec $CREATOR_USD_VALUE)
        echo "Creator USD Value: \$$(echo "scale=6; $CREATOR_USD_DEC / 1000000" | bc)"
        
        # Calculate 5% tolerance
        TOLERANCE=$(echo "scale=0; $CREATOR_USD_DEC * 0.05" | bc)
        MIN_VALUE=$(echo "scale=0; $CREATOR_USD_DEC - $TOLERANCE" | bc)
        MAX_VALUE=$(echo "scale=0; $CREATOR_USD_DEC + $TOLERANCE" | bc)
        
        echo ""
        echo "📏 Required Range for Joining (±5%):"
        echo "Min: \$$(echo "scale=6; $MIN_VALUE / 1000000" | bc) (raw: $MIN_VALUE)"
        echo "Max: \$$(echo "scale=6; $MAX_VALUE / 1000000" | bc) (raw: $MAX_VALUE)"
        
    else
        echo "❌ Failed to get creator's USD value"
    fi
else
    echo "❌ Creator token ID is 0 - battle might not be properly created"
fi

echo ""
echo "🔍 Now check your NFTs against this range..."