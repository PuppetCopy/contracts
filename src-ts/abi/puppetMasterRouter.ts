// This file is auto-generated from forge-artifacts/MasterRouter.sol/MasterRouter.json
// Do not edit manually.

export default [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_authority",
        "type": "address",
        "internalType": "contract IAuthority"
      },
      {
        "name": "_registry",
        "type": "address",
        "internalType": "contract Registry"
      },
      {
        "name": "_position",
        "type": "address",
        "internalType": "contract Position"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "authority",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IAuthority"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "canCall",
    "inputs": [
      {
        "name": "user",
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
    "name": "createMaster",
    "inputs": [
      {
        "name": "_user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_baseTokenId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_name",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "processPostCall",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_hookData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "processPreCall",
    "inputs": [
      {
        "name": "_caller",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_callValue",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_callData",
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
    "type": "function",
    "name": "setAccess",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "isEnabled",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "error",
    "name": "Access__CallerNotAuthority",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Access__Unauthorized",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__TokenNotFound",
    "inputs": []
  }
] as const
