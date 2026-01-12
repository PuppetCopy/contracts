// This file is auto-generated from forge-artifacts/UserRouter.sol/UserRouter.json
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
        "internalType": "struct UserRouter.Config",
        "components": [
          {
            "name": "allocation",
            "type": "address",
            "internalType": "contract Allocate"
          },
          {
            "name": "matcher",
            "type": "address",
            "internalType": "contract Match"
          },
          {
            "name": "tokenRouter",
            "type": "address",
            "internalType": "contract TokenRouter"
          },
          {
            "name": "registry",
            "type": "address",
            "internalType": "contract Registry"
          }
        ]
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "allocate",
    "inputs": [
      {
        "name": "_puppetList",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "_requestedAmountList",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "_attestation",
        "type": "tuple",
        "internalType": "struct Allocate.AllocateAttestation",
        "components": [
          {
            "name": "master",
            "type": "address",
            "internalType": "contract IERC7579Account"
          },
          {
            "name": "sharePrice",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "masterAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "puppetListHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "amountListHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "blockNumber",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "blockTimestamp",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "nonce",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "deadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "signature",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      }
    ],
    "outputs": [],
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
    "name": "config",
    "inputs": [],
    "outputs": [
      {
        "name": "allocation",
        "type": "address",
        "internalType": "contract Allocate"
      },
      {
        "name": "matcher",
        "type": "address",
        "internalType": "contract Match"
      },
      {
        "name": "tokenRouter",
        "type": "address",
        "internalType": "contract TokenRouter"
      },
      {
        "name": "registry",
        "type": "address",
        "internalType": "contract Registry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct UserRouter.Config",
        "components": [
          {
            "name": "allocation",
            "type": "address",
            "internalType": "contract Allocate"
          },
          {
            "name": "matcher",
            "type": "address",
            "internalType": "contract Match"
          },
          {
            "name": "tokenRouter",
            "type": "address",
            "internalType": "contract TokenRouter"
          },
          {
            "name": "registry",
            "type": "address",
            "internalType": "contract Registry"
          }
        ]
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
    "name": "setFilter",
    "inputs": [
      {
        "name": "_dim",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_value",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "_allowed",
        "type": "bool",
        "internalType": "bool"
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
    "name": "setPolicy",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_allowanceRate",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_throttlePeriod",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_expiry",
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
    "type": "error",
    "name": "Permission__CallerNotAuthority",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
] as const
