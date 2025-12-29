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
            name: 'position',
            type: 'address',
            internalType: 'contract Position'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'gasLimit',
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
        name: 'position',
        type: 'address',
        internalType: 'contract Position'
      },
      {
        name: 'maxPuppetList',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'gasLimit',
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
    name: 'createMasterSubaccount',
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
      },
      {
        name: '_subaccountName',
        type: 'bytes32',
        internalType: 'bytes32'
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
            name: 'subaccountName',
            type: 'bytes32',
            internalType: 'bytes32'
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
    name: 'executeOrder',
    inputs: [
      {
        name: '_intent',
        type: 'tuple',
        internalType: 'struct Allocation.CallIntent',
        components: [
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
            name: 'subaccountName',
            type: 'bytes32',
            internalType: 'bytes32'
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
            name: 'subaccountName',
            type: 'bytes32',
            internalType: 'bytes32'
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
    name: 'frozenMap',
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
        internalType: 'struct Allocation.Config',
        components: [
          {
            name: 'position',
            type: 'address',
            internalType: 'contract Position'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'gasLimit',
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
        name: '_name',
        type: 'bytes32',
        internalType: 'bytes32'
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
    name: 'isInitialized',
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
        type: 'bool',
        internalType: 'bool'
      }
    ],
    stateMutability: 'pure'
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
    name: 'setSessionSigner',
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
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setTokenCap',
    inputs: [
      {
        name: '_token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_cap',
        type: 'uint256',
        internalType: 'uint256'
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
    name: 'tokenCapMap',
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
    type: 'event',
    name: 'EIP712DomainChanged',
    inputs: [],
    anonymous: false
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
    name: 'Allocation__DepositExceedsCap',
    inputs: [
      {
        name: 'amount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'cap',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Allocation__InsufficientBalance',
    inputs: []
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
    name: 'Allocation__InvalidGasLimit',
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
    name: 'Allocation__InvalidPosition',
    inputs: []
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
    name: 'Allocation__SubaccountFrozen',
    inputs: []
  },
  {
    type: 'error',
    name: 'Allocation__TokenNotAllowed',
    inputs: []
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
    name: 'Allocation__ZeroAmount',
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
