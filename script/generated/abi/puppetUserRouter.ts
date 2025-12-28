// This file is auto-generated from forge-artifacts/UserRouter.sol/UserRouter.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_allocation',
        type: 'address',
        internalType: 'contract Allocation'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'allocation',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Allocation'
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
  }
] as const
