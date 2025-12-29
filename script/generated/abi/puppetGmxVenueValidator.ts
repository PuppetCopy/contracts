// This file is auto-generated from forge-artifacts/GmxVenueValidator.sol/GmxVenueValidator.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_dataStore',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_reader',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_referralStorage',
        type: 'address',
        internalType: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'dataStore',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IGmxDataStore'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getPositionInfo',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'contract IERC7579Account'
      },
      {
        name: '_callData',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [
      {
        name: '_info',
        type: 'tuple',
        internalType: 'struct IVenueValidator.PositionInfo',
        components: [
          {
            name: 'positionKey',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'netValue',
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
    name: 'getPositionNetValue',
    inputs: [
      {
        name: '_positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: 'netValue',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getReferralCode',
    inputs: [
      {
        name: '_callData',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'pure'
  },
  {
    type: 'function',
    name: 'reader',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IGmxReader'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'referralStorage',
    inputs: [],
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
    name: 'validate',
    inputs: [
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'contract IERC7579Account'
      },
      {
        name: '_token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_callData',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'pure'
  },
  {
    type: 'error',
    name: 'ChainlinkPriceFeedNotUpdated',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'timestamp',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'heartbeatDuration',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'EmptyPriceFeedMultiplier',
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
    name: 'GmxVenueValidator__AmountMismatch',
    inputs: [
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'actual',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'GmxVenueValidator__InvalidOrderType',
    inputs: []
  },
  {
    type: 'error',
    name: 'GmxVenueValidator__InvalidReceiver',
    inputs: []
  },
  {
    type: 'error',
    name: 'GmxVenueValidator__TokenMismatch',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'actual',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'InvalidFeedPrice',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'price',
        type: 'int256',
        internalType: 'int256'
      }
    ]
  },
  {
    type: 'error',
    name: 'NoPriceFeed',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'address'
      }
    ]
  }
] as const
