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
            "name": "position",
            "type": "address",
            "internalType": "contract Position"
          },
          {
            "name": "attest",
            "type": "address",
            "internalType": "contract Attest"
          },
          {
            "name": "compact",
            "type": "address",
            "internalType": "contract Compact"
          },
          {
            "name": "tokenRouter",
            "type": "address",
            "internalType": "contract TokenRouter"
          },
          {
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
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
        "name": "position",
        "type": "address",
        "internalType": "contract Position"
      },
      {
        "name": "attest",
        "type": "address",
        "internalType": "contract Attest"
      },
      {
        "name": "compact",
        "type": "address",
        "internalType": "contract Compact"
      },
      {
        "name": "tokenRouter",
        "type": "address",
        "internalType": "contract TokenRouter"
      },
      {
        "name": "masterHook",
        "type": "address",
        "internalType": "address"
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
    "name": "disposeMaster",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
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
            "name": "position",
            "type": "address",
            "internalType": "contract Position"
          },
          {
            "name": "attest",
            "type": "address",
            "internalType": "contract Attest"
          },
          {
            "name": "compact",
            "type": "address",
            "internalType": "contract Compact"
          },
          {
            "name": "tokenRouter",
            "type": "address",
            "internalType": "contract TokenRouter"
          },
          {
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isDisposed",
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
    "name": "processPostCall",
    "inputs": [
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
        "name": "_msgSender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_master",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_msgValue",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_msgData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "hookData",
        "type": "bytes",
        "internalType": "bytes"
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
    "type": "function",
    "name": "withdraw",
    "inputs": [
      {
        "name": "_attestation",
        "type": "tuple",
        "internalType": "struct Allocate.WithdrawAttestation",
        "components": [
          {
            "name": "user",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "master",
            "type": "address",
            "internalType": "contract IERC7579Account"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "sharePrice",
            "type": "uint256",
            "internalType": "uint256"
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
    "type": "error",
    "name": "Permission__CallerNotAuthority",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UserRouter__UnauthorizedCaller",
    "inputs": []
  }
] as const
