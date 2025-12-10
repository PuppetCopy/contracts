// This file is auto-generated from forge-artifacts/FeeMarketplace.sol/FeeMarketplace.json
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
        name: '_protocolToken',
        type: 'address',
        internalType: 'contract PuppetToken'
      },
      {
        name: '_store',
        type: 'address',
        internalType: 'contract FeeMarketplaceStore'
      },
      {
        name: '_config',
        type: 'tuple',
        internalType: 'struct FeeMarketplace.Config',
        components: [
          {
            name: 'transferOutGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'distributionTimeframe',
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
    name: 'acceptOffer',
    inputs: [
      {
        name: '_feeToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_depositor',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_purchaseAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'accountedBalance',
    inputs: [
      {
        name: '',
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
    name: 'askAmount',
    inputs: [
      {
        name: '',
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
    name: 'deposit',
    inputs: [
      {
        name: '_feeToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_depositor',
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
        internalType: 'struct FeeMarketplace.Config',
        components: [
          {
            name: 'transferOutGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'distributionTimeframe',
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
    name: 'getPendingUnlock',
    inputs: [
      {
        name: '_feeToken',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    outputs: [
      {
        name: '_pending',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getTotalUnlocked',
    inputs: [
      {
        name: '_feeToken',
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
    name: 'lastDistributionTimestamp',
    inputs: [
      {
        name: '',
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
    name: 'protocolToken',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract PuppetToken'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'setAskPrice',
    inputs: [
      {
        name: '_feeToken',
        type: 'address',
        internalType: 'contract IERC20'
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
    name: 'store',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract FeeMarketplaceStore'
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
    name: 'syncBalance',
    inputs: [
      {
        name: '_feeToken',
        type: 'address',
        internalType: 'contract IERC20'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'unclockedFees',
    inputs: [
      {
        name: '',
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
    type: 'error',
    name: 'FeeMarketplace__InsufficientUnlockedBalance',
    inputs: [
      {
        name: 'accruedReward',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'FeeMarketplace__InvalidAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__NotAuctionableToken',
    inputs: []
  },
  {
    type: 'error',
    name: 'FeeMarketplace__ZeroDeposit',
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
