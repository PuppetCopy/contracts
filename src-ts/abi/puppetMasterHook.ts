// This file is auto-generated from forge-artifacts/MasterHook.sol/MasterHook.json
// Do not edit manually.

export default [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_position",
        "type": "address",
        "internalType": "contract Position"
      },
      {
        "name": "_registry",
        "type": "address",
        "internalType": "contract Registry"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isInitialized",
    "inputs": [
      {
        "name": "_account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isModuleType",
    "inputs": [
      {
        "name": "_moduleTypeId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "onInstall",
    "inputs": [
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "onUninstall",
    "inputs": [
      {
        "name": "",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "position",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract Position"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "postCheck",
    "inputs": [
      {
        "name": "hookData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "preCheck",
    "inputs": [
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "callValue",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "callData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "registry",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract Registry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "error",
    "name": "MasterHook__UninstallDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ModuleAlreadyInitialized",
    "inputs": [
      {
        "name": "smartAccount",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "NotInitialized",
    "inputs": [
      {
        "name": "smartAccount",
        "type": "address",
        "internalType": "address"
      }
    ]
  }
] as const
