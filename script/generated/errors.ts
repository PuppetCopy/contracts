// This file is auto-generated from contracts/src/utils/Error.sol
// Do not edit manually.

export const puppetErrorAbi = [
  {
    type: 'error',
    name: 'TransferUtils__TokenTransferError',
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address'
      },
      {
        name: 'receiver',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'TransferUtils__TokenTransferFromError',
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address'
      },
      {
        name: 'from',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'to',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'TransferUtils__EmptyHoldingAddress',
    inputs: []
  },
  {
    type: 'error',
    name: 'TransferUtils__SafeERC20FailedOperation',
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'TransferUtils__InvalidReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'TransferUtils__EmptyTokenTransferGasLimit',
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Dictatorship__ContractNotRegistered',
    inputs: []
  },
  {
    type: 'error',
    name: 'Dictatorship__ContractAlreadyInitialized',
    inputs: []
  },
  {
    type: 'error',
    name: 'Dictatorship__ConfigurationUpdateFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Dictatorship__InvalidTargetAddress',
    inputs: []
  },
  {
    type: 'error',
    name: 'Dictatorship__InvalidCoreContract',
    inputs: []
  },
  {
    type: 'error',
    name: 'TokenRouter__EmptyTokenTranferGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'BankStore__InsufficientBalance',
    inputs: []
  },
  {
    type: 'error',
    name: 'PuppetVoteToken__Unsupported',
    inputs: []
  },
  {
    type: 'error',
    name: 'RewardDistributor__InvalidAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'RewardDistributor__InsufficientRewards',
    inputs: [
      {
        name: 'accured',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'VotingEscrow__ZeroAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'VotingEscrow__ExceedMaxTime',
    inputs: []
  },
  {
    type: 'error',
    name: 'VotingEscrow__ExceedingAccruedAmount',
    inputs: [
      {
        name: 'accured',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Access__CallerNotAuthority',
    inputs: []
  },
  {
    type: 'error',
    name: 'Access__Unauthorized',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__Unauthorized',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__CallerNotAuthority',
    inputs: []
  },
  {
    type: 'error',
    name: 'Subscribe__InvalidAllowanceRate',
    inputs: [
      {
        name: 'min',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'max',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Subscribe__InvalidActivityThrottle',
    inputs: [
      {
        name: 'minAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maxAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Subscribe__InvalidExpiryDuration',
    inputs: [
      {
        name: 'minExpiryDuration',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InvalidAllocation',
    inputs: [
      {
        name: 'allocationAddress',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InvalidCollateralDelta',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidMatchMakerExecutionFeeAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidSizeDelta',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListEmpty',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListTooLarge',
    inputs: [
      {
        name: 'provided',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maximum',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InsufficientGmxExecutionFee',
    inputs: [
      {
        name: 'provided',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'required',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchMakerFeeExceedsCostFactor',
    inputs: [
      {
        name: 'matchMakerFee',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'allocationAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__OrderCreationFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__MatchMakerFeeExceedsAdjustmentRatio',
    inputs: [
      {
        name: 'matchMakerFee',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'allocationAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchMakerFeeExceedsCloseRatio',
    inputs: [
      {
        name: 'matchMakerFee',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'allocationAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchMakerFeeNotFullyCovered',
    inputs: [
      {
        name: 'totalPaid',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'requiredFee',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__RequestPending',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__NoPosition',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PositionAlreadyOpen',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__DecreaseTooLarge',
    inputs: [
      {
        name: 'requested',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'available',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__TraderPositionTooOld',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__InvalidAllocation',
    inputs: [
      {
        name: 'allocationAddress',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__PuppetListMismatch',
    inputs: [
      {
        name: 'provided',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'expected',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__InvalidMatchMakerExecutionFeeAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__InvalidMatchMakerExecutionFeeReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__MatchMakerFeeExceedsSettledAmount',
    inputs: [
      {
        name: 'matchMakerFee',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'settledAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__PuppetListExceedsMaximum',
    inputs: [
      {
        name: 'provided',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maximum',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__InvalidReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__DustThresholdNotSet',
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__NoDustToCollect',
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'account',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__AmountExceedsDustThreshold',
    inputs: [
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'threshold',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Account__NoFundsToTransfer',
    inputs: [
      {
        name: 'allocationAddress',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'token',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Account__InvalidSettledAmount',
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address'
      },
      {
        name: 'recordedAmount',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'settledAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Account__InvalidAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Account__TokenNotAllowed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Account__DepositExceedsLimit',
    inputs: [
      {
        name: 'depositCap',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Account__InsufficientBalance',
    inputs: [
      {
        name: 'actualBalance',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'requiredAmount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Account__ArrayLengthMismatch',
    inputs: []
  },
  {
    type: 'error',
    name: 'Account__InvalidDepositCap',
    inputs: []
  },
  {
    type: 'error',
    name: 'Account__InvalidTokenAddress',
    inputs: []
  },
  {
    type: 'error',
    name: 'Account__AmountExceedsUnaccounted',
    inputs: []
  },
  {
    type: 'error',
    name: 'AllocationAccount__UnauthorizedOperator',
    inputs: []
  },
  {
    type: 'error',
    name: 'AllocationAccount__InsufficientBalance',
    inputs: []
  },
  {
    type: 'error',
    name: 'MatchMakerRouter__FailedRefundExecutionFee',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InsufficientUnlockedBalance',
    inputs: [
      {
        name: 'unlockedBalance',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'FeeMarketplace__ZeroDeposit',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InvalidConfig',
    inputs: []
  }
] as const
