// This file is auto-generated from forge-artifacts/Registry.sol/Registry.json
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
        "name": "_config",
        "type": "tuple",
        "internalType": "struct Registry.Config",
        "components": [
          {
            "name": "account7579CodeList",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
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
        "name": "signatureHash",
        "type": "bytes4",
        "internalType": "bytes4"
      },
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
        "name": "_baseToken",
        "type": "address",
        "internalType": "contract IERC20"
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
    "name": "getConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct Registry.Config",
        "components": [
          {
            "name": "account7579CodeList",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getMasterInfo",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct MasterInfo",
        "components": [
          {
            "name": "user",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "signer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "baseToken",
            "type": "address",
            "internalType": "contract IERC20"
          },
          {
            "name": "name",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isAllowedCodeHash",
    "inputs": [
      {
        "name": "_codeHash",
        "type": "bytes32",
        "internalType": "bytes32"
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
    "name": "isRegistered",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
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
    "name": "registeredMap",
    "inputs": [
      {
        "name": "master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      }
    ],
    "outputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "signer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "baseToken",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "name",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "setConfig",
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
    "name": "setPermission",
    "inputs": [
      {
        "name": "functionSig",
        "type": "bytes4",
        "internalType": "bytes4"
      },
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
    "type": "function",
    "name": "setToken",
    "inputs": [
      {
        "name": "_tokenId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_token",
        "type": "address",
        "internalType": "contract IERC20"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTokenCap",
    "inputs": [
      {
        "name": "_token",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "_cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "tokenCapMap",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "contract IERC20"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokenMap",
    "inputs": [
      {
        "name": "tokenId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IERC20"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "error",
    "name": "Permission__CallerNotAuthority",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Permission__Unauthorized",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__AlreadyRegistered",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__InvalidAccountCodeHash",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__InvalidTokenAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__InvalidTokenId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Registry__TokenNotAllowed",
    "inputs": []
  }
] as const
