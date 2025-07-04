// LiquidArena Protocol - Contract ABIs for Frontend Integration
// Generated from deployed contracts on Monad Testnet

export const RANGE_BATTLE_ADDRESS = '0x78f4f7A63C9a4f2d75749209d6EBf133464cb9e6' as const;
export const FEE_BATTLE_ADDRESS = '0x18d6b03A4A0499077A2dc8c45fFf8DA10aF16f64' as const;

// LPBattleVault ABI (Range Battles)
export const RANGE_BATTLE_ABI = [
  // Core Functions
  {
    "type": "function",
    "name": "createBattle",
    "inputs": [
      {"name": "tokenId", "type": "uint256"},
      {"name": "durations", "type": "uint256"}
    ],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "joinBattle",
    "inputs": [
      {"name": "battleId", "type": "uint256"},
      {"name": "tokenId", "type": "uint256"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "resolveBattle",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  
  // View Functions
  {
    "type": "function",
    "name": "getBattleDetails",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "opponent", "type": "address"},
      {"name": "usdValue", "type": "uint256"},
      {"name": "winner", "type": "address"},
      {"name": "status", "type": "string"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCompleteBattleDetails",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "opponent", "type": "address"},
      {"name": "creatorTokenId", "type": "uint256"},
      {"name": "opponentTokenId", "type": "uint256"},
      {"name": "isResolved", "type": "bool"},
      {"name": "winner", "type": "address"},
      {"name": "startTime", "type": "uint256"},
      {"name": "duration", "type": "uint256"},
      {"name": "valueUSD", "type": "uint256"},
      {"name": "status", "type": "string"},
      {"name": "creatorInRange", "type": "bool"},
      {"name": "opponentInRange", "type": "bool"},
      {"name": "currentTick", "type": "int24"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleStatus",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleUSDValue",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleTokenInfo",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "token0", "type": "address"},
      {"name": "token1", "type": "address"},
      {"name": "fee", "type": "uint24"},
      {"name": "poolName", "type": "string"}
    ],
    "stateMutability": "view"
  },
  
  // Public Variables
  {
    "type": "function",
    "name": "battleIdCounter",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "battles",
    "inputs": [{"name": "", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "isResolved", "type": "bool"},
      {"name": "creatorTickLower", "type": "int24"},
      {"name": "creatorTickUpper", "type": "int24"},
      {"name": "opponentTickLower", "type": "int24"},
      {"name": "opponentTickUpper", "type": "int24"},
      {"name": "opponent", "type": "address"},
      {"name": "winner", "type": "address"},
      {"name": "creatorTokenId", "type": "uint256"},
      {"name": "opponentTokenId", "type": "uint256"},
      {"name": "startTime", "type": "uint256"},
      {"name": "duration", "type": "uint256"},
      {"name": "totalValueUSD", "type": "uint256"}
    ],
    "stateMutability": "view"
  },
  
  // Events
  {
    "type": "event",
    "name": "BattleCreated",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "creator", "type": "address", "indexed": true},
      {"name": "creatorTokenId", "type": "uint256", "indexed": false},
      {"name": "duration", "type": "uint256", "indexed": false},
      {"name": "totalValueUSD", "type": "uint256", "indexed": false}
    ]
  },
  {
    "type": "event",
    "name": "BattleJoined",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "opponent", "type": "address", "indexed": true},
      {"name": "opponentTokenId", "type": "uint256", "indexed": false},
      {"name": "startTime", "type": "uint256", "indexed": false}
    ]
  },
  {
    "type": "event",
    "name": "BattleResolved",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "winner", "type": "address", "indexed": true},
      {"name": "resolver", "type": "address", "indexed": true},
      {"name": "resolverReward", "type": "uint256", "indexed": false}
    ]
  },
  
  // Constants
  {
    "type": "function",
    "name": "RESOLVER_REWARD_BPS",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MIN_BATTLE_DURATION",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_BATTLE_DURATION",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LP_VALUE_TOLERANCE_BPS",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  }
] as const;

// LPFeeBattle ABI (Fee Battles)
export const FEE_BATTLE_ABI = [
  // Core Functions
  {
    "type": "function",
    "name": "createBattle",
    "inputs": [
      {"name": "tokenId", "type": "uint256"},
      {"name": "duration", "type": "uint256"}
    ],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "joinBattle",
    "inputs": [
      {"name": "battleId", "type": "uint256"},
      {"name": "tokenId", "type": "uint256"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "resolveBattle",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  
  // View Functions
  {
    "type": "function",
    "name": "getBattleDetails",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "opponent", "type": "address"},
      {"name": "creatorTokenId", "type": "uint256"},
      {"name": "opponentTokenId", "type": "uint256"},
      {"name": "isResolved", "type": "bool"},
      {"name": "winner", "type": "address"},
      {"name": "startTime", "type": "uint256"},
      {"name": "duration", "type": "uint256"},
      {"name": "creatorLPValueUSD", "type": "uint256"},
      {"name": "status", "type": "string"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCurrentFeePerformance",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creatorFeeGrowthUSD", "type": "uint256"},
      {"name": "opponentFeeGrowthUSD", "type": "uint256"},
      {"name": "creatorFeeRate", "type": "uint256"},
      {"name": "opponentFeeRate", "type": "uint256"},
      {"name": "currentLeader", "type": "address"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getDetailedFeePerformance",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creatorStartFees", "type": "uint256"},
      {"name": "opponentStartFees", "type": "uint256"},
      {"name": "creatorCurrentFees", "type": "uint256"},
      {"name": "opponentCurrentFees", "type": "uint256"},
      {"name": "creatorFeeGrowthUSD", "type": "uint256"},
      {"name": "opponentFeeGrowthUSD", "type": "uint256"},
      {"name": "creatorFeeRate", "type": "uint256"},
      {"name": "opponentFeeRate", "type": "uint256"},
      {"name": "currentLeader", "type": "address"},
      {"name": "leadReason", "type": "string"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCompleteBattleDetails",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "opponent", "type": "address"},
      {"name": "creatorTokenId", "type": "uint256"},
      {"name": "opponentTokenId", "type": "uint256"},
      {"name": "isResolved", "type": "bool"},
      {"name": "winner", "type": "address"},
      {"name": "startTime", "type": "uint256"},
      {"name": "duration", "type": "uint256"},
      {"name": "valueUSD", "type": "uint256"},
      {"name": "status", "type": "string"},
      {"name": "creatorFeeGrowthUSD", "type": "uint256"},
      {"name": "opponentFeeGrowthUSD", "type": "uint256"},
      {"name": "creatorFeeRate", "type": "uint256"},
      {"name": "opponentFeeRate", "type": "uint256"},
      {"name": "currentLeader", "type": "address"}
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleStatus",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleUSDValue",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBattleTokenInfo",
    "inputs": [{"name": "battleId", "type": "uint256"}],
    "outputs": [
      {"name": "token0", "type": "address"},
      {"name": "token1", "type": "address"},
      {"name": "fee", "type": "uint24"},
      {"name": "poolName", "type": "string"}
    ],
    "stateMutability": "view"
  },

  // Public Variables
  {
    "type": "function",
    "name": "battleIdCounter",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "battles",
    "inputs": [{"name": "", "type": "uint256"}],
    "outputs": [
      {"name": "creator", "type": "address"},
      {"name": "creatorTokenId", "type": "uint256"},
      {"name": "opponentTokenId", "type": "uint256"},
      {"name": "opponent", "type": "address"},
      {"name": "isResolved", "type": "bool"},
      {"name": "winner", "type": "address"},
      {"name": "startTime", "type": "uint256"},
      {"name": "duration", "type": "uint256"},
      {"name": "creatorStartFee0", "type": "uint256"},
      {"name": "creatorStartFee1", "type": "uint256"},
      {"name": "opponentStartFee0", "type": "uint256"},
      {"name": "opponentStartFee1", "type": "uint256"},
      {"name": "creatorLPValue", "type": "uint256"}
    ],
    "stateMutability": "view"
  },

  // Events
  {
    "type": "event",
    "name": "BattleCreated",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "creator", "type": "address", "indexed": true},
      {"name": "creatorTokenId", "type": "uint256", "indexed": false}
    ]
  },
  {
    "type": "event",
    "name": "BattleJoined",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "opponent", "type": "address", "indexed": true},
      {"name": "opponentTokenId", "type": "uint256", "indexed": false}
    ]
  },
  {
    "type": "event",
    "name": "BattleResolved",
    "inputs": [
      {"name": "battleId", "type": "uint256", "indexed": true},
      {"name": "winner", "type": "address", "indexed": true}
    ]
  },

  // Constants
  {
    "type": "function",
    "name": "RESOLVER_REWARD_BPS",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MIN_BATTLE_DURATION",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view"
  }
] as const;

// Custom Error Types
export const CONTRACT_ERRORS = {
  NotOwner: 'NotOwner()',
  NotLPOwner: 'NotLPOwner()',
  BattleAlreadyJoined: 'BattleAlreadyJoined()',
  BattleAlreadyResolved: 'BattleAlreadyResolved()',
  BattleNotEnded: 'BattleNotEnded()',
  BattleNotStarted: 'BattleNotStarted()',
  LPValueNotWithinTolerance: 'LPValueNotWithinTolerance()',
  BattleDoesNotExist: 'BattleDoesNotExist()',
  BattleDurationTooLong: 'BattleDurationTooLong(uint256,uint256)',
  PriceFeedNotSet: 'PriceFeedNotSet()',
  StalePrice: 'StalePrice()',
} as const;

// Type definitions for TypeScript
export type BattleStatus = 'queued' | 'onGoing' | 'readyToResolve' | 'ended';

export interface RangeBattleDetails {
  creator: string;
  opponent: string;
  usdValue: bigint;
  winner: string;
  status: BattleStatus;
}

export interface CompleteBattleDetails {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  valueUSD: bigint;
  status: BattleStatus;
  creatorInRange: boolean;
  opponentInRange: boolean;
  currentTick: number;
}

export interface FeeBattleDetails {
  creator: string;
  opponent: string;
  creatorTokenId: bigint;
  opponentTokenId: bigint;
  isResolved: boolean;
  winner: string;
  startTime: bigint;
  duration: bigint;
  creatorLPValueUSD: bigint;
  status: BattleStatus;
}

export interface FeePerformance {
  creatorFeeGrowthUSD: bigint;
  opponentFeeGrowthUSD: bigint;
  creatorFeeRate: bigint;
  opponentFeeRate: bigint;
  currentLeader: string;
}

export interface DetailedFeePerformance {
  creatorStartFees: bigint;
  opponentStartFees: bigint;
  creatorCurrentFees: bigint;
  opponentCurrentFees: bigint;
  creatorFeeGrowthUSD: bigint;
  opponentFeeGrowthUSD: bigint;
  creatorFeeRate: bigint;
  opponentFeeRate: bigint;
  currentLeader: string;
  leadReason: string;
}

export interface TokenInfo {
  token0: string;
  token1: string;
  fee: number;
  poolName: string;
}
