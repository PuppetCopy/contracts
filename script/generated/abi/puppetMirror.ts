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
            name: 'increaseCallbackGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'decreaseCallbackGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxSequencerFeeToAllocationRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxSequencerFeeToAdjustmentRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledPositionThreshold',
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
        name: 'increaseCallbackGasLimit',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'decreaseCallbackGasLimit',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxPuppetList',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxSequencerFeeToAllocationRatio',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'maxSequencerFeeToAdjustmentRatio',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'stalledPositionThreshold',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'execute',
    inputs: [
      {
        name: '_requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
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
    name: 'getAllocationWithPuppets',
    inputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'total',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'puppetAllocations',
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
            name: 'increaseCallbackGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'decreaseCallbackGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxPuppetList',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxSequencerFeeToAllocationRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxSequencerFeeToAdjustmentRatio',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledPositionThreshold',
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
    name: 'getPosition',
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
        type: 'tuple',
        internalType: 'struct Mirror.Position',
        components: [
          {
            name: 'size',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'traderSize',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'traderCollateral',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'lastUpdateTime',
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
    name: 'getTraderPositionCollateralAmount',
    inputs: [
      {
        name: '_traderPositionKey',
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
    name: 'getTraderPositionSizeInUsd',
    inputs: [
      {
        name: '_traderPositionKey',
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
    name: 'liquidate',
    inputs: [
      {
        name: '_allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'positionMap',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      }
    ],
    outputs: [
      {
        name: 'size',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'traderSize',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'traderCollateral',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'lastUpdateTime',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'requestAdjust',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_callbackContract',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Mirror.CallPosition',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'traderRequestKey',
            type: 'bytes32',
            internalType: 'bytes32'
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
            name: 'sequencerFeeReceiver',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'isIncrease',
            type: 'bool',
            internalType: 'bool'
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
            name: 'collateralDelta',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sizeDeltaInUsd',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'triggerPrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sequencerFee',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
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
    name: 'requestAdjustmentMap',
    inputs: [
      {
        name: 'requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'traderIsIncrease',
        type: 'bool',
        internalType: 'bool'
      },
      {
        name: 'isIncrease',
        type: 'bool',
        internalType: 'bool'
      },
      {
        name: 'traderCollateralDelta',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'traderSizeDelta',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'sizeDelta',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'requestCloseStalled',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_params',
        type: 'tuple',
        internalType: 'struct Mirror.StalledPositionParams',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'market',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'sequencerFeeReceiver',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'reasonEnum',
            type: 'uint8',
            internalType: 'uint8'
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
            name: 'acceptablePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sequencerFee',
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
        name: '_callbackContract',
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
    name: 'requestOpen',
    inputs: [
      {
        name: '_account',
        type: 'address',
        internalType: 'contract Account'
      },
      {
        name: '_ruleContract',
        type: 'address',
        internalType: 'contract Rule'
      },
      {
        name: '_callbackContract',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Mirror.CallPosition',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'traderRequestKey',
            type: 'bytes32',
            internalType: 'bytes32'
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
            name: 'sequencerFeeReceiver',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'isIncrease',
            type: 'bool',
            internalType: 'bool'
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
            name: 'collateralDelta',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sizeDeltaInUsd',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'acceptablePrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'triggerPrice',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sequencerFee',
            type: 'uint256',
            internalType: 'uint256'
          }
        ]
      },
      {
        name: '_puppetList',
        type: 'address[]',
        internalType: 'address[]'
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
    name: 'Mirror__ExecutionRequestMissing',
    inputs: [
      {
        name: 'requestKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__InitialMustBeIncrease',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InsufficientAllocationForSequencerFee',
    inputs: [
      {
        name: 'allocation',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'sequencerFee',
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
    name: 'Mirror__InvalidCollateralDelta',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidCurrentLeverage',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidSequencerExecutionFeeAmount',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__InvalidSizeDelta',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__NoAdjustmentRequired',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__OrderCreationFailed',
    inputs: []
  },
  {
    type: 'error',
    name: 'Mirror__PositionNotFound',
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
    name: 'Mirror__PositionNotStalled',
    inputs: [
      {
        name: 'allocationAddress',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ]
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
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256'
      }
    ]
  },
  {
    type: 'error',
    name: 'Mirror__SequencerFeeExceedsAdjustmentRatio',
    inputs: [
      {
        name: 'sequencerFee',
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
    name: 'Mirror__SequencerFeeExceedsCostFactor',
    inputs: [
      {
        name: 'sequencerFee',
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
    name: 'Mirror__SequencerFeeNotFullyCovered',
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
    name: 'Mirror__TraderCollateralZero',
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
    name: 'Mirror__TraderPositionNotFound',
    inputs: [
      {
        name: 'trader',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'positionKey',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ]
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
