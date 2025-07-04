#!/bin/bash

# LiquidArena Monad Testnet Deployment and Verification Script
# This script deploys and verifies LiquidArena contracts on Monad Testnet

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHAIN_ID=10143
VERIFIER_URL="https://sourcify-api-monad.blockvision.org"
DEPLOYMENT_FILE="deployments/monad-testnet.json"

echo -e "${BLUE}🚀 LiquidArena Monad Testnet Deployment Script${NC}"
echo "=============================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please create a .env file with your PRIVATE_KEY"
    echo "Example: PRIVATE_KEY=0x..."
    exit 1
fi

# Check if PRIVATE_KEY is set
if ! grep -q "PRIVATE_KEY" .env; then
    echo -e "${RED}❌ Error: PRIVATE_KEY not found in .env file${NC}"
    echo "Please add your private key to .env file"
    echo "Example: PRIVATE_KEY=0x..."
    exit 1
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

echo -e "${YELLOW}📋 Pre-deployment Checks${NC}"
echo "✅ Environment file found"
echo "✅ Private key configured"
echo "✅ Deployments directory ready"
echo ""

# Step 1: Deploy contracts
echo -e "${BLUE}🔨 Step 1: Deploying Contracts${NC}"
echo "Network: Monad Testnet (Chain ID: $CHAIN_ID)"
echo ""

forge script script/DeployImprovedLiquidArena.s.sol:DeployImprovedLiquidArena \
    --rpc-url https://testnet-rpc.monad.xyz \
    --broadcast \
    --verify \
    --slow

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    exit 1
fi

# Check if deployment file was created
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo -e "${RED}❌ Error: Deployment file not created${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📄 Reading Deployment Addresses${NC}"

# Extract addresses from deployment file
RANGE_VAULT_ADDRESS=$(cat $DEPLOYMENT_FILE | grep -o '"LPBattleVault":[^}]*"address":[^"]*"[^"]*"' | grep -o '"address":[^"]*"[^"]*"' | cut -d'"' -f4)
FEE_BATTLE_ADDRESS=$(cat $DEPLOYMENT_FILE | grep -o '"LPFeeBattle":[^}]*"address":[^"]*"[^"]*"' | grep -o '"address":[^"]*"[^"]*"' | cut -d'"' -f4)

echo "LPBattleVault: $RANGE_VAULT_ADDRESS"
echo "LPFeeBattle: $FEE_BATTLE_ADDRESS"
echo ""

# Step 2: Verify contracts
echo -e "${BLUE}🔍 Step 2: Verifying Contracts${NC}"
echo "Verifier: Sourcify"
echo "URL: $VERIFIER_URL"
echo ""

# Verify LPBattleVault
echo -e "${YELLOW}Verifying LPBattleVault...${NC}"
forge verify-contract \
    $RANGE_VAULT_ADDRESS \
    src/LPBattleVault.sol:LPBattleVault \
    --chain $CHAIN_ID \
    --verifier sourcify \
    --verifier-url $VERIFIER_URL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ LPBattleVault verification submitted${NC}"
else
    echo -e "${YELLOW}⚠️  LPBattleVault verification may have failed (this is sometimes normal)${NC}"
fi

echo ""

# Verify LPFeeBattle
echo -e "${YELLOW}Verifying LPFeeBattle...${NC}"
forge verify-contract \
    $FEE_BATTLE_ADDRESS \
    src/LPFeeBattle.sol:LPFeeBattle \
    --chain $CHAIN_ID \
    --verifier sourcify \
    --verifier-url $VERIFIER_URL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ LPFeeBattle verification submitted${NC}"
else
    echo -e "${YELLOW}⚠️  LPFeeBattle verification may have failed (this is sometimes normal)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Deployment and Verification Complete!${NC}"
echo "=============================================="
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "Network: Monad Testnet"
echo "Chain ID: $CHAIN_ID"
echo "LPBattleVault: $RANGE_VAULT_ADDRESS"
echo "LPFeeBattle: $FEE_BATTLE_ADDRESS"
echo ""
echo -e "${BLUE}🔗 Useful Links:${NC}"
echo "Sourcify Verification: $VERIFIER_URL"
echo "Deployment Details: $DEPLOYMENT_FILE"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Check verification status at: $VERIFIER_URL"
echo "2. Update your frontend with the new contract addresses"
echo "3. Test the contracts on Monad Testnet"
echo ""
echo -e "${GREEN}🚀 Your LiquidArena protocol is now live on Monad Testnet!${NC}"
