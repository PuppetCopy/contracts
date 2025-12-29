// This file is auto-generated from forge-artifacts/Position.sol/Position.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        type: 'address',
        internalType: 'contract IAuthority'
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
    name: 'getNetValue',
    inputs: [
      {
        name: '_token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_subaccount',
        type: 'address',
        internalType: 'contract IERC7579Account'
      },
      {
        name: '_name',
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
    name: 'getPositionKeyList',
    inputs: [
      {
        name: '_matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bytes32[]',
        internalType: 'bytes32[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getValidator',
    inputs: [
      {
        name: '_venueKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IVenueValidator'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getVenue',
    inputs: [
      {
        name: '_entrypoint',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_venue',
        type: 'tuple',
        internalType: 'struct Position.Venue',
        components: [
          {
            name: 'venueKey',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'validator',
            type: 'address',
            internalType: 'contract IVenueValidator'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'positionKeyListMap',
    inputs: [
      {
        name: 'matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'positionVenueMap',
    inputs: [
      {
        name: 'positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: 'venueKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'validator',
        type: 'address',
        internalType: 'contract IVenueValidator'
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
    name: 'setVenue',
    inputs: [
      {
        name: '_venueKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_validator',
        type: 'address',
        internalType: 'contract IVenueValidator'
      },
      {
        name: '_entrypoints',
        type: 'address[]',
        internalType: 'address[]'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'snapshotNetValue',
    inputs: [
      {
        name: '_matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '_positionValue',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_positions',
        type: 'tuple[]',
        internalType: 'struct Position.PositionInfo[]',
        components: [
          {
            name: 'venue',
            type: 'tuple',
            internalType: 'struct Position.Venue',
            components: [
              {
                name: 'venueKey',
                type: 'bytes32',
                internalType: 'bytes32'
              },
              {
                name: 'validator',
                type: 'address',
                internalType: 'contract IVenueValidator'
              }
            ]
          },
          {
            name: 'value',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positionKey',
            type: 'bytes32',
            internalType: 'bytes32'
          }
        ]
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
    name: 'updatePosition',
    inputs: [
      {
        name: '_matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_venue',
        type: 'tuple',
        internalType: 'struct Position.Venue',
        components: [
          {
            name: 'venueKey',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'validator',
            type: 'address',
            internalType: 'contract IVenueValidator'
          }
        ]
      },
      {
        name: '_netValue',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'validateCall',
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
        name: '_target',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_callData',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [
      {
        name: '_venue',
        type: 'tuple',
        internalType: 'struct Position.Venue',
        components: [
          {
            name: 'venueKey',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'validator',
            type: 'address',
            internalType: 'contract IVenueValidator'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'venueKeyMap',
    inputs: [
      {
        name: 'entrypoint',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'venueValidatorMap',
    inputs: [
      {
        name: 'venueKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IVenueValidator'
      }
    ],
    stateMutability: 'view'
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
    name: 'Position__VenueNotRegistered',
    inputs: [
      {
        name: 'venueKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'ReentrancyGuardReentrantCall',
    inputs: []
  }
] as const
