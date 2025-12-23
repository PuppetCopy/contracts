// This file is auto-generated from forge-artifacts/Allocation.sol/Allocation.json
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
        internalType: 'struct Allocation.Config',
        components: [
          {
            name: 'maxPuppetList',
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
    name: 'allocate',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_subscribe',
        type: 'address',
        internalType: 'contract Subscribe'
      },
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_trader',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_traderAllocation',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'allocationBalance',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
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
    name: 'config',
    inputs: [],
    outputs: [
      {
        name: 'maxPuppetList',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'cumulativeSettlementPerUtilization',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'currentEpoch',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'epochRemaining',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'epoch',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'getAvailableAllocation',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
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
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct Allocation.Config',
        components: [
          {
            name: 'maxPuppetList',
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
    name: 'getSubaccountTokenList',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address[]',
        internalType: 'contract IERC20[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getUserUtilization',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
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
    name: 'initializeTraderActivityThrottle',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_puppet',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'lastActivityThrottleMap',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'puppet',
        type: 'address',
        internalType: 'address'
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
    name: 'pendingSettlement',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
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
    name: 'pendingSettlement',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_utilization',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'realize',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_realized',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'registerSubaccount',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_hook',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'registeredSubaccount',
    inputs: [
      {
        name: 'subaccount',
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
    name: 'settle',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'subaccountMap',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'subaccountRecordedBalance',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'subaccountTraderMap',
    inputs: [
      {
        name: 'subaccount',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'trader',
        type: 'address',
        internalType: 'address'
      }
    ],
    stateMutability: 'view'
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
    name: 'syncSettlement',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'syncUtilization',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_executionCalldata',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'totalAllocation',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'totalUtilization',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'userAllocationSnapshot',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'userEpoch',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'userRemainingCheckpoint',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'userSettlementCheckpoint',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
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
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'utilize',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_utilization',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_executionCalldata',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'withdraw',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_user',
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
    type: 'error',
    name: 'Allocation__InsufficientAllocation',
    inputs: [
      {
        name: 'available',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'required',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__InsufficientTraderBalance',
    inputs: [
      {
        name: 'available',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'required',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__NoUtilization',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__PuppetListTooLarge',
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
    name: 'Allocation__UnregisteredSubaccount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__UtilizationNotSettled',
    inputs: [
      {
        name: 'utilization',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__ZeroAllocation',
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
  }
] as const
