# ExecuteDecreasePosition
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/logic/ExecuteDecreasePosition.sol)


## Functions
### decrease


```solidity
function decrease(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external;
```

### _decrease


```solidity
function _decrease(
    CallConfig calldata callConfig,
    GmxPositionUtils.Props calldata order,
    CallParams memory callParams,
    PositionStore.RequestAdjustment memory request
) internal;
```

### getDistribution


```solidity
function getDistribution(uint performanceFeeRate, uint traderPerformanceFeeShare, uint totalProfit, uint amountOut, uint totalAmountOut)
    internal
    pure
    returns (uint performanceFee, uint traderPerformanceCutoffFee, uint amountOutAfterFee);
```

## Events
### ExecuteDecreasePosition__DecreasePosition

```solidity
event ExecuteDecreasePosition__DecreasePosition(
    bytes32 requestKey, bytes32 positionKey, uint totalAmountOut, uint profit, uint totalPerformanceFee, uint traderPerformanceCutoffFee
);
```

## Errors
### ExecutePosition__InvalidRequest

```solidity
error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
```

### ExecutePosition__UnexpectedEventData

```solidity
error ExecutePosition__UnexpectedEventData();
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    Router router;
    PositionStore positionStore;
    PuppetStore puppetStore;
    RevenueStore revenueStore;
    address gmxOrderReciever;
    uint performanceFeeRate;
    uint traderPerformanceFeeShare;
}
```

### CallParams

```solidity
struct CallParams {
    PositionStore.MirrorPosition mirrorPosition;
    bytes32 positionKey;
    bytes32 requestKey;
    address positionRouterAddress;
    IERC20 outputToken;
    uint puppetListLength;
    uint totalAmountOut;
    uint profit;
}
```

