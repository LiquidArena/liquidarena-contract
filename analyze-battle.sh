#!/bin/bash

# Analyze ongoing battle from contract 0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6

echo "🎮 BATTLE ANALYZER"
echo "=================="
echo "Analyzing ongoing battles in contract 0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6"
echo ""

# Contract addresses
OLD_VAULT_CONTRACT="0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6"
NEW_VAULT_CONTRACT="0xDAC45c475b8446810ED89281773763c628c2e103"
RPC_URL="https://testnet-rpc.monad.xyz"

# Function to decode battle data
decode_battle() {
    local battle_id=$1
    local battle_data=$2
    
    python3 << EOF
try:
    data = "$battle_data"
    chunks = [data[i:i+64] for i in range(2, len(data), 64)]
    
    if len(chunks) >= 13:
        creator = '0x' + chunks[0][24:]
        is_resolved = int(chunks[1], 16) == 1
        creator_tick_lower = int(chunks[2], 16)
        creator_tick_upper = int(chunks[3], 16)
        opponent_tick_lower = int(chunks[4], 16)
        opponent_tick_upper = int(chunks[5], 16)
        opponent = '0x' + chunks[6][24:]
        creator_value = int(chunks[7], 16)
        creator_token_id = int(chunks[8], 16)
        opponent_token_id = int(chunks[9], 16)
        start_time = int(chunks[10], 16)
        duration = int(chunks[11], 16)
        tolerance = int(chunks[12], 16)
        
        # Convert signed ticks
        if creator_tick_lower > 2**255:
            creator_tick_lower = creator_tick_lower - 2**256
        if creator_tick_upper > 2**255:
            creator_tick_upper = creator_tick_upper - 2**256
        if opponent_tick_lower > 2**255:
            opponent_tick_lower = opponent_tick_lower - 2**256
        if opponent_tick_upper > 2**255:
            opponent_tick_upper = opponent_tick_upper - 2**256
        
        print(f"⚔️  BATTLE $1 DETAILS:")
        print("=" * 30)
        print(f"Creator: {creator}")
        print(f"Creator Token ID: {creator_token_id}")
        print(f"Creator Tick Range: {creator_tick_lower:,} to {creator_tick_upper:,}")
        print(f"Creator Value: {creator_value / 1e18:.6f} USD")
        print()
        print(f"Opponent: {opponent}")
        print(f"Opponent Token ID: {opponent_token_id}")
        print(f"Opponent Tick Range: {opponent_tick_lower:,} to {opponent_tick_upper:,}")
        print()
        print(f"Battle Status: {'Resolved' if is_resolved else 'Active'}")
        print(f"Start Time: {start_time}")
        print(f"Duration: {duration} seconds")
        print(f"Tolerance: {tolerance / 100:.2f}%")
        print()
        
        # Store token IDs for value checking
        global creator_token, opponent_token
        creator_token = creator_token_id
        opponent_token = opponent_token_id
        
except Exception as e:
    print(f"❌ Error decoding battle: {e}")
EOF
}

# Function to get token value from new contract
get_token_value() {
    local token_id=$1
    echo "💰 Getting current USD value for token $token_id from new contract..."
    
    local usd_result=$(cast call $NEW_VAULT_CONTRACT "getLPTokenValueUSD(uint256)" $token_id --rpc-url $RPC_URL 2>&1)
    
    if [[ $usd_result == *"error"* ]]; then
        echo "❌ Error getting USD value: $usd_result"
        return 1
    else
        # Decode USD value
        python3 << EOF
try:
    data = "$usd_result"
    chunks = [data[i:i+64] for i in range(2, len(data), 64)]
    
    if len(chunks) >= 3:
        amount0 = int(chunks[0], 16)
        amount1 = int(chunks[1], 16) 
        usd_value = int(chunks[2], 16)
        
        print(f"💵 Token $token_id Value: \${usd_value / 1e18:.6f}")
        print(usd_value / 1e18)
        
    else:
        print("❌ Invalid USD value format")
        
except Exception as e:
    print(f"❌ Error decoding USD value: {e}")
EOF
    fi
}

echo "🔍 Checking battles..."

# Check battles 1-5 to find active ones
for battle_id in {1..5}; do
    echo "Checking battle $battle_id..."
    
    battle_data=$(cast call $OLD_VAULT_CONTRACT "battles(uint256)" $battle_id --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$battle_data" != "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" ]; then
        echo ""
        echo "🎯 FOUND BATTLE $battle_id"
        decode_battle $battle_id "$battle_data"
        
        # Get current values from new contract
        echo "📊 CURRENT TOKEN VALUES (from new contract):"
        echo "============================================="
        
        # Extract token IDs from the decoded data and get their current values
        creator_token=$(python3 -c "
data = '$battle_data'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]
if len(chunks) >= 9:
    print(int(chunks[8], 16))
")
        
        opponent_token=$(python3 -c "
data = '$battle_data'
chunks = [data[i:i+64] for i in range(2, len(data), 64)]
if len(chunks) >= 10:
    print(int(chunks[9], 16))
")
        
        if [ "$creator_token" != "0" ]; then
            get_token_value $creator_token
        fi
        
        if [ "$opponent_token" != "0" ]; then
            get_token_value $opponent_token
        fi
        
        echo ""
        echo "=========================================="
        echo ""
    fi
done

echo "✅ Battle analysis completed!"