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
    name: 'allocate',
    inputs: [
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_masterAllocation',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      },
      {
        name: '_allocationList',
        type: 'uint256[]',
        internalType: 'uint256[]'
      }
    ],
    outputs: [],
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
    name: 'syncAllocation',
    inputs: [
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_master',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'withdrawAllocation',
    inputs: [
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_master',
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
