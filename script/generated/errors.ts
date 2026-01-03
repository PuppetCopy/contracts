// This file is auto-generated from contracts/src/utils/Error.sol
// Do not edit manually.

export const puppetErrorAbi = [
  {
    type: "error",
    name: "TransferUtils__TokenTransferError",
    inputs: [
      {
        name: "token",
        internalType: "contract IERC20",
        type: "address"
      },
      {
        name: "receiver",
        internalType: "address",
        type: "address"
      },
      {
        name: "amount",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "TransferUtils__TokenTransferFromError",
    inputs: [
      {
        name: "token",
        internalType: "contract IERC20",
        type: "address"
      },
      {
        name: "from",
        internalType: "address",
        type: "address"
      },
      {
        name: "to",
        internalType: "address",
        type: "address"
      },
      {
        name: "amount",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "TransferUtils__EmptyHoldingAddress",
    inputs: []
  },
  {
    type: "error",
    name: "TransferUtils__SafeERC20FailedOperation",
    inputs: [
      {
        name: "token",
        internalType: "contract IERC20",
        type: "address"
      }
    ]
  },
  {
    type: "error",
    name: "TransferUtils__InvalidReceiver",
    inputs: []
  },
  {
    type: "error",
    name: "TransferUtils__EmptyTokenTransferGasLimit",
    inputs: [
      {
        name: "token",
        internalType: "contract IERC20",
        type: "address"
      }
    ]
  },
  {
    type: "error",
    name: "Dictatorship__ContractNotRegistered",
    inputs: []
  },
  {
    type: "error",
    name: "Dictatorship__ContractAlreadyInitialized",
    inputs: []
  },
  {
    type: "error",
    name: "Dictatorship__ConfigurationUpdateFailed",
    inputs: []
  },
  {
    type: "error",
    name: "Dictatorship__InvalidCoreContract",
    inputs: []
  },
  {
    type: "error",
    name: "BankStore__InsufficientBalance",
    inputs: []
  },
  {
    type: "error",
    name: "PuppetVoteToken__Unsupported",
    inputs: []
  },
  {
    type: "error",
    name: "VotingEscrow__ZeroAmount",
    inputs: []
  },
  {
    type: "error",
    name: "VotingEscrow__ExceedMaxTime",
    inputs: []
  },
  {
    type: "error",
    name: "VotingEscrow__ExceedingAccruedAmount",
    inputs: [
      {
        name: "accured",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Access__CallerNotAuthority",
    inputs: []
  },
  {
    type: "error",
    name: "Access__Unauthorized",
    inputs: []
  },
  {
    type: "error",
    name: "Permission__Unauthorized",
    inputs: []
  },
  {
    type: "error",
    name: "Permission__CallerNotAuthority",
    inputs: []
  },
  {
    type: "error",
    name: "Subscribe__InvalidAllowanceRate",
    inputs: [
      {
        name: "min",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "max",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Subscribe__InvalidActivityThrottle",
    inputs: [
      {
        name: "minAllocationActivity",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "maxAllocationActivity",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Subscribe__InvalidExpiryDuration",
    inputs: [
      {
        name: "minExpiryDuration",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Account__NoFundsToTransfer",
    inputs: [
      {
        name: "allocationAddress",
        internalType: "address",
        type: "address"
      },
      {
        name: "token",
        internalType: "address",
        type: "address"
      }
    ]
  },
  {
    type: "error",
    name: "Account__InvalidSettledAmount",
    inputs: [
      {
        name: "token",
        internalType: "contract IERC20",
        type: "address"
      },
      {
        name: "recordedAmount",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "settledAmount",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Account__InvalidAmount",
    inputs: []
  },
  {
    type: "error",
    name: "Account__TokenNotAllowed",
    inputs: []
  },
  {
    type: "error",
    name: "Account__DepositExceedsLimit",
    inputs: [
      {
        name: "depositCap",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Account__InsufficientBalance",
    inputs: [
      {
        name: "actualBalance",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "requiredAmount",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Account__ArrayLengthMismatch",
    inputs: []
  },
  {
    type: "error",
    name: "Account__InvalidDepositCap",
    inputs: []
  },
  {
    type: "error",
    name: "Account__InvalidTokenAddress",
    inputs: []
  },
  {
    type: "error",
    name: "Account__AmountExceedsUnaccounted",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__InsufficientBalance",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__ActiveShares",
    inputs: [
      {
        name: "totalShares",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__AlreadyRegistered",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__UnregisteredSubaccount",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__TransferFailed",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__ArrayLengthMismatch",
    inputs: [
      {
        name: "puppetCount",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "allocationCount",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__PuppetListTooLarge",
    inputs: [
      {
        name: "provided",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "maximum",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__IntentExpired",
    inputs: [
      {
        name: "deadline",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "currentTime",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__InvalidSignature",
    inputs: [
      {
        name: "expected",
        internalType: "address",
        type: "address"
      },
      {
        name: "recovered",
        internalType: "address",
        type: "address"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__InvalidNonce",
    inputs: [
      {
        name: "expected",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "provided",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__InvalidPosition",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__InvalidMasterHook",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__InvalidMaxPuppetList",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__InvalidGasLimit",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__TokenNotAllowed",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__DepositExceedsCap",
    inputs: [
      {
        name: "amount",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "cap",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__SubaccountFrozen",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__ZeroAmount",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__ZeroShares",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__InsufficientLiquidity",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__AmountMismatch",
    inputs: [
      {
        name: "expected",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "actual",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__InvalidAccountCodeHash",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__MasterHookNotInstalled",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__NetValueBelowMin",
    inputs: [
      {
        name: "netValue",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "acceptableNetValue",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__NetValueAboveMax",
    inputs: [
      {
        name: "netValue",
        internalType: "uint256",
        type: "uint256"
      },
      {
        name: "acceptableNetValue",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "Allocation__NetValueParamsMismatch",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__TokenMismatch",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__ZeroAssets",
    inputs: []
  },
  {
    type: "error",
    name: "Allocation__DisposedWithShares",
    inputs: []
  },
  {
    type: "error",
    name: "FeeMarketplace__InsufficientUnlockedBalance",
    inputs: [
      {
        name: "unlockedBalance",
        internalType: "uint256",
        type: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "FeeMarketplace__ZeroDeposit",
    inputs: []
  },
  {
    type: "error",
    name: "FeeMarketplace__InvalidConfig",
    inputs: []
  },
  {
    type: "error",
    name: "Position__UnknownStage",
    inputs: [
      {
        name: "stage",
        internalType: "bytes32",
        type: "bytes32"
      }
    ]
  },
  {
    type: "error",
    name: "Position__InvalidAction",
    inputs: [
      {
        name: "action",
        internalType: "bytes32",
        type: "bytes32"
      }
    ]
  },
  {
    type: "error",
    name: "Position__DelegateCallBlocked",
    inputs: []
  },
  {
    type: "error",
    name: "Position__InvalidBalanceChange",
    inputs: []
  },
  {
    type: "error",
    name: "Position__PendingOrdersExist",
    inputs: []
  },
  {
    type: "error",
    name: "Position__NotPositionOwner",
    inputs: []
  },
  {
    type: "error",
    name: "Position__OrderStillPending",
    inputs: []
  },
  {
    type: "error",
    name: "Position__InvalidStage",
    inputs: []
  },
  {
    type: "error",
    name: "Position__ArrayLengthMismatch",
    inputs: []
  },
  {
    type: "error",
    name: "Position__BatchOrderNotAllowed",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidCallData",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidCallType",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidTarget",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidOrderType",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidReceiver",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidAction",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidBalanceChange",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__InvalidExecutionSequence",
    inputs: []
  },
  {
    type: "error",
    name: "GmxStage__MissingPriceFeed",
    inputs: [
      {
        name: "token",
        internalType: "address",
        type: "address"
      }
    ]
  },
  {
    type: "error",
    name: "GmxStage__InvalidPrice",
    inputs: [
      {
        name: "token",
        internalType: "address",
        type: "address"
      }
    ]
  }
] as const
