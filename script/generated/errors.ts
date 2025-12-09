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
    name: 'Rule__InvalidAllowanceRate',
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
    name: 'Rule__InvalidActivityThrottle',
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
    name: 'Rule__InvalidExpiryDuration',
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
    name: 'Mirror__TraderPositionNotFound',
    inputs: [
      {
        name: 'trader',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'positionKey',
        internalType: 'bytes32',
        type: 'bytes32'
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
    name: 'Mirror__InvalidCurrentLeverage',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidSequencerExecutionFeeAmount',
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
    name: 'Mirror__ExecutionRequestMissing',
    inputs: [
      {
        name: 'requestKey',
        internalType: 'bytes32',
        type: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InitialMustBeIncrease',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__NoAdjustmentRequired',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PositionNotFound',
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
    name: 'Mirror__PositionNotStalled',
    inputs: [
      {
        name: 'allocationAddress',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'positionKey',
        internalType: 'bytes32',
        type: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__TraderCollateralZero',
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
    name: 'Mirror__DustTransferFailed',
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
    name: 'Mirror__InsufficientAllocationForSequencerFee',
    inputs: [
      {
        name: 'allocation',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'sequencerFee',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__SequencerFeeExceedsCostFactor',
    inputs: [
      {
        name: 'sequencerFee',
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
    name: 'Mirror__SequencerFeeExceedsAdjustmentRatio',
    inputs: [
      {
        name: 'sequencerFee',
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
    name: 'Mirror__PuppetListMismatch',
    inputs: [
      {
        name: 'expected',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'provided',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__SequencerFeeNotFullyCovered',
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
    name: 'Mirror__AllocationNotFullyRedistributed',
    inputs: [
      {
        name: 'remainingAllocation',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
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
    name: 'Settle__InvalidSequencerExecutionFeeAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__InvalidSequencerExecutionFeeReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__SequencerFeeExceedsSettledAmount',
    inputs: [
      {
        name: 'sequencerFee',
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
    name: 'SequencerRouter__FailedRefundExecutionFee',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__NotAuctionableToken',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InsufficientUnlockedBalance',
    inputs: [
      {
        name: 'accruedReward',
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
    name: 'FeeMarketplace__InvalidReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InvalidAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InsufficientDistributionBalance',
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
  }
] as const
