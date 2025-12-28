// This file is auto-generated from forge-artifacts/UserRouter.sol/UserRouter.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_allocate',
        type: 'address',
        internalType: 'contract Allocate'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'allocate',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Allocate'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'createSubaccount',
    inputs: [
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
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const
