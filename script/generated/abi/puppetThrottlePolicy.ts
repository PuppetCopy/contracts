// This file is auto-generated from forge-artifacts/ThrottlePolicy.sol/ThrottlePolicy.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_eventEmitter',
        type: 'address',
        internalType: 'contract IEventEmitter'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'checkAction',
    inputs: [
      {
        name: 'id',
        type: 'bytes32',
        internalType: 'ConfigId'
      },
      {
        name: 'account',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'value',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'data',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'eventEmitter',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IEventEmitter'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'initializeWithMultiplexer',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'configId',
        type: 'bytes32',
        internalType: 'ConfigId'
      },
      {
        name: 'initData',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'isInitialized',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'configId',
        type: 'bytes32',
        internalType: 'ConfigId'
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
    name: 'isInitialized',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'multiplexer',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'configId',
        type: 'bytes32',
        internalType: 'ConfigId'
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
        name: 'moduleTypeId',
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
  }
] as const
