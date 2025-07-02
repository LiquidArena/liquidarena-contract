#!/bin/bash

# Debug pool existence and token information
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
FACTORY="0x961235a9020B05C44DF1026D956D1F4D78014276"
RPC_URL="https://testnet-rpc.monad.xyz"

echo "🔍 Debug Pool Existence Issues"
echo ""

# Get creator token ID from battle
BATTLE_DATA=$(cast call $CONTRACT_ADDRESS "battles(uint256)" 0 --rpc-url $RPC_URL)
CREATOR_TOKEN_ID="0x$(echo $BATTLE_DATA | cut -c539-578)"
CREATOR_TOKEN_DEC=$(cast --to-dec $CREATOR_TOKEN_ID)

echo "Creator Token ID: $CREATOR_TOKEN_DEC"
echo ""

# Check if this token ID actually exists
echo "📍 Checking if Token ID exists:"
OWNER_CHECK=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")

if [ "$OWNER_CHECK" = "ERROR" ]; then
    echo "❌ Token ID $CREATOR_TOKEN_DEC does not exist!"
    echo "This means the battle was created with an invalid/non-existent NFT"
    echo ""
    echo "Possible reasons:"
    echo "1. The NFT was burned or transferred after battle creation"
    echo "2. The battle data parsing is incorrect"
    echo "3. The battle wasn't created properly"
    echo ""
    exit 1
else
    echo "✅ Token ID $CREATOR_TOKEN_DEC exists"
    echo "Owner: $OWNER_CHECK"
fi

# Get position data
echo ""
echo "📊 Position Data:"
POSITION_DATA=$(cast call $POSITION_MANAGER "positions(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL)
echo "Raw position: $POSITION_DATA"

# Parse position data
TOKEN0="0x$(echo $POSITION_DATA | cut -c107-146)"
TOKEN1="0x$(echo $POSITION_DATA | cut -c147-186)"
FEE_HEX="0x$(echo $POSITION_DATA | cut -c191-194)"
FEE_DEC=$(cast --to-dec $FEE_HEX)
LIQUIDITY_HEX="0x$(echo $POSITION_DATA | cut -c323-386)"
LIQUIDITY_DEC=$(cast --to-dec $LIQUIDITY_HEX)

echo ""
echo "Token0: $TOKEN0"
echo "Token1: $TOKEN1"
echo "Fee: $FEE_DEC"
echo "Liquidity: $LIQUIDITY_DEC"
echo ""

# Check if tokens are valid
echo "🔍 Checking Token Validity:"
echo "Token0 name:"
TOKEN0_NAME=$(cast call $TOKEN0 "name()" --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
echo "  $TOKEN0_NAME"

echo "Token1 name:"
TOKEN1_NAME=$(cast call $TOKEN1 "name()" --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
echo "  $TOKEN1_NAME"

# Check pool existence
echo ""
echo "🏊 Pool Check:"
echo "Checking pool for tokens: $TOKEN0, $TOKEN1, fee: $FEE_DEC"

# Try different fee tiers
for fee_tier in 500 3000 10000; do
    echo "Trying fee tier: $fee_tier"
    POOL=$(cast call $FACTORY "getPool(address,address,uint24)" $TOKEN0 $TOKEN1 $fee_tier --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
    
    if [ "$POOL" != "ERROR" ] && [ "$POOL" != "0x0000000000000000000000000000000000000000" ]; then
        echo "  ✅ Pool found at fee $fee_tier: $POOL"
        
        # Get pool slot0 data
        SLOT0=$(cast call $POOL "slot0()" --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
        if [ "$SLOT0" != "ERROR" ]; then
            echo "  Pool slot0: $SLOT0"
        else
            echo "  ❌ Pool exists but slot0 failed"
        fi
    else
        echo "  ❌ No pool at fee tier $fee_tier"
    fi
done

echo ""
echo "🚨 Root Cause Analysis:"
if [ "$LIQUIDITY_DEC" = "0" ]; then
    echo "❌ LIQUIDITY IS ZERO - This means the LP position is empty!"
    echo "Possible reasons:"
    echo "1. All liquidity was removed from the position"
    echo "2. The position was closed"
    echo "3. The position is out of range with no active liquidity"
    echo ""
    echo "💡 Solution: Use an active LP position with liquidity > 0"
elif [ "$TOKEN0" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ TOKEN ADDRESSES ARE ZERO - Position data is corrupted"
else
    echo "✅ Position looks valid but pool might not exist for this exact fee tier"
    echo "The contract's getLPTokenValueUSD function fails because:"
    echo "1. It can't find the pool for the exact token pair + fee combination"
    echo "2. This causes the USD calculation to fail"
    echo "3. Without USD values, the tolerance check can't work"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Check if you have any LP positions with active liquidity"
echo "2. Use ./check-real-nfts.sh to find your valid NFTs"
echo "3. Create a new battle instead of joining this broken one" 