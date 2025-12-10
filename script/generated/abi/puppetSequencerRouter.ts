// This file is auto-generated from forge-artifacts/SequencerRouter.sol/SequencerRouter.json
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
        name: '_mirror',
        type: 'address',
        internalType: 'contract Mirror'
      },
      {
        name: '_settle',
        type: 'address',
        internalType: 'contract Settle'
      },
      {
        name: '_config',
        type: 'tuple',
        internalType: 'struct SequencerRouter.Config',
        components: [
          {
            name: 'openBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'openPerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'adjustBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'adjustPerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'settleBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'settlePerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'gasPriceBufferBasisPoints',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxEthPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxIndexPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxFiatPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxGasAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledCheckInterval',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledPositionThreshold',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minOpenTraderCollateral',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAllocationUsd',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAdjustUsd',
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
    name: 'account',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Account'
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
    name: 'collectAllocationAccountDust',
    inputs: [
      {
        name: '_allocationAccount',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_dustToken',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [
      {
        name: '',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct SequencerRouter.Config',
        components: [
          {
            name: 'openBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'openPerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'adjustBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'adjustPerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'settleBaseGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'settlePerPuppetGasLimit',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'gasPriceBufferBasisPoints',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxEthPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxIndexPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxFiatPriceAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'maxGasAge',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledCheckInterval',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'stalledPositionThreshold',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minOpenTraderCollateral',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAllocationUsd',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'minAdjustUsd',
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
    name: 'mirror',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Mirror'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'recoverUnaccountedTokens',
    inputs: [
      {
        name: '_token',
        type: 'address',
        internalType: 'contract IERC20'
      },
      {
        name: '_receiver',
        type: 'address',
        internalType: 'address'
      },
      {
        name: '_amount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'requestAdjust',
    inputs: [
      {
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Mirror.CallParams',
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
            name: 'sequencerFeeReceiver',
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
    name: 'requestClose',
    inputs: [
      {
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Mirror.CallParams',
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
            name: 'sequencerFeeReceiver',
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
        name: '_reason',
        type: 'uint8',
        internalType: 'uint8'
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
        name: '_callParams',
        type: 'tuple',
        internalType: 'struct Mirror.CallParams',
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
            name: 'sequencerFeeReceiver',
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
    name: 'ruleContract',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Rule'
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
    name: 'settle',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract Settle'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'settleAllocation',
    inputs: [
      {
        name: '_settleParams',
        type: 'tuple',
        internalType: 'struct Settle.CallSettle',
        components: [
          {
            name: 'collateralToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'distributionToken',
            type: 'address',
            internalType: 'contract IERC20'
          },
          {
            name: 'sequencerFeeReceiver',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'trader',
            type: 'address',
            internalType: 'address'
          },
          {
            name: 'allocationId',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'sequencerExecutionFee',
            type: 'uint256',
            internalType: 'uint256'
          },
          {
            name: 'amount',
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
        name: 'distributionAmount',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'platformFeeAmount',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
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
