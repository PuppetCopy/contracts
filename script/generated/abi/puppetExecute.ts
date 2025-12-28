// This file is auto-generated from forge-artifacts/Execute.sol/Execute.json
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
        internalType: 'struct Execute.Config',
        components: [
          {
            name: 'allocate',
            type: 'address',
            internalType: 'contract Allocate'
          },
          {
            name: 'callGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'transferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
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
    name: 'INTENT_TYPEHASH',
    inputs: [],
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
        name: 'allocate',
        type: 'address',
        internalType: 'contract Allocate'
      },
      {
        name: 'callGasLimit',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'transferGasLimit',
        type: 'uint256',
        internalType: 'uint256'
      },
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
    name: 'createSubaccount',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Execute.Intent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Execute.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'contract IERC7579Account'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptableNetValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'deadline',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'nonce',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_signature',
        type: 'bytes',
        internalType: 'bytes'
      },
      {
        name: '_signer',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'eip712Domain',
    inputs: [],
    outputs: [
      {
        name: 'fields',
        type: 'bytes1',
        internalType: 'bytes1'
      },
      {
        name: 'name',
        type: 'string',
        internalType: 'string'
      },
      {
        name: 'version',
        type: 'string',
        internalType: 'string'
      },
      {
        name: 'chainId',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'verifyingContract',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'salt',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'extensions',
        type: 'uint256[]',
        internalType: 'uint256[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'executeAllocate',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Execute.Intent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Execute.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'contract IERC7579Account'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptableNetValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'deadline',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'nonce',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_signature',
        type: 'bytes',
        internalType: 'bytes'
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'contract IERC7579Account[]'
      },
      {
        name: '_amountList',
        type: 'uint256[]',
        internalType: 'uint256[]'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'executeMasterDeposit',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Execute.Intent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Execute.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'contract IERC7579Account'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptableNetValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'deadline',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'nonce',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_signature',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'executeOrder',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Execute.Intent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Execute.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'contract IERC7579Account'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptableNetValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'deadline',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'nonce',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_signature',
        type: 'bytes',
        internalType: 'bytes'
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
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'executeWithdraw',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Execute.Intent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Execute.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'contract IERC7579Account'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptableNetValue',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'deadline',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'nonce',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_signature',
        type: 'bytes',
        internalType: 'bytes'
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
        internalType: 'struct Execute.Config',
        components: [
          {
            name: 'allocate',
            type: 'address',
            internalType: 'contract Allocate'
          },
          {
            name: 'callGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'transferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
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
    name: 'isInitialized',
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
        type: 'bool',
        internalType: 'bool'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'isModuleType',
    inputs: [
      {
        name: '_moduleTypeId',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'nonceMap',
    inputs: [
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
    name: 'onInstall',
    inputs: [
      {
        name: '',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'onUninstall',
    inputs: [
      {
        name: '',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
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
    type: 'event',
    name: 'EIP712DomainChanged',
    inputs: [],
    anonymous: false
  },
  {
    type: 'error',
    name: 'ECDSAInvalidSignature',
    inputs: []
  },
  {
    type: 'error',
    name: 'ECDSAInvalidSignatureLength',
    inputs: [
      {
        name: 'length',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'ECDSAInvalidSignatureS',
    inputs: [
      {
        name: 's',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__ArrayLengthMismatch',
    inputs: [
      {
        name: 'puppetCount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'allocationCount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__IntentExpired',
    inputs: [
      {
        name: 'deadline',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'currentTime',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__InvalidAllocate',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__InvalidCallGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__InvalidIntentType',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__InvalidMaxPuppetList',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__InvalidNonce',
    inputs: [
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__InvalidSignature',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'recovered',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Execute__InvalidTransferGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__ModuleNotInstalled',
    inputs: []
  },
  {
    type: 'error',
    name: 'Execute__PuppetListTooLarge',
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
    name: 'Execute__TransferFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'InvalidShortString',
    inputs: []
  },
  {
    type: 'error',
    name: 'ModuleAlreadyInitialized',
    inputs: [
      {
        name: 'smartAccount',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'NotInitialized',
    inputs: [
      {
        name: 'smartAccount',
        type: 'address',
        internalType: 'address'
      }
    ]
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
    name: 'StringTooLong',
    inputs: [
      {
        name: 'str',
        type: 'string',
        internalType: 'string'
      }
    ]
  }
] as const
