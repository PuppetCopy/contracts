// This file is auto-generated from forge-artifacts/Allocate.sol/Allocate.json
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
        "internalType": "struct Allocate.Config",
        "components": [
          {
            "name": "attest",
            "type": "address",
            "internalType": "contract Attest"
          },
          {
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "compact",
            "type": "address",
            "internalType": "contract Compact"
          },
          {
            "name": "allocateGasLimit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawGasLimit",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ALLOCATE_ATTESTATION_TYPEHASH",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "WITHDRAW_ATTESTATION_TYPEHASH",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "account7579CodeHashMap",
    "inputs": [
      {
        "name": "codeHash",
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
    "name": "allocate",
    "inputs": [
      {
        "name": "_matcher",
        "type": "address",
        "internalType": "contract Match"
      },
      {
        "name": "_master",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
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
    "name": "computeTokenId",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_baseToken",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "config",
    "inputs": [],
    "outputs": [
      {
        "name": "attest",
        "type": "address",
        "internalType": "contract Attest"
      },
      {
        "name": "masterHook",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "compact",
        "type": "address",
        "internalType": "contract Compact"
      },
      {
        "name": "allocateGasLimit",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "withdrawGasLimit",
        "type": "uint256",
        "internalType": "uint256"
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
    "name": "eip712Domain",
    "inputs": [],
    "outputs": [
      {
        "name": "fields",
        "type": "bytes1",
        "internalType": "bytes1"
      },
      {
        "name": "name",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "version",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "chainId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "verifyingContract",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "extensions",
        "type": "uint256[]",
        "internalType": "uint256[]"
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
        "internalType": "struct Allocate.Config",
        "components": [
          {
            "name": "attest",
            "type": "address",
            "internalType": "contract Attest"
          },
          {
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "compact",
            "type": "address",
            "internalType": "contract Compact"
          },
          {
            "name": "allocateGasLimit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawGasLimit",
            "type": "uint256",
            "internalType": "uint256"
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
          },
          {
            "name": "disposed",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "stage",
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
        "name": "",
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
      },
      {
        "name": "disposed",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "stage",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "setCodeHash",
    "inputs": [
      {
        "name": "_codeHash",
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
    "type": "event",
    "name": "EIP712DomainChanged",
    "inputs": [],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "Allocate__AlreadyRegistered",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__AmountMismatch",
    "inputs": [
      {
        "name": "expected",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "actual",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__ArrayLengthMismatch",
    "inputs": [
      {
        "name": "puppetCount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "allocationCount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__AttestationExpired",
    "inputs": [
      {
        "name": "deadline",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "currentTime",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__DepositExceedsCap",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__InsufficientBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InsufficientLiquidity",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidAccountCodeHash",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidAttestation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidAttestor",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidCompact",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidGasLimit",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidMasterHook",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__MasterDisposed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__TokenNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__UninstallDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__UnregisteredMaster",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__ZeroAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__ZeroShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidShortString",
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
    "name": "StringTooLong",
    "inputs": [
      {
        "name": "str",
        "type": "string",
        "internalType": "string"
      }
    ]
  }
] as const
