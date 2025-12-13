// This file is auto-generated from forge-artifacts/Mirror.sol/Mirror.json
// Do not edit manually.

export default [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        type: 'address',
        internalType: 'contract IAuthority'
      },
      {
        name: '_config',
        type: 'tuple',
        internalType: 'struct Mirror.Config',
        components: [
          {
            name: 'gmxExchangeRouter',
            type: 'address',
            internalType: 'contract IGmxExchangeRouter'
          },
          {
            name: 'gmxDataStore',
            type: 'address',
            internalType: 'contract IGmxReadDataStore'
          },
          {
            name: 'gmxOrderVault',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'referralCode',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToAllocationRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToAdjustmentRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToCloseRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchOpenDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchAdjustDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'collateralReserveBps',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'adjust',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_callPosition',
        type: 'tuple',
        internalType: 'struct Mirror.CallPosition',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'market',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'isLong',
            type: 'bool',
            internalType: 'bool'
          },
          {
            name: 'executionFee',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'matchmakerFee',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      },
      {
        name: '_feeReceiver',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    name: 'allocationMap',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'totalAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'allocationPuppetList',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: 'puppetAmounts',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'authority',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IAuthority'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'canCall',
    inputs: [
      {
        name: 'signatureHash',
        type: 'bytes4',
        internalType: 'bytes4'
      },
      {
        name: 'user',
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
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'close',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_callPosition',
        type: 'tuple',
        internalType: 'struct Mirror.CallPosition',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'market',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'isLong',
            type: 'bool',
            internalType: 'bool'
          },
          {
            name: 'executionFee',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'matchmakerFee',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      },
      {
        name: '_reason',
        type: 'uint8',
        internalType: 'uint8'
      },
      {
        name: '_feeReceiver',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    name: 'config',
    inputs: [],
    outputs: [
      {
        name: 'gmxExchangeRouter',
        type: 'address',
        internalType: 'contract IGmxExchangeRouter'
      },
      {
        name: 'gmxDataStore',
        type: 'address',
        internalType: 'contract IGmxReadDataStore'
      },
      {
        name: 'gmxOrderVault',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'referralCode',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'maxPuppetList',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxMatchmakerFeeToAllocationRatio',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxMatchmakerFeeToAdjustmentRatio',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxMatchmakerFeeToCloseRatio',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxMatchOpenDuration',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxMatchAdjustDuration',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'collateralReserveBps',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getAllocation',
    inputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getAllocationPuppetList',
    inputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256[]',
        internalType: 'uint256[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct Mirror.Config',
        components: [
          {
            name: 'gmxExchangeRouter',
            type: 'address',
            internalType: 'contract IGmxExchangeRouter'
          },
          {
            name: 'gmxDataStore',
            type: 'address',
            internalType: 'contract IGmxReadDataStore'
          },
          {
            name: 'gmxOrderVault',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'referralCode',
            type: 'bytes32',
            internalType: 'bytes32'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToAllocationRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToAdjustmentRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchmakerFeeToCloseRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchOpenDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxMatchAdjustDuration',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'collateralReserveBps',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getLastActivityThrottle',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_puppet',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getPositionSizeInUsd',
    inputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_market',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_collateralToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_isLong',
        type: 'bool',
        internalType: 'bool'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'initializeTraderActivityThrottle',
    inputs: [
      {
        name: '_traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '_puppet',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'lastActivityThrottleMap',
    inputs: [
      {
        name: 'traderMatchingKey',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'puppet',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'lastActivity',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'lastTargetSizeMap',
    inputs: [
      {
        name: 'positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'matchmake',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_subscribe',
        type: 'address',
        internalType: 'contract Subscribe'
      },
      {
        name: '_callPosition',
        type: 'tuple',
        internalType: 'struct Mirror.CallPosition',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'market',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'isLong',
            type: 'bool',
            internalType: 'bool'
          },
          {
            name: 'executionFee',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'matchmakerFee',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
      },
      {
        name: '_feeReceiver',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    name: 'reservedCollateralMap',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'reservedCollateralAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'setConfig',
    inputs: [
      {
        name: '_data',
        type: 'bytes',
        internalType: 'bytes'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setPermission',
    inputs: [
      {
        name: 'functionSig',
        type: 'bytes4',
        internalType: 'bytes4'
      },
      {
        name: 'user',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'isEnabled',
        type: 'bool',
        internalType: 'bool'
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
    name: 'Mirror__AllocationNotFullyRedistributed',
    inputs: [
      {
        name: 'remainingAllocation',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InsufficientGmxExecutionFee',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'required',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InvalidAllocation',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InvalidMatchmakerExecutionFeeAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidSizeDelta',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__MatchmakerFeeExceedsAdjustmentRatio',
    inputs: [
      {
        name: 'matchmakerFee',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'allocationAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchmakerFeeExceedsCloseRatio',
    inputs: [
      {
        name: 'matchmakerFee',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'allocationAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchmakerFeeExceedsCostFactor',
    inputs: [
      {
        name: 'matchmakerFee',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'allocationAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__MatchmakerFeeNotFullyCovered',
    inputs: [
      {
        name: 'totalPaid',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'requiredFee',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__NoPosition',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__OrderCreationFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PositionAlreadyOpen',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListEmpty',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListMismatch',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__PuppetListTooLarge',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maximum',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__RequestPending',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__TraderPositionTooOld',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__CallerNotAuthority',
    inputs: []
  },
  {
    type: 'error',
    name: 'Permission__Unauthorized',
    inputs: []
  },
  {
    type: 'error',
    name: 'ReentrancyGuardReentrantCall',
    inputs: []
  }
] as const
