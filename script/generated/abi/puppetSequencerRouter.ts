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
            name: 'fallbackRefundExecutionFeeReceiver',
            type: 'address',
            internalType: 'address'
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
    name: 'afterOrderCancellation',
    inputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.Props',
        components: [
          {
            name: 'addresses',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Addresses',
            components: [
              {
                name: 'account',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'receiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'cancellationReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'callbackContract',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'uiFeeReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'market',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'initialCollateralToken',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'swapPath',
                type: 'address[]',
                internalType: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Numbers',
            components: [
              {
                name: 'orderType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.OrderType'
              },
              {
                name: 'decreasePositionSwapType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType'
              },
              {
                name: 'sizeDeltaUsd',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'triggerPrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'acceptablePrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'executionFee',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'minOutputAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'updatedAtTime',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'validFromTime',
                type: 'uint256',
                internalType: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Flags',
            components: [
              {
                name: 'isLong',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'shouldUnwrapNativeToken',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'isFrozen',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'autoCancel',
                type: 'bool',
                internalType: 'bool'
              }
            ]
          }
        ]
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.EventLogData',
        components: [
          {
            name: 'addressItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.AddressItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address',
                    internalType: 'address'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address[]',
                    internalType: 'address[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'uintItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.UintItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256',
                    internalType: 'uint256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256[]',
                    internalType: 'uint256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'intItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.IntItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256',
                    internalType: 'int256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256[]',
                    internalType: 'int256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'boolItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BoolItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool',
                    internalType: 'bool'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool[]',
                    internalType: 'bool[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytes32Items',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Bytes32Items',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32KeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32',
                    internalType: 'bytes32'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32ArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32[]',
                    internalType: 'bytes32[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytesItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BytesItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes',
                    internalType: 'bytes'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes[]',
                    internalType: 'bytes[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'stringItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.StringItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string',
                    internalType: 'string'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string[]',
                    internalType: 'string[]'
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'afterOrderExecution',
    inputs: [
      {
        name: 'key',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: 'order',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.Props',
        components: [
          {
            name: 'addresses',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Addresses',
            components: [
              {
                name: 'account',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'receiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'cancellationReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'callbackContract',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'uiFeeReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'market',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'initialCollateralToken',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'swapPath',
                type: 'address[]',
                internalType: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Numbers',
            components: [
              {
                name: 'orderType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.OrderType'
              },
              {
                name: 'decreasePositionSwapType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType'
              },
              {
                name: 'sizeDeltaUsd',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'triggerPrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'acceptablePrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'executionFee',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'minOutputAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'updatedAtTime',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'validFromTime',
                type: 'uint256',
                internalType: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Flags',
            components: [
              {
                name: 'isLong',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'shouldUnwrapNativeToken',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'isFrozen',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'autoCancel',
                type: 'bool',
                internalType: 'bool'
              }
            ]
          }
        ]
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.EventLogData',
        components: [
          {
            name: 'addressItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.AddressItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address',
                    internalType: 'address'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address[]',
                    internalType: 'address[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'uintItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.UintItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256',
                    internalType: 'uint256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256[]',
                    internalType: 'uint256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'intItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.IntItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256',
                    internalType: 'int256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256[]',
                    internalType: 'int256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'boolItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BoolItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool',
                    internalType: 'bool'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool[]',
                    internalType: 'bool[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytes32Items',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Bytes32Items',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32KeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32',
                    internalType: 'bytes32'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32ArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32[]',
                    internalType: 'bytes32[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytesItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BytesItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes',
                    internalType: 'bytes'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes[]',
                    internalType: 'bytes[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'stringItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.StringItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string',
                    internalType: 'string'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string[]',
                    internalType: 'string[]'
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'afterOrderFrozen',
    inputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.Props',
        components: [
          {
            name: 'addresses',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Addresses',
            components: [
              {
                name: 'account',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'receiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'cancellationReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'callbackContract',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'uiFeeReceiver',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'market',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'initialCollateralToken',
                type: 'address',
                internalType: 'address'
              },
              {
                name: 'swapPath',
                type: 'address[]',
                internalType: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Numbers',
            components: [
              {
                name: 'orderType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.OrderType'
              },
              {
                name: 'decreasePositionSwapType',
                type: 'uint8',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType'
              },
              {
                name: 'sizeDeltaUsd',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'triggerPrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'acceptablePrice',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'executionFee',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'minOutputAmount',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'updatedAtTime',
                type: 'uint256',
                internalType: 'uint256'
              },
              {
                name: 'validFromTime',
                type: 'uint256',
                internalType: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Flags',
            components: [
              {
                name: 'isLong',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'shouldUnwrapNativeToken',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'isFrozen',
                type: 'bool',
                internalType: 'bool'
              },
              {
                name: 'autoCancel',
                type: 'bool',
                internalType: 'bool'
              }
            ]
          }
        ]
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.EventLogData',
        components: [
          {
            name: 'addressItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.AddressItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address',
                    internalType: 'address'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address[]',
                    internalType: 'address[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'uintItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.UintItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256',
                    internalType: 'uint256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256[]',
                    internalType: 'uint256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'intItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.IntItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256',
                    internalType: 'int256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256[]',
                    internalType: 'int256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'boolItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BoolItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool',
                    internalType: 'bool'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool[]',
                    internalType: 'bool[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytes32Items',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Bytes32Items',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32KeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32',
                    internalType: 'bytes32'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32ArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32[]',
                    internalType: 'bytes32[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytesItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BytesItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes',
                    internalType: 'bytes'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes[]',
                    internalType: 'bytes[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'stringItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.StringItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string',
                    internalType: 'string'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string[]',
                    internalType: 'string[]'
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
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
            name: 'fallbackRefundExecutionFeeReceiver',
            type: 'address',
            internalType: 'address'
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
    name: 'refundExecutionFee',
    inputs: [
      {
        name: 'key',
        type: 'bytes32',
        internalType: 'bytes32'
      },
      {
        name: '',
        type: 'tuple',
        internalType: 'struct GmxPositionUtils.EventLogData',
        components: [
          {
            name: 'addressItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.AddressItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address',
                    internalType: 'address'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.AddressArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'address[]',
                    internalType: 'address[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'uintItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.UintItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256',
                    internalType: 'uint256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.UintArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'uint256[]',
                    internalType: 'uint256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'intItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.IntItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256',
                    internalType: 'int256'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.IntArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'int256[]',
                    internalType: 'int256[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'boolItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BoolItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool',
                    internalType: 'bool'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BoolArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bool[]',
                    internalType: 'bool[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytes32Items',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.Bytes32Items',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32KeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32',
                    internalType: 'bytes32'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.Bytes32ArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes32[]',
                    internalType: 'bytes32[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'bytesItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.BytesItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes',
                    internalType: 'bytes'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.BytesArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'bytes[]',
                    internalType: 'bytes[]'
                  }
                ]
              }
            ]
          },
          {
            name: 'stringItems',
            type: 'tuple',
            internalType: 'struct GmxPositionUtils.StringItems',
            components: [
              {
                name: 'items',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string',
                    internalType: 'string'
                  }
                ]
              },
              {
                name: 'arrayItems',
                type: 'tuple[]',
                internalType: 'struct GmxPositionUtils.StringArrayKeyValue[]',
                components: [
                  {
                    name: 'key',
                    type: 'string',
                    internalType: 'string'
                  },
                  {
                    name: 'value',
                    type: 'string[]',
                    internalType: 'string[]'
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    name: 'requestAdjust',
    inputs: [
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
    name: 'requestCloseStalled',
    inputs: [
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
      }
    ],
    outputs: [
      {
        name: '',
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
  },
  {
    type: 'error',
    name: 'SequencerRouter__FailedRefundExecutionFee',
    inputs: []
  }
] as const
