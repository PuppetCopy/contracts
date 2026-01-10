// This file is auto-generated from forge-artifacts/Position.sol/Position.json
// Do not edit manually.

export default [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_authority",
        "type": "address",
        "internalType": "contract IAuthority"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ACTION_NONE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "ACTION_ORDER_CREATED",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
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
    "name": "getNetValue",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_baseToken",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "_stages",
        "type": "address[]",
        "internalType": "contract IStage[]"
      },
      {
        "name": "_positionKeys",
        "type": "bytes32[][]",
        "internalType": "bytes32[][]"
      }
    ],
    "outputs": [
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "handlers",
    "inputs": [
      {
        "name": "target",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IStage"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pendingOrderCount",
    "inputs": [
      {
        "name": "master",
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
    "name": "processPostCall",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "address"
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
        "name": "_hookData",
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
    "name": "setHandler",
    "inputs": [
      {
        "name": "_target",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_handler",
        "type": "address",
        "internalType": "contract IStage"
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
    "name": "settleOrders",
    "inputs": [
      {
        "name": "_master",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_orderStages",
        "type": "address[]",
        "internalType": "contract IStage[]"
      },
      {
        "name": "_orderKeys",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
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
    "name": "validStages",
    "inputs": [
      {
        "name": "stage",
        "type": "address",
        "internalType": "contract IStage"
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
    "name": "Position__ArrayLengthMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__BatchOrderNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__DelegateCallBlocked",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__InvalidStage",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__NotPositionOwner",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__OrderStillPending",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Position__PendingOrdersExist",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
] as const
