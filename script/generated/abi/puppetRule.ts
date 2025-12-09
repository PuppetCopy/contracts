// This file is auto-generated from forge-artifacts/Rule.sol/Rule.json
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
        internalType: 'struct Rule.Config',
        components: [
          {
            name: 'minExpiryDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAllowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxAllowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minActivityThrottle',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxActivityThrottle',
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
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct Rule.Config',
        components: [
          {
            name: 'minExpiryDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAllowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxAllowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minActivityThrottle',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxActivityThrottle',
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
    name: 'getRuleList',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      }
    ],
    outputs: [
      {
        name: '_ruleList',
        type: 'tuple[]',
        internalType: 'struct Rule.RuleParams[]',
        components: [
          {
            name: 'allowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'throttleActivity',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'expiry',
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
    name: 'matchingRuleMap',
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
        name: 'allowanceRate',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'throttleActivity',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'expiry',
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
    name: 'setRule',
    inputs: [
      {
        name: 'mirror',
        type: 'address',
        internalType: 'contract Mirror'
      },
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_user',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_trader',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_ruleParams',
        type: 'tuple',
        internalType: 'struct Rule.RuleParams',
        components: [
          {
            name: 'allowanceRate',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'throttleActivity',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'expiry',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      }
    ],
    outputs: [],
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
    name: 'Rule__InvalidActivityThrottle',
    inputs: [
      {
        name: 'minAllocationActivity',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxAllocationActivity',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Rule__InvalidAllowanceRate',
    inputs: [
      {
        name: 'min',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'max',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Rule__InvalidExpiryDuration',
    inputs: [
      {
        name: 'minExpiryDuration',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  }
] as const
