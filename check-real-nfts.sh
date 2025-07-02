#!/bin/bash

# Check actual NFTs owned by your address
# Contract: 0xca6118BD65778C454B67B11DE39B9BB881915b40

set -e

CONTRACT_ADDRESS="0xca6118BD65778C454B67B11DE39B9BB881915b40"
POSITION_MANAGER="0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7"
RPC_URL="https://testnet-rpc.monad.xyz"

# Your private key
PRIVATE_KEY="0xb0fa99ac07b0deeff3c88905912a9e020270b9da93d89a2448a298dd6a286419"

echo "🔍 Checking Real NFTs for Your Address"
echo ""

# Get your wallet address
YOUR_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Your address: $YOUR_ADDRESS"
echo ""

# Check your actual NFT balance
echo "📊 Checking NFT balance..."
NFT_BALANCE=$(cast call $POSITION_MANAGER "balanceOf(address)" $YOUR_ADDRESS --rpc-url $RPC_URL)
NFT_COUNT=$(cast --to-dec $NFT_BALANCE)
echo "Your LP NFT balance: $NFT_COUNT"
echo ""

if [ "$NFT_COUNT" -eq 0 ]; then
    echo "❌ You don't own any LP NFTs!"
    echo ""
    echo "This means you need to:"
    echo "1. Create a Uniswap V3 LP position first"
    echo "2. Or get an LP NFT transferred to your address"
    echo ""
    echo "To create an LP position:"
    echo "- Use Uniswap V3 interface"
    echo "- Or use cast to mint a position"
    echo ""
    exit 1
fi

echo "🎯 Your actual LP NFTs:"
for i in $(seq 0 $((NFT_COUNT-1))); do
    echo "Getting NFT #$i..."
    TOKEN_ID=$(cast call $POSITION_MANAGER "tokenOfOwnerByIndex(address,uint256)" $YOUR_ADDRESS $i --rpc-url $RPC_URL)
    TOKEN_ID_DEC=$(cast --to-dec $TOKEN_ID)
    echo "  NFT Index #$i: Token ID $TOKEN_ID_DEC"
    
    # Verify ownership
    OWNER=$(cast call $POSITION_MANAGER "ownerOf(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL)
    echo "  Owner: $OWNER"
    
    if [ "$OWNER" = "$YOUR_ADDRESS" ]; then
        echo "  ✅ Confirmed: You own this NFT"
        
        # Get position details to verify it exists
        echo "  📍 Getting position details..."
        POSITION_DATA=$(cast call $POSITION_MANAGER "positions(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
        
        if [ "$POSITION_DATA" != "ERROR" ]; then
            echo "  ✅ Position data exists"
            
            # Parse basic info
            TOKEN0="0x$(echo $POSITION_DATA | cut -c107-146)"
            TOKEN1="0x$(echo $POSITION_DATA | cut -c147-186)"
            FEE_HEX="0x$(echo $POSITION_DATA | cut -c191-194)"
            FEE_DEC=$(cast --to-dec $FEE_HEX)
            LIQUIDITY_HEX="0x$(echo $POSITION_DATA | cut -c323-386)"
            LIQUIDITY_DEC=$(cast --to-dec $LIQUIDITY_HEX)
            
            echo "  Token0: $TOKEN0"
            echo "  Token1: $TOKEN1"
            echo "  Fee: $FEE_DEC"
            echo "  Liquidity: $LIQUIDITY_DEC"
            
            # Try to get USD value from contract
            echo "  💰 Getting USD value..."
            USD_DATA=$(cast call $CONTRACT_ADDRESS "getLPTokenValueUSD(uint256)" $TOKEN_ID_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
            
            if [ "$USD_DATA" != "ERROR" ]; then
                USD_VALUE="0x$(echo $USD_DATA | cut -c131-194)"
                USD_DEC=$(cast --to-dec $USD_VALUE)
                echo "  USD Value: \$$(echo "scale=6; $USD_DEC / 1000000" | bc)"
                
                # Check if can join battle 0
                echo "  🎯 Can join battle 0?"
                CAN_JOIN=$(cast call $CONTRACT_ADDRESS "canJoinBattle(uint256,uint256)" 0 $TOKEN_ID_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
                
                if [ "$CAN_JOIN" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
                    echo "  ✅ YES - This NFT can join battle 0!"
                    echo ""
                    echo "🚀 Use this Token ID: $TOKEN_ID_DEC"
                elif [ "$CAN_JOIN" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
                    echo "  ❌ NO - Value not within 5% tolerance"
                else
                    echo "  ❓ Unknown response: $CAN_JOIN"
                fi
            else
                echo "  ❌ Failed to get USD value"
            fi
        else
            echo "  ❌ Failed to get position data"
        fi
    else
        echo "  ❌ ERROR: NFT not owned by you!"
    fi
    echo ""
done

# Get battle 0 info
echo "⚔️ Battle 0 Information:"
BATTLE_COUNT=$(cast call $CONTRACT_ADDRESS "battleIdCounter()" --rpc-url $RPC_URL)
BATTLE_COUNT_DEC=$(cast --to-dec $BATTLE_COUNT)

if [ "$BATTLE_COUNT_DEC" -gt 0 ]; then
    echo "Battle 0 exists. Getting creator's token ID..."
    BATTLE_DATA=$(cast call $CONTRACT_ADDRESS "battles(uint256)" 0 --rpc-url $RPC_URL)
    CREATOR_TOKEN="0x$(echo $BATTLE_DATA | cut -c67-130)"
    CREATOR_TOKEN_DEC=$(cast --to-dec $CREATOR_TOKEN)
    
    echo "Creator's Token ID: $CREATOR_TOKEN_DEC"
    
    # Get creator's USD value
    CREATOR_USD_DATA=$(cast call $CONTRACT_ADDRESS "getLPTokenValueUSD(uint256)" $CREATOR_TOKEN_DEC --rpc-url $RPC_URL 2>/dev/null || echo "ERROR")
    
    if [ "$CREATOR_USD_DATA" != "ERROR" ]; then
        CREATOR_USD_VALUE="0x$(echo $CREATOR_USD_DATA | cut -c131-194)"
        CREATOR_USD_DEC=$(cast --to-dec $CREATOR_USD_VALUE)
        echo "Creator's USD Value: \$$(echo "scale=6; $CREATOR_USD_DEC / 1000000" | bc)"
        
        # Calculate 5% tolerance range
        TOLERANCE=$(echo "scale=0; $CREATOR_USD_DEC * 0.05" | bc)
        MIN_VALUE=$(echo "scale=0; $CREATOR_USD_DEC - $TOLERANCE" | bc)
        MAX_VALUE=$(echo "scale=0; $CREATOR_USD_DEC + $TOLERANCE" | bc)
        
        echo "Required range (±5%):"
        echo "  Min: \$$(echo "scale=6; $MIN_VALUE / 1000000" | bc)"
        echo "  Max: \$$(echo "scale=6; $MAX_VALUE / 1000000" | bc)"
    else
        echo "Failed to get creator's USD value"
    fi
else
    echo "No battles exist yet"
fi