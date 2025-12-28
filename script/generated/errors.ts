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
    name: 'Dictatorship__InvalidCoreContract',
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
    name: 'Allocation__InsufficientBalance',
    inputs: [
      {
        name: 'available',
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
    name: 'Allocation__ActiveShares',
    inputs: [
      {
        name: 'totalShares',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__AlreadyRegistered',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__UnregisteredSubaccount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__TransferFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__NetValueBelowAcceptable',
    inputs: [
      {
        name: 'netValue',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'acceptable',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__ArrayLengthMismatch',
    inputs: [
      {
        name: 'puppetCount',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'allocationCount',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__PuppetListTooLarge',
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
    name: 'Allocation__TargetNotWhitelisted',
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__InvalidCallType',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__IntentExpired',
    inputs: [
      {
        name: 'deadline',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'currentTime',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__InvalidSignature',
    inputs: [
      {
        name: 'expected',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'recovered',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__InvalidNonce',
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
    name: 'Allocation__InvalidMaxPuppetList',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__InvalidTransferGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__InvalidCallGasLimit',
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
  },
  {
    type: 'error',
    name: 'VenueRegistry__ContractNotWhitelisted',
    inputs: [
      {
        name: 'venue',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Position__VenueNotRegistered',
    inputs: [
      {
        name: 'venueKey',
        internalType: 'bytes32',
        type: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'GmxVenueValidator__InvalidCallData',
    inputs: []
  },
  {
    type: 'error',
    name: 'GmxVenueValidator__TokenMismatch',
    inputs: [
      {
        name: 'expected',
        internalType: 'address',
        type: 'address'
      },
      {
        name: 'actual',
        internalType: 'address',
        type: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'GmxVenueValidator__AmountMismatch',
    inputs: [
      {
        name: 'expected',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'actual',
        internalType: 'uint256',
        type: 'uint256'
      }
    ]
  }
] as const
