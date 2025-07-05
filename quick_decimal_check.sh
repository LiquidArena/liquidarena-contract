#!/bin/bash

# Quick Decimal Check Script
# Fast verification of decimal handling without full test suite

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Quick Decimal Check${NC}\n"

# Check if foundry.toml exists
if [ ! -f "foundry.toml" ]; then
    echo -e "${RED}Error: Run this script from liquidarena-contract directory${NC}"
    exit 1
fi

# Quick compile check
echo -e "${BLUE}📦 Compiling contracts...${NC}"
if forge build --quiet; then
    echo -e "${GREEN}✅ Compilation successful${NC}"
else
    echo -e "${RED}❌ Compilation failed${NC}"
    exit 1
fi

# Run only the most critical decimal tests
echo -e "\n${BLUE}🧪 Running critical decimal tests...${NC}"

critical_tests=(
    "testStablecoinDecimals"
    "testCrossContractConsistency"
    "testEdgeCases"
)

all_passed=true

for test in "${critical_tests[@]}"; do
    echo -n "  Testing $test... "
    if forge test --match-test "$test" --quiet > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
        all_passed=false
    fi
done

echo ""

if [ "$all_passed" = true ]; then
    echo -e "${GREEN}🎉 All critical decimal tests passed!${NC}"
    echo -e "${BLUE}💡 Run './test_decimals.sh' for comprehensive testing${NC}"
else
    echo -e "${RED}⚠️  Some tests failed. Run './test_decimals.sh' for details${NC}"
    exit 1
fi
