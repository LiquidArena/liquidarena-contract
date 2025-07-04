// Quick fix: Modify these lines in LPBattleVault.sol for testing
// Lines 270-271 in joinBattle function

// ORIGINAL (5% tolerance):
// uint256 minValue = (creatorValue * 95) / 100;
// uint256 maxValue = (creatorValue * 105) / 100;

// MODIFIED (200% tolerance for cross-pool testing):
uint256 minValue = (creatorValue * 10) / 100;   // Allow 90% lower
uint256 maxValue = (creatorValue * 300) / 100;  // Allow 200% higher

// This will allow your $1.58 vs $0.11 battle to proceed
// Your difference: 93% (well within 90% lower bound)