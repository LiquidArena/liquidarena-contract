#!/bin/bash

# Deploy Updated Contract with Relaxed Tolerance for Cross-Pool Testing

echo "🚀 DEPLOYING UPDATED CONTRACT"
echo "============================"
echo "Modified tolerance: 90% lower / 200% higher (instead of 5%)"
echo "This will allow your \$1.58 vs \$0.11 cross-pool battle!"
echo ""

# Compile and deploy
echo "📦 Compiling contract..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

echo "✅ Compilation successful!"
echo ""

echo "🌐 Deploying to Monad testnet..."
DEPLOY_RESULT=$(forge script script/DeployLPBattleVault-Monad.s.sol:DeployLPBattleVault --broadcast --verify --rpc-url https://testnet-rpc.monad.xyz)

echo "Deployment result: $DEPLOY_RESULT"

if [ $? -eq 0 ]; then
    echo "✅ Contract deployed successfully!"
    echo ""
    echo "🔍 Extract new contract address from the deployment output above"
    echo "📝 Update your scripts with the new contract address"
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "1. Update contract address in your scripts"
    echo "2. Create battle with token 67327"
    echo "3. Join with token 67082"
    echo "4. Enjoy your cross-pool battle!"
else
    echo "❌ Deployment failed!"
fi