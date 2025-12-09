// This file is auto-generated. Do not edit manually.
// Source: GMX contracts/error/Errors.sol from GitHub (main branch)

export const gmxErrorAbi = [
  {
    name: 'ActionAlreadySignalled',
    type: 'error',
    inputs: []
  },
  {
    name: 'ActionNotSignalled',
    type: 'error',
    inputs: []
  },
  {
    name: 'AdlNotEnabled',
    type: 'error',
    inputs: []
  },
  {
    name: 'AdlNotRequired',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'pnlToPoolFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPnlFactorForAdl'
      }
    ]
  },
  {
    name: 'ArrayOutOfBoundsBytes',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes[]',
        type: 'bytes[]',
        name: 'values'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'index'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'label'
      }
    ]
  },
  {
    name: 'ArrayOutOfBoundsUint256',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256[]',
        type: 'uint256[]',
        name: 'values'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'index'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'label'
      }
    ]
  },
  {
    name: 'AttemptedBridgeAmountTooHigh',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minRequiredFeeAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'feeAmountCurrentChain'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amountToBridgeOut'
      }
    ]
  },
  {
    name: 'AvailableFeeAmountIsZero',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'buybackToken'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'availableFeeAmount'
      }
    ]
  },
  {
    name: 'BlockNumbersNotSorted',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOracleBlockNumber'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'prevMinOracleBlockNumber'
      }
    ]
  },
  {
    name: 'BridgedAmountNotSufficient',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minRequiredFeeAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentChainFeeAmount'
      }
    ]
  },
  {
    name: 'BridgeOutNotSupportedDuringShift',
    type: 'error',
    inputs: []
  },
  {
    name: 'BridgingBalanceArrayMismatch',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balancesLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'targetBalancesLength'
      }
    ]
  },
  {
    name: 'BridgingTransactionFailed',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes',
        type: 'bytes',
        name: 'result'
      }
    ]
  },
  {
    name: 'BuybackAndFeeTokenAreEqual',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'buybackToken'
      }
    ]
  },
  {
    name: 'ChainlinkPriceFeedNotUpdated',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'heartbeatDuration'
      }
    ]
  },
  {
    name: 'CollateralAlreadyClaimed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'adjustedClaimableAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'claimedAmount'
      }
    ]
  },
  {
    name: 'CompactedArrayOutOfBounds',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256[]',
        type: 'uint256[]',
        name: 'compactedValues'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'index'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'slotIndex'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'label'
      }
    ]
  },
  {
    name: 'ConfigValueExceedsAllowedRange',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'baseKey'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'value'
      }
    ]
  },
  {
    name: 'DataListLengthExceeded',
    type: 'error',
    inputs: []
  },
  {
    name: 'DataStreamIdAlreadyExistsForToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'DeadlinePassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'deadline'
      }
    ]
  },
  {
    name: 'DepositNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'DisabledFeature',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'DisabledMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'DuplicateClaimTerms',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'existingDistributionId'
      }
    ]
  },
  {
    name: 'DuplicatedIndex',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'index'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'label'
      }
    ]
  },
  {
    name: 'DuplicatedMarketInSwapPath',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'EdgeDataStreamIdAlreadyExistsForToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyAccount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyAddressInMarketTokenBalanceValidation',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyChainlinkPriceFeed',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyChainlinkPriceFeedMultiplier',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyClaimableAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyClaimFeesMarket',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyDataStreamFeedId',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyDataStreamMultiplier',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyDeposit',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyDepositAmounts',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyDepositAmountsAfterSwap',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyFundingAccount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlv',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      }
    ]
  },
  {
    name: 'EmptyGlvDeposit',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlvDepositAmounts',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlvMarketAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlvTokenSupply',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlvWithdrawal',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyGlvWithdrawalAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyHoldingAddress',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyMarket',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyMarketPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'EmptyMarketTokenSupply',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyMultichainTransferInAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyMultichainTransferOutAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyOrder',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyPeer',
    type: 'error',
    inputs: [
      {
        internalType: 'uint32',
        type: 'uint32',
        name: 'eid'
      }
    ]
  },
  {
    name: 'EmptyPosition',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyPositionImpactWithdrawalAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyPrimaryPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyReceiver',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyReduceLentAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyRelayFeeAddress',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyShift',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyShiftAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptySizeDeltaInTokens',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyTarget',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyToken',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyTokenTranferGasLimit',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'EmptyValidatedPrices',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyWithdrawal',
    type: 'error',
    inputs: []
  },
  {
    name: 'EmptyWithdrawalAmount',
    type: 'error',
    inputs: []
  },
  {
    name: 'EndOfOracleSimulation',
    type: 'error',
    inputs: []
  },
  {
    name: 'EventItemNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'key'
      }
    ]
  },
  {
    name: 'ExternalCallFailed',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes',
        type: 'bytes',
        name: 'data'
      }
    ]
  },
  {
    name: 'FeeBatchNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'FeeDistributionAlreadyCompleted',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'lastDistributionTime'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'startOfCurrentWeek'
      }
    ]
  },
  {
    name: 'GlvAlreadyExists',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'salt'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      }
    ]
  },
  {
    name: 'GlvDepositNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'GlvDisabledMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvEnabledMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvInsufficientMarketTokenBalance',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketTokenBalance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketTokenAmount'
      }
    ]
  },
  {
    name: 'GlvInvalidLongToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'provided'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expected'
      }
    ]
  },
  {
    name: 'GlvInvalidShortToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'provided'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expected'
      }
    ]
  },
  {
    name: 'GlvMarketAlreadyExists',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvMaxMarketCountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'glvMaxMarketCount'
      }
    ]
  },
  {
    name: 'GlvMaxMarketTokenBalanceAmountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxMarketTokenBalanceAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketTokenBalanceAmount'
      }
    ]
  },
  {
    name: 'GlvMaxMarketTokenBalanceUsdExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxMarketTokenBalanceUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketTokenBalanceUsd'
      }
    ]
  },
  {
    name: 'GlvNameTooLong',
    type: 'error',
    inputs: []
  },
  {
    name: 'GlvNegativeMarketPoolValue',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvNonZeroMarketBalance',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'key'
      }
    ]
  },
  {
    name: 'GlvShiftIntervalNotYetPassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'lastGlvShiftExecutedAt'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'glvShiftMinInterval'
      }
    ]
  },
  {
    name: 'GlvShiftMaxLossExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'effectivePriceImpactFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'glvMaxShiftPriceImpactFactor'
      }
    ]
  },
  {
    name: 'GlvShiftNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'GlvSymbolTooLong',
    type: 'error',
    inputs: []
  },
  {
    name: 'GlvUnsupportedMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'glv'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'GlvWithdrawalNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'GmEmptySigner',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'signerIndex'
      }
    ]
  },
  {
    name: 'GmInvalidBlockNumber',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOracleBlockNumber'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentBlockNumber'
      }
    ]
  },
  {
    name: 'GmInvalidMinMaxBlockNumber',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOracleBlockNumber'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxOracleBlockNumber'
      }
    ]
  },
  {
    name: 'GmMaxOracleSigners',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'oracleSigners'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxOracleSigners'
      }
    ]
  },
  {
    name: 'GmMaxPricesNotSorted',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'price'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'prevPrice'
      }
    ]
  },
  {
    name: 'GmMaxSignerIndex',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'signerIndex'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxSignerIndex'
      }
    ]
  },
  {
    name: 'GmMinOracleSigners',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'oracleSigners'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOracleSigners'
      }
    ]
  },
  {
    name: 'GmMinPricesNotSorted',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'price'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'prevPrice'
      }
    ]
  },
  {
    name: 'InsufficientBuybackOutputAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'buybackToken'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'outputAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOutputAmount'
      }
    ]
  },
  {
    name: 'InsufficientCollateralAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'collateralAmount'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'collateralDeltaAmount'
      }
    ]
  },
  {
    name: 'InsufficientCollateralUsd',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'remainingCollateralUsd'
      }
    ]
  },
  {
    name: 'InsufficientExecutionFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minExecutionFee'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'executionFee'
      }
    ]
  },
  {
    name: 'InsufficientExecutionGas',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'startingGas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'estimatedGasLimit'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minAdditionalGasForExecution'
      }
    ]
  },
  {
    name: 'InsufficientExecutionGasForErrorHandling',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'startingGas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minHandleErrorGas'
      }
    ]
  },
  {
    name: 'InsufficientFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'feeProvided'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'feeRequired'
      }
    ]
  },
  {
    name: 'InsufficientFunds',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InsufficientFundsToPayForCosts',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'remainingCostUsd'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'step'
      }
    ]
  },
  {
    name: 'InsufficientGasForAutoCancellation',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'gas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minHandleExecutionErrorGas'
      }
    ]
  },
  {
    name: 'InsufficientGasForCancellation',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'gas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minHandleExecutionErrorGas'
      }
    ]
  },
  {
    name: 'InsufficientGasLeft',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'gas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'estimatedGasLimit'
      }
    ]
  },
  {
    name: 'InsufficientGasLeftForCallback',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'gasToBeForwarded'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'callbackGasLimit'
      }
    ]
  },
  {
    name: 'InsufficientHandleExecutionErrorGas',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'gas'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minHandleExecutionErrorGas'
      }
    ]
  },
  {
    name: 'InsufficientImpactPoolValueForWithdrawal',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'withdrawalAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolValue'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'totalPendingImpactAmount'
      }
    ]
  },
  {
    name: 'InsufficientMarketTokens',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expected'
      }
    ]
  },
  {
    name: 'InsufficientMultichainBalance',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amount'
      }
    ]
  },
  {
    name: 'InsufficientMultichainNativeFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'msgValue'
      }
    ]
  },
  {
    name: 'InsufficientNativeTokenAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'msgValue'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expectedNativeValue'
      }
    ]
  },
  {
    name: 'InsufficientOutputAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'outputAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOutputAmount'
      }
    ]
  },
  {
    name: 'InsufficientPoolAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amount'
      }
    ]
  },
  {
    name: 'InsufficientRelayFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'requiredRelayFee'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'availableFeeAmount'
      }
    ]
  },
  {
    name: 'InsufficientReserve',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'reservedUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxReservedUsd'
      }
    ]
  },
  {
    name: 'InsufficientReserveForOpenInterest',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'reservedUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxReservedUsd'
      }
    ]
  },
  {
    name: 'InsufficientSwapOutputAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'outputAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOutputAmount'
      }
    ]
  },
  {
    name: 'InsufficientWntAmountForExecutionFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'wntAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'executionFee'
      }
    ]
  },
  {
    name: 'InvalidAdl',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'nextPnlToPoolFactor'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'pnlToPoolFactor'
      }
    ]
  },
  {
    name: 'InvalidAmountInForFeeBatch',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amountIn'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'remainingAmount'
      }
    ]
  },
  {
    name: 'InvalidBaseKey',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'baseKey'
      }
    ]
  },
  {
    name: 'InvalidBlockRangeSet',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'largestMinBlockNumber'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'smallestMaxBlockNumber'
      }
    ]
  },
  {
    name: 'InvalidBridgeOutToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidBuybackToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'buybackToken'
      }
    ]
  },
  {
    name: 'InvalidCancellationReceiverForSubaccountOrder',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'cancellationReceiver'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedCancellationReceiver'
      }
    ]
  },
  {
    name: 'InvalidClaimableFactor',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'value'
      }
    ]
  },
  {
    name: 'InvalidClaimableReductionFactor',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'value'
      }
    ]
  },
  {
    name: 'InvalidClaimAffiliateRewardsInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      }
    ]
  },
  {
    name: 'InvalidClaimCollateralInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timeKeysLength'
      }
    ]
  },
  {
    name: 'InvalidClaimFundingFeesInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      }
    ]
  },
  {
    name: 'InvalidClaimTermsSignature',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'recoveredSigner'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedSigner'
      }
    ]
  },
  {
    name: 'InvalidClaimTermsSignatureForContract',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedSigner'
      }
    ]
  },
  {
    name: 'InvalidClaimUiFeesInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      }
    ]
  },
  {
    name: 'InvalidCollateralTokenForMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidContributorToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidDataStreamBidAsk',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'int192',
        type: 'int192',
        name: 'bid'
      },
      {
        internalType: 'int192',
        type: 'int192',
        name: 'ask'
      }
    ]
  },
  {
    name: 'InvalidDataStreamFeedId',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'feedId'
      },
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'expectedFeedId'
      }
    ]
  },
  {
    name: 'InvalidDataStreamPrices',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'int192',
        type: 'int192',
        name: 'bid'
      },
      {
        internalType: 'int192',
        type: 'int192',
        name: 'ask'
      }
    ]
  },
  {
    name: 'InvalidDataStreamSpreadReductionFactor',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'spreadReductionFactor'
      }
    ]
  },
  {
    name: 'InvalidDecreaseOrderSize',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeDeltaUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionSizeInUsd'
      }
    ]
  },
  {
    name: 'InvalidDecreasePositionSwapType',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'decreasePositionSwapType'
      }
    ]
  },
  {
    name: 'InvalidDestinationChainId',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'desChainId'
      }
    ]
  },
  {
    name: 'InvalidDistributionState',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'distributionStateUint'
      }
    ]
  },
  {
    name: 'InvalidEdgeDataStreamBidAsk',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'bid'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'ask'
      }
    ]
  },
  {
    name: 'InvalidEdgeDataStreamExpo',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'expo'
      }
    ]
  },
  {
    name: 'InvalidEdgeDataStreamPrices',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'bid'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'ask'
      }
    ]
  },
  {
    name: 'InvalidEdgeSignature',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'recoverError'
      }
    ]
  },
  {
    name: 'InvalidEdgeSigner',
    type: 'error',
    inputs: []
  },
  {
    name: 'InvalidEid',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'eid'
      }
    ]
  },
  {
    name: 'InvalidExecutionFee',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'executionFee'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minExecutionFee'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxExecutionFee'
      }
    ]
  },
  {
    name: 'InvalidExecutionFeeForMigration',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalExecutionFee'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'msgValue'
      }
    ]
  },
  {
    name: 'InvalidExternalCallInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'targetsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'dataListLength'
      }
    ]
  },
  {
    name: 'InvalidExternalCalls',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sendTokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sendAmountsLength'
      }
    ]
  },
  {
    name: 'InvalidExternalCallTarget',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'target'
      }
    ]
  },
  {
    name: 'InvalidExternalReceiversInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'refundTokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'refundReceiversLength'
      }
    ]
  },
  {
    name: 'InvalidFeeBatchTokenIndex',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokenIndex'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'feeBatchTokensLength'
      }
    ]
  },
  {
    name: 'InvalidFeedPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'price'
      }
    ]
  },
  {
    name: 'InvalidFeeReceiver',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      }
    ]
  },
  {
    name: 'InvalidGlpAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalGlpAmountToRedeem'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalGlpAmount'
      }
    ]
  },
  {
    name: 'InvalidGlvDepositInitialLongToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'initialLongToken'
      }
    ]
  },
  {
    name: 'InvalidGlvDepositInitialShortToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'initialShortToken'
      }
    ]
  },
  {
    name: 'InvalidGlvDepositSwapPath',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'longTokenSwapPathLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'shortTokenSwapPathLength'
      }
    ]
  },
  {
    name: 'InvalidGmMedianMinMaxPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPrice'
      }
    ]
  },
  {
    name: 'InvalidGmOraclePrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidGmSignature',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'recoveredSigner'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedSigner'
      }
    ]
  },
  {
    name: 'InvalidGmSignerMinMaxPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPrice'
      }
    ]
  },
  {
    name: 'InvalidHoldingAddress',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      }
    ]
  },
  {
    name: 'InvalidInitializer',
    type: 'error',
    inputs: []
  },
  {
    name: 'InvalidKeeperForFrozenOrder',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'keeper'
      }
    ]
  },
  {
    name: 'InvalidMarketTokenBalance',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expectedMinBalance'
      }
    ]
  },
  {
    name: 'InvalidMarketTokenBalanceForClaimableFunding',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'claimableFundingFeeAmount'
      }
    ]
  },
  {
    name: 'InvalidMarketTokenBalanceForCollateralAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'balance'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'collateralAmount'
      }
    ]
  },
  {
    name: 'InvalidMinGlvTokensForFirstGlvDeposit',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minGlvTokens'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expectedMinGlvTokens'
      }
    ]
  },
  {
    name: 'InvalidMinMarketTokensForFirstDeposit',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minMarketTokens'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expectedMinMarketTokens'
      }
    ]
  },
  {
    name: 'InvalidMinMaxForPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'min'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'max'
      }
    ]
  },
  {
    name: 'InvalidMultichainEndpoint',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'endpoint'
      }
    ]
  },
  {
    name: 'InvalidMultichainProvider',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'provider'
      }
    ]
  },
  {
    name: 'InvalidNativeTokenSender',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'msgSender'
      }
    ]
  },
  {
    name: 'InvalidOracleProvider',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'provider'
      }
    ]
  },
  {
    name: 'InvalidOracleProviderForToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'provider'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedProvider'
      }
    ]
  },
  {
    name: 'InvalidOracleSetPricesDataParam',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'dataLength'
      }
    ]
  },
  {
    name: 'InvalidOracleSetPricesProvidersParam',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'providersLength'
      }
    ]
  },
  {
    name: 'InvalidOracleSigner',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'signer'
      }
    ]
  },
  {
    name: 'InvalidOrderPrices',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'primaryPriceMin'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'primaryPriceMax'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'triggerPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'InvalidOutputToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'tokenOut'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedTokenOut'
      }
    ]
  },
  {
    name: 'InvalidParams',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'reason'
      }
    ]
  },
  {
    name: 'InvalidPermitSpender',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'spender'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedSpender'
      }
    ]
  },
  {
    name: 'InvalidPoolValueForDeposit',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'poolValue'
      }
    ]
  },
  {
    name: 'InvalidPoolValueForWithdrawal',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'poolValue'
      }
    ]
  },
  {
    name: 'InvalidPositionImpactPoolDistributionRate',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'distributionAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionImpactPoolAmount'
      }
    ]
  },
  {
    name: 'InvalidPositionMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'InvalidPositionSizeValues',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeInUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeInTokens'
      }
    ]
  },
  {
    name: 'InvalidPrimaryPricesForSimulation',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'primaryTokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'primaryPricesLength'
      }
    ]
  },
  {
    name: 'InvalidReceiver',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      }
    ]
  },
  {
    name: 'InvalidReceiverForFirstDeposit',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedReceiver'
      }
    ]
  },
  {
    name: 'InvalidReceiverForFirstGlvDeposit',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedReceiver'
      }
    ]
  },
  {
    name: 'InvalidReceiverForSubaccountOrder',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedReceiver'
      }
    ]
  },
  {
    name: 'InvalidRecoveredSigner',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'signatureType'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'recovered'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'recoveredFromMinified'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedSigner'
      }
    ]
  },
  {
    name: 'InvalidReferralRewardToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidSetContributorPaymentInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amountsLength'
      }
    ]
  },
  {
    name: 'InvalidSetMaxTotalContributorTokenAmountInput',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amountsLength'
      }
    ]
  },
  {
    name: 'InvalidSignature',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'signatureType'
      }
    ]
  },
  {
    name: 'InvalidSizeDeltaForAdl',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeDeltaUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionSizeInUsd'
      }
    ]
  },
  {
    name: 'InvalidSrcChainId',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'srcChainId'
      }
    ]
  },
  {
    name: 'InvalidSubaccountApprovalDesChainId',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'desChainId'
      }
    ]
  },
  {
    name: 'InvalidSubaccountApprovalNonce',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'storedNonce'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'nonce'
      }
    ]
  },
  {
    name: 'InvalidSubaccountApprovalSubaccount',
    type: 'error',
    inputs: []
  },
  {
    name: 'InvalidSwapMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'InvalidSwapOutputToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'outputToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedOutputToken'
      }
    ]
  },
  {
    name: 'InvalidSwapPathForV1',
    type: 'error',
    inputs: [
      {
        internalType: 'address[]',
        type: 'address[]',
        name: 'path'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'bridgingToken'
      }
    ]
  },
  {
    name: 'InvalidTimelockDelay',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timelockDelay'
      }
    ]
  },
  {
    name: 'InvalidToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'InvalidTokenIn',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'tokenIn'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'InvalidTransferRequestsLength',
    type: 'error',
    inputs: []
  },
  {
    name: 'InvalidTrustedSignerAddress',
    type: 'error',
    inputs: []
  },
  {
    name: 'InvalidUiFeeFactor',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'uiFeeFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxUiFeeFactor'
      }
    ]
  },
  {
    name: 'InvalidUserDigest',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'digest'
      }
    ]
  },
  {
    name: 'InvalidVersion',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'version'
      }
    ]
  },
  {
    name: 'JitEmptyShiftParams',
    type: 'error',
    inputs: []
  },
  {
    name: 'JitInvalidToMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedMarket'
      }
    ]
  },
  {
    name: 'JitUnsupportedOrderType',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'KeeperAmountMismatch',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'wntForKeepers'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'wntToKeepers'
      }
    ]
  },
  {
    name: 'KeeperArrayLengthMismatch',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'keepersLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'keeperTargetBalancesLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'keeperVersionsLength'
      }
    ]
  },
  {
    name: 'LiquidatablePosition',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'reason'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'remainingCollateralUsd'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'minCollateralUsd'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'minCollateralUsdForLeverage'
      }
    ]
  },
  {
    name: 'LongTokensAreNotEqual',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'fromMarketLongToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'toMarketLongToken'
      }
    ]
  },
  {
    name: 'MarketAlreadyExists',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'salt'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'existingMarketAddress'
      }
    ]
  },
  {
    name: 'MarketNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'key'
      }
    ]
  },
  {
    name: 'MaskIndexOutOfBounds',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'index'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'label'
      }
    ]
  },
  {
    name: 'MaxAutoCancelOrdersExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'count'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxAutoCancelOrders'
      }
    ]
  },
  {
    name: 'MaxBuybackPriceAgeExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'priceTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'buybackMaxPriceAge'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      }
    ]
  },
  {
    name: 'MaxCallbackGasLimitExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'callbackGasLimit'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxCallbackGasLimit'
      }
    ]
  },
  {
    name: 'MaxCollateralSumExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'collateralSum'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxCollateralSum'
      }
    ]
  },
  {
    name: 'MaxDataListLengthExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'dataLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxDataLength'
      }
    ]
  },
  {
    name: 'MaxEsGmxReferralRewardsAmountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensForReferralRewards'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxEsGmxReferralRewards'
      }
    ]
  },
  {
    name: 'MaxFundingFactorPerSecondLimitExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxFundingFactorPerSecond'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'limit'
      }
    ]
  },
  {
    name: 'MaxLendableFactorForWithdrawalsExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxLendableUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'lentUsd'
      }
    ]
  },
  {
    name: 'MaxOpenInterestExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'openInterest'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxOpenInterest'
      }
    ]
  },
  {
    name: 'MaxOracleTimestampRangeExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'range'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxRange'
      }
    ]
  },
  {
    name: 'MaxPoolAmountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPoolAmount'
      }
    ]
  },
  {
    name: 'MaxPoolUsdForDepositExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPoolUsdForDeposit'
      }
    ]
  },
  {
    name: 'MaxPriceAgeExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'oracleTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      }
    ]
  },
  {
    name: 'MaxReferralRewardsExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'cumulativeTransferAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensForReferralRewards'
      }
    ]
  },
  {
    name: 'MaxRefPriceDeviationExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'price'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'refPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxRefPriceDeviationFactor'
      }
    ]
  },
  {
    name: 'MaxRelayFeeSwapForSubaccountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'feeUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxFeeUsd'
      }
    ]
  },
  {
    name: 'MaxSubaccountActionCountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'subaccount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'count'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxCount'
      }
    ]
  },
  {
    name: 'MaxSwapPathLengthExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'swapPathLengh'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxSwapPathLength'
      }
    ]
  },
  {
    name: 'MaxTimelockDelayExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timelockDelay'
      }
    ]
  },
  {
    name: 'MaxTotalCallbackGasLimitForAutoCancelOrdersExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalCallbackGasLimit'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxTotalCallbackGasLimit'
      }
    ]
  },
  {
    name: 'MaxTotalContributorTokenAmountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxTotalAmount'
      }
    ]
  },
  {
    name: 'MaxWntFromTreasuryExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxWntFromTreasury'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'additionalWntFromTreasury'
      }
    ]
  },
  {
    name: 'MaxWntReferralRewardsInUsdAmountExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'wntReferralRewardsInUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxWntReferralRewardsInUsdAmount'
      }
    ]
  },
  {
    name: 'MaxWntReferralRewardsInUsdExceeded',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'wntReferralRewardsInUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxWntReferralRewardsInUsd'
      }
    ]
  },
  {
    name: 'MinContributorPaymentIntervalBelowAllowedRange',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'interval'
      }
    ]
  },
  {
    name: 'MinContributorPaymentIntervalNotYetPassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPaymentInterval'
      }
    ]
  },
  {
    name: 'MinGlvTokens',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'received'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expected'
      }
    ]
  },
  {
    name: 'MinLongTokens',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'received'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expected'
      }
    ]
  },
  {
    name: 'MinMarketTokens',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'received'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expected'
      }
    ]
  },
  {
    name: 'MinPositionSize',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionSizeInUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPositionSizeUsd'
      }
    ]
  },
  {
    name: 'MinShortTokens',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'received'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expected'
      }
    ]
  },
  {
    name: 'NegativeExecutionPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'executionPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'price'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionSizeInUsd'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'priceImpactUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeDeltaUsd'
      }
    ]
  },
  {
    name: 'NonAtomicOracleProvider',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'provider'
      }
    ]
  },
  {
    name: 'NonEmptyExternalCallsForSubaccountOrder',
    type: 'error',
    inputs: []
  },
  {
    name: 'NonEmptyTokensWithPrices',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'tokensWithPricesLength'
      }
    ]
  },
  {
    name: 'OpenInterestCannotBeUpdatedForSwapOnlyMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'OraclePriceOutdated',
    type: 'error',
    inputs: []
  },
  {
    name: 'OracleProviderAlreadyExistsForToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'oracle'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'OracleProviderMinChangeDelayNotYetPassed',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'provider'
      }
    ]
  },
  {
    name: 'OracleTimestampsAreLargerThanRequestExpirationTime',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxOracleTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'requestTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'requestExpirationTime'
      }
    ]
  },
  {
    name: 'OracleTimestampsAreSmallerThanRequired',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minOracleTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'expectedTimestamp'
      }
    ]
  },
  {
    name: 'OrderAlreadyFrozen',
    type: 'error',
    inputs: []
  },
  {
    name: 'OrderNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'OrderNotFulfillableAtAcceptablePrice',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'price'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'acceptablePrice'
      }
    ]
  },
  {
    name: 'OrderNotUpdatable',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'OrderTypeCannotBeCreated',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'OrderValidFromTimeNotReached',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'validFromTime'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      }
    ]
  },
  {
    name: 'OutdatedReadResponse',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timestamp'
      }
    ]
  },
  {
    name: 'PnlFactorExceededForLongs',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'pnlToPoolFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPnlFactor'
      }
    ]
  },
  {
    name: 'PnlFactorExceededForShorts',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'pnlToPoolFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPnlFactor'
      }
    ]
  },
  {
    name: 'PnlOvercorrected',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'nextPnlToPoolFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPnlFactorForAdl'
      }
    ]
  },
  {
    name: 'PositionNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'PositionShouldNotBeLiquidated',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'reason'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'remainingCollateralUsd'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'minCollateralUsd'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'minCollateralUsdForLeverage'
      }
    ]
  },
  {
    name: 'PriceAlreadySet',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'minPrice'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'maxPrice'
      }
    ]
  },
  {
    name: 'PriceFeedAlreadyExistsForToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      }
    ]
  },
  {
    name: 'PriceImpactLargerThanOrderSize',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'priceImpactUsd'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sizeDeltaUsd'
      }
    ]
  },
  {
    name: 'ReductionExceedsLentAmount',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'lentAmount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'totalReductionAmount'
      }
    ]
  },
  {
    name: 'ReferralCodeAlreadyExists',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'code'
      }
    ]
  },
  {
    name: 'RelayCalldataTooLong',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'calldataLength'
      }
    ]
  },
  {
    name: 'RelayEmptyBatch',
    type: 'error',
    inputs: []
  },
  {
    name: 'RemovalShouldNotBeSkipped',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'listKey'
      },
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'entityKey'
      }
    ]
  },
  {
    name: 'RequestNotYetCancellable',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'requestAge'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'requestExpirationAge'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'requestType'
      }
    ]
  },
  {
    name: 'SelfTransferNotSupported',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      }
    ]
  },
  {
    name: 'SendEthToKeeperFailed',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'keeper'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sendAmount'
      },
      {
        internalType: 'bytes',
        type: 'bytes',
        name: 'result'
      }
    ]
  },
  {
    name: 'SequencerDown',
    type: 'error',
    inputs: []
  },
  {
    name: 'SequencerGraceDurationNotYetPassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'timeSinceUp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'sequencerGraceDuration'
      }
    ]
  },
  {
    name: 'ShiftFromAndToMarketAreEqual',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'ShiftNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'ShortTokensAreNotEqual',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'fromMarketLongToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'toMarketLongToken'
      }
    ]
  },
  {
    name: 'SignalTimeNotYetPassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'signalTime'
      }
    ]
  },
  {
    name: 'SubaccountApprovalDeadlinePassed',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'deadline'
      }
    ]
  },
  {
    name: 'SubaccountApprovalExpired',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'subaccount'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'deadline'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'currentTimestamp'
      }
    ]
  },
  {
    name: 'SubaccountIntegrationIdDisabled',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'integrationId'
      }
    ]
  },
  {
    name: 'SubaccountNotAuthorized',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'account'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'subaccount'
      }
    ]
  },
  {
    name: 'SwapPriceImpactExceedsAmountIn',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amountAfterFees'
      },
      {
        internalType: 'int256',
        type: 'int256',
        name: 'negativeImpactAmount'
      }
    ]
  },
  {
    name: 'SwapsNotAllowedForAtomicWithdrawal',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'longTokenSwapPathLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'shortTokenSwapPathLength'
      }
    ]
  },
  {
    name: 'SyncConfigInvalidInputLengths',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'marketsLength'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'parametersLength'
      }
    ]
  },
  {
    name: 'SyncConfigInvalidMarketFromData',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'marketFromData'
      }
    ]
  },
  {
    name: 'SyncConfigUpdatesDisabledForMarket',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'SyncConfigUpdatesDisabledForMarketParameter',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'parameter'
      }
    ]
  },
  {
    name: 'SyncConfigUpdatesDisabledForParameter',
    type: 'error',
    inputs: [
      {
        internalType: 'string',
        type: 'string',
        name: 'parameter'
      }
    ]
  },
  {
    name: 'ThereMustBeAtLeastOneRoleAdmin',
    type: 'error',
    inputs: []
  },
  {
    name: 'ThereMustBeAtLeastOneTimelockMultiSig',
    type: 'error',
    inputs: []
  },
  {
    name: 'TokenPermitsNotAllowedForMultichain',
    type: 'error',
    inputs: []
  },
  {
    name: 'TokenTransferError',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'receiver'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'amount'
      }
    ]
  },
  {
    name: 'Uint256AsBytesLengthExceeds32Bytes',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'length'
      }
    ]
  },
  {
    name: 'UnableToGetBorrowingFactorEmptyPoolUsd',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnableToGetCachedTokenPrice',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'UnableToGetFundingFactorEmptyOpenInterest',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnableToGetOppositeToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'inputToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'UnableToPayOrderFee',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnableToPayOrderFeeFromCollateral',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnableToWithdrawCollateral',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'estimatedRemainingCollateralUsd'
      }
    ]
  },
  {
    name: 'Unauthorized',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'msgSender'
      },
      {
        internalType: 'string',
        type: 'string',
        name: 'role'
      }
    ]
  },
  {
    name: 'UnexpectedBorrowingFactor',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'positionBorrowingFactor'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'cumulativeBorrowingFactor'
      }
    ]
  },
  {
    name: 'UnexpectedMarket',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnexpectedPoolValue',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'poolValue'
      }
    ]
  },
  {
    name: 'UnexpectedPositionState',
    type: 'error',
    inputs: []
  },
  {
    name: 'UnexpectedRelayFeeToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedFeeToken'
      }
    ]
  },
  {
    name: 'UnexpectedRelayFeeTokenAfterSwap',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedFeeToken'
      }
    ]
  },
  {
    name: 'UnexpectedTokenForVirtualInventory',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'token'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'market'
      }
    ]
  },
  {
    name: 'UnexpectedValidFromTime',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'UnsupportedOrderType',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'UnsupportedOrderTypeForAutoCancellation',
    type: 'error',
    inputs: [
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'orderType'
      }
    ]
  },
  {
    name: 'UnsupportedRelayFeeToken',
    type: 'error',
    inputs: [
      {
        internalType: 'address',
        type: 'address',
        name: 'feeToken'
      },
      {
        internalType: 'address',
        type: 'address',
        name: 'expectedFeeToken'
      }
    ]
  },
  {
    name: 'UsdDeltaExceedsLongOpenInterest',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'usdDelta'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'longOpenInterest'
      }
    ]
  },
  {
    name: 'UsdDeltaExceedsPoolValue',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'usdDelta'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'poolUsd'
      }
    ]
  },
  {
    name: 'UsdDeltaExceedsShortOpenInterest',
    type: 'error',
    inputs: [
      {
        internalType: 'int256',
        type: 'int256',
        name: 'usdDelta'
      },
      {
        internalType: 'uint256',
        type: 'uint256',
        name: 'shortOpenInterest'
      }
    ]
  },
  {
    name: 'WithdrawalNotFound',
    type: 'error',
    inputs: [
      {
        internalType: 'bytes32',
        type: 'bytes32',
        name: 'key'
      }
    ]
  },
  {
    name: 'ZeroTreasuryAddress',
    type: 'error',
    inputs: []
  }
] as const
