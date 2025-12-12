// This file is auto-generated from forge-artifacts/Settle.sol/Settle.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        type: 'address',
        internalType: 'contract IAuthority'
      },
      {
        name: '_config',
        type: 'tuple',
        internalType: 'struct Settle.Config',
        components: [
          {
            name: 'transferOutGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'platformSettleFeeFactor',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchMakerFeeToSettleRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationAccountTransferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'authority',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IAuthority'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'canCall',
    inputs: [
      {
        name: 'signatureHash',
        type: 'bytes4',
        internalType: 'bytes4'
      },
      {
        name: 'user',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bool',
        internalType: 'bool'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'collectAllocationAccountDust',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_allocationAccount',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_dustToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '_dustAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'collectPlatformFees',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct Settle.Config',
        components: [
          {
            name: 'transferOutGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'platformSettleFeeFactor',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchMakerFeeToSettleRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationAccountTransferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'platformFeeMap',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    outputs: [
      {
        name: 'accumulatedFees',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'setConfig',
    inputs: [
      {
        name: '_data',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setPermission',
    inputs: [
      {
        name: 'functionSig',
        type: 'bytes4',
        internalType: 'bytes4'
      },
      {
        name: 'user',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'isEnabled',
        type: 'bool',
        internalType: 'bool'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setTokenDustThresholdList',
    inputs: [
      {
        name: '_tokenDustThresholdList',
        type: 'address[]',
        internalType: 'contract IERC20[]'
      },
      {
        name: '_tokenDustThresholdCapList',
        type: 'uint256[]',
        internalType: 'uint256[]'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'settle',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_mirror',
        type: 'address',
        internalType: 'contract Mirror'
      },
      {
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Settle.CallSettle',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'distributionToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'matchMakerFeeReceiver',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'matchMakerExecutionFee',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      }
    ],
    outputs: [
      {
        name: '_distributedAmount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_platformFeeAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'supportsInterface',
    inputs: [
      {
        name: 'interfaceId',
        type: 'bytes4',
        internalType: 'bytes4'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bool',
        internalType: 'bool'
      }
    ],
    stateMutability: 'pure'
  },
  {
    type: 'function',
    name: 'tokenDustThresholdAmountMap',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'tokenDustThresholdList',
    inputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListEmpty',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__CallerNotAuthority',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__Unauthorized',
    inputs: []
  },
  {
    type: 'error',
    name: 'ReentrancyGuardReentrantCall',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__AmountExceedsDustThreshold',
    inputs: [
      {
        name: 'amount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'threshold',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__DustThresholdNotSet',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__InvalidAllocation',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
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
    name: 'Settle__InvalidReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'Settle__MatchMakerFeeExceedsSettledAmount',
    inputs: [
      {
        name: 'matchMakerFee',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'settledAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__PuppetListExceedsMaximum',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maximum',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Settle__PuppetListMismatch',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  }
] as const
