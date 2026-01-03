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
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "maxPuppetList",
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
    "name": "CALL_INTENT_TYPEHASH",
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
    "name": "baseTokenMap",
    "inputs": [
      {
        "name": "subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
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
        "name": "masterHook",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "maxPuppetList",
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
    "name": "disposeSubaccount",
    "inputs": [
      {
        "name": "_subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "disposedMap",
    "inputs": [
      {
        "name": "subaccount",
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
    "name": "executeAllocate",
    "inputs": [
      {
        "name": "_position",
        "type": "address",
        "internalType": "contract Position"
      },
      {
        "name": "_match",
        "type": "address",
        "internalType": "contract Match"
      },
      {
        "name": "_intent",
        "type": "tuple",
        "internalType": "struct Allocate.CallIntent",
        "components": [
          {
            "name": "account",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "subaccount",
            "type": "address",
            "internalType": "contract IERC7579Account"
          },
          {
            "name": "token",
            "type": "address",
            "internalType": "contract IERC20"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "triggerNetValue",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "acceptableNetValue",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "positionParamsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "deadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "nonce",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_signature",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "_puppetList",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "_amountList",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "_positionParams",
        "type": "tuple",
        "internalType": "struct Allocate.PositionParams",
        "components": [
          {
            "name": "stages",
            "type": "address[]",
            "internalType": "contract IStage[]"
          },
          {
            "name": "positionKeys",
            "type": "bytes32[][]",
            "internalType": "bytes32[][]"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "executeWithdraw",
    "inputs": [
      {
        "name": "_position",
        "type": "address",
        "internalType": "contract Position"
      },
      {
        "name": "_intent",
        "type": "tuple",
        "internalType": "struct Allocate.CallIntent",
        "components": [
          {
            "name": "account",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "subaccount",
            "type": "address",
            "internalType": "contract IERC7579Account"
          },
          {
            "name": "token",
            "type": "address",
            "internalType": "contract IERC20"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "triggerNetValue",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "acceptableNetValue",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "positionParamsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "deadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "nonce",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_signature",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "_positionParams",
        "type": "tuple",
        "internalType": "struct Allocate.PositionParams",
        "components": [
          {
            "name": "stages",
            "type": "address[]",
            "internalType": "contract IStage[]"
          },
          {
            "name": "positionKeys",
            "type": "bytes32[][]",
            "internalType": "bytes32[][]"
          }
        ]
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
        "internalType": "struct Allocate.Config",
        "components": [
          {
            "name": "masterHook",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "maxPuppetList",
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
    "name": "getSharePrice",
    "inputs": [
      {
        "name": "_subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_totalAssets",
        "type": "uint256",
        "internalType": "uint256"
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
    "name": "getUserShares",
    "inputs": [
      {
        "name": "_subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "_account",
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
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "hasRemainingShares",
    "inputs": [
      {
        "name": "_subaccount",
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
    "name": "nonceMap",
    "inputs": [
      {
        "name": "subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
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
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "registerMasterSubaccount",
    "inputs": [
      {
        "name": "_account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_signer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_subaccount",
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
    "name": "registeredMap",
    "inputs": [
      {
        "name": "subaccount",
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
    "name": "sessionSignerMap",
    "inputs": [
      {
        "name": "subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
      }
    ],
    "outputs": [
      {
        "name": "",
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
    "name": "shareBalanceMap",
    "inputs": [
      {
        "name": "subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
      },
      {
        "name": "account",
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
    "stateMutability": "view"
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
    "name": "totalSharesMap",
    "inputs": [
      {
        "name": "subaccount",
        "type": "address",
        "internalType": "contract IERC7579Account"
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
    "name": "Allocate__IntentExpired",
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
    "name": "Allocate__InvalidAccountCodeHash",
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
    "name": "Allocate__InvalidMaxPuppetList",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__InvalidNonce",
    "inputs": [
      {
        "name": "expected",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "provided",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__InvalidSignature",
    "inputs": [
      {
        "name": "expected",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "recovered",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__MasterHookNotInstalled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__NetValueAboveMax",
    "inputs": [
      {
        "name": "netValue",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "acceptableNetValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__NetValueBelowMin",
    "inputs": [
      {
        "name": "netValue",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "acceptableNetValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__NetValueParamsMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__PuppetListTooLarge",
    "inputs": [
      {
        "name": "provided",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "maximum",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "Allocate__SubaccountFrozen",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__TokenMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__TokenNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__TransferFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__UnregisteredSubaccount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Allocate__ZeroAssets",
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
