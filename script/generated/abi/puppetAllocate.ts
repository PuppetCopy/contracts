// This file is auto-generated from forge-artifacts/Allocate.sol/Allocate.json
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
        internalType: 'struct Allocate.Config',
        components: [
          {
            name: 'position',
            type: 'address',
            internalType: 'contract Position'
          },
          {
            name: 'virtualShareOffset',
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
    name: 'config',
    inputs: [],
    outputs: [
      {
        name: 'position',
        type: 'address',
        internalType: 'contract Position'
      },
      {
        name: 'virtualShareOffset',
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
        internalType: 'struct Allocate.Config',
        components: [
          {
            name: 'position',
            type: 'address',
            internalType: 'contract Position'
          },
          {
            name: 'virtualShareOffset',
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
    name: 'getSharePrice',
    inputs: [
      {
        name: '_key',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_totalAssets',
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
    name: 'getUserNpv',
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
        name: '_account',
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
    name: 'getUserShares',
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
        name: '_account',
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
    name: 'handleCreateSubaccount',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_signer',
        type: 'address',
        internalType: 'address'
      },
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
      }
    ],
    outputs: [
      {
        name: '_result',
        type: 'tuple',
        internalType: 'struct Allocate.CreateSubaccountResult',
        components: [
          {
            name: 'key',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'sharesOut',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sharePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'totalShares',
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
    name: 'handleMasterDeposit',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'address'
      },
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
        name: '_acceptableNetValue',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '_result',
        type: 'tuple',
        internalType: 'struct Allocate.DepositResult',
        components: [
          {
            name: 'key',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'sharesOut',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sharePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'totalShares',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocation',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positionValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positions',
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
        ]
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'handleWithdraw',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'address'
      },
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
        name: '_shareAmount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_acceptableNetValue',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '_result',
        type: 'tuple',
        internalType: 'struct Allocate.WithdrawResult',
        components: [
          {
            name: 'key',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'amountOut',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sharePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'totalShares',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'shareBalance',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocation',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positionValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positions',
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
        ]
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'isSubaccountRegistered',
    inputs: [
      {
        name: '_key',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'masterSubaccountMap',
    inputs: [
      {
        name: 'matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IERC7579Account'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'prepareAllocate',
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
        name: '_acceptableNetValue',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '_result',
        type: 'tuple',
        internalType: 'struct Allocate.AllocateResult',
        components: [
          {
            name: 'key',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'sharePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocation',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positionValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'netValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positions',
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
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'prepareOrder',
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
        name: '_acceptableNetValue',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_target',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_result',
        type: 'tuple',
        internalType: 'struct Allocate.OrderResult',
        components: [
          {
            name: 'key',
            type: 'bytes32',
            internalType: 'bytes32'
          },
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
            name: 'allocation',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positionValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'netValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'positions',
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
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'recordAllocation',
    inputs: [
      {
        name: '_key',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_puppet',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_sharePrice',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'sessionSignerMap',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'signer',
        type: 'address',
        internalType: 'address'
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
    name: 'shareBalanceMap',
    inputs: [
      {
        name: 'matchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'account',
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
    name: 'subaccountCollateralMap',
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
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'subaccountOwnerMap',
    inputs: [
      {
        name: 'subaccount',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'owner',
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
    name: 'totalSharesMap',
    inputs: [
      {
        name: 'matchingKey',
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
    type: 'error',
    name: 'Allocate__AlreadyRegistered',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocate__InsufficientAllocation',
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
    name: 'Allocate__InsufficientBalance',
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
    name: 'Allocate__InvalidPosition',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__NetValueBelowAcceptable',
    inputs: [
      {
        name: 'netValue',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'acceptable',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__TargetNotWhitelisted',
    inputs: [
      {
        name: 'target',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__UnregisteredSubaccount',
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
