// This file is auto-generated from forge-artifacts/UserRouter.sol/UserRouter.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
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
        name: '_feeMarketplace',
        type: 'address',
        internalType: 'contract FeeMarketplace'
      },
      {
        name: '_mirror',
        type: 'address',
        internalType: 'contract Mirror'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'acceptOffer',
    inputs: [
      {
        name: 'feeToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: 'receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'purchaseAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'account',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Account'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'deposit',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: 'amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'feeMarketplace',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract FeeMarketplace'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'mirror',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Mirror'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'setRule',
    inputs: [
      {
        name: 'collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: 'trader',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'ruleParams',
        type: 'tuple',
        internalType: 'struct Subscribe.RuleParams',
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
    name: 'subscribe',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Subscribe'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'withdraw',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: 'receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'error',
    name: 'ReentrancyGuardReentrantCall',
    inputs: []
  }
] as const
