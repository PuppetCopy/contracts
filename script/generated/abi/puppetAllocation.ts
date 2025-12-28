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
          },
          {
            name: 'transferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'callGasLimit',
            type: 'uint256',
            internalType: 'uint256'
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
    name: 'CALL_INTENT_TYPEHASH',
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
        name: 'maxPuppetList',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'transferGasLimit',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'callGasLimit',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'createSubaccount',
    inputs: [
      {
        name: '_user',
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
        internalType: 'address'
      },
      {
        name: '_token',
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
        internalType: 'struct Allocation.CallIntent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Allocation.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
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
        internalType: 'address[]'
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
        internalType: 'struct Allocation.CallIntent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Allocation.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
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
        internalType: 'struct Allocation.CallIntent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Allocation.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
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
        internalType: 'struct Allocation.CallIntent',
        components: [
          {
            name: 'intentType',
            type: 'uint8',
            internalType: 'enum Allocation.IntentType'
          },
          {
            name: 'account',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'subaccount',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'token',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'amount',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
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
        internalType: 'struct Allocation.Config',
        components: [
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'transferGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'callGasLimit',
            type: 'uint256',
            internalType: 'uint256'
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
    name: 'getPositionKeyList',
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
        type: 'bytes32[]',
        internalType: 'bytes32[]'
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
        internalType: 'address'
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
        internalType: 'address'
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
    name: 'isInitialized',
    inputs: [
      {
        name: '_smartAccount',
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
    name: 'masterSubaccountMap',
    inputs: [
      {
        name: '',
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
    name: 'nonces',
    inputs: [
      {
        name: '',
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
    name: 'npvReaderMap',
    inputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract INpvReader'
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
    name: 'positionKeyList',
    inputs: [
      {
        name: '',
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
    name: 'positionTargetMap',
    inputs: [
      {
        name: '',
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
    name: 'sessionSigner',
    inputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address'
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
    name: 'setNpvReader',
    inputs: [
      {
        name: '_target',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_reader',
        type: 'address',
        internalType: 'contract INpvReader'
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
    name: 'subaccountCollateral',
    inputs: [
      {
        name: '',
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
    name: 'totalShares',
    inputs: [
      {
        name: '',
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
    name: 'userShares',
    inputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '',
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
    type: 'event',
    name: 'EIP712DomainChanged',
    inputs: [],
    anonymous: false
  },
  {
    type: 'error',
    name: 'Allocation__ActiveShares',
    inputs: [
      {
        name: 'totalShares',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'Allocation__ArrayLengthMismatch',
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
    name: 'Allocation__InsufficientBalance',
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
    name: 'Allocation__IntentExpired',
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
    name: 'Allocation__InvalidCallGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__InvalidCallType',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__InvalidMaxPuppetList',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__InvalidNonce',
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
    name: 'Allocation__InvalidSignature',
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
    name: 'Allocation__InvalidTransferGasLimit',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__PriceTooHigh',
    inputs: [
      {
        name: 'sharePrice',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxAcceptable',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__PriceTooLow',
    inputs: [
      {
        name: 'sharePrice',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'minAcceptable',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
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
    name: 'Allocation__TargetNotWhitelisted',
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
    name: 'Allocation__TransferFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__UnregisteredSubaccount',
    inputs: []
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
