// This file is auto-generated from forge-artifacts/MasterHook.sol/MasterHook.json
// Do not edit manually.

export default [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_routerProxy",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isInitialized",
    "inputs": [
      {
        "name": "",
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
    "stateMutability": "pure"
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
    "name": "router",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract MasterRouter"
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
