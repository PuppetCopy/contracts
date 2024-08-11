# RequestIncreasePosition
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/logic/RequestIncreasePosition.sol)


## Functions
### proxyIncrease


```solidity
function proxyIncrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams, address[] calldata puppetList)
    internal;
```

### traderIncrease


```solidity
function traderIncrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams, address[] calldata puppetList)
    internal;
```

### increase


```solidity
function increase(
    CallConfig memory callConfig,
    PositionStore.RequestAdjustment memory request,
    PositionUtils.TraderCallParams calldata traderCallParams,
    address[] calldata puppetList
) internal;
```

### matchUp


```solidity
function matchUp(
    CallConfig memory callConfig,
    PositionStore.RequestAdjustment memory request,
    MatchCallParams memory callParams,
    PositionUtils.TraderCallParams calldata traderCallParams,
    address[] calldata puppetList
) internal;
```

### adjust


```solidity
function adjust(
    CallConfig memory callConfig,
    PositionStore.RequestAdjustment memory request,
    PositionStore.MirrorPosition memory mirrorPosition,
    AdjustCallParams memory callParams,
    PositionUtils.TraderCallParams calldata traderCallParams
) internal;
```

### _createOrder


```solidity
function _createOrder(
    CallConfig memory callConfig,
    PositionStore.RequestAdjustment memory request,
    PositionUtils.TraderCallParams calldata traderCallParams,
    address subaccountAddress,
    bytes32 positionKey
) internal returns (bytes32 requestKey);
```

### _reducePuppetSizeDelta


```solidity
function _reducePuppetSizeDelta(
    CallConfig memory callConfig,
    PositionUtils.TraderCallParams calldata traderCallParams,
    address subaccountAddress,
    uint puppetReduceSizeDelta
) internal returns (bytes32 requestKey);
```

## Events
### RequestIncreasePosition__Match

```solidity
event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 positionKey, bytes32 requestKey, address[] puppetList);
```

### RequestIncreasePosition__Request

```solidity
event RequestIncreasePosition__Request(
    PositionStore.RequestAdjustment request,
    address subaccount,
    bytes32 positionKey,
    bytes32 requestKey,
    uint sizeDelta,
    uint collateralDelta,
    uint[] puppetCollateralDeltaList
);
```

### RequestIncreasePosition__RequestReducePuppetSize

```solidity
event RequestIncreasePosition__RequestReducePuppetSize(
    address trader, address subaccount, bytes32 requestKey, bytes32 reduceRequestKey, uint sizeDelta
);
```

## Errors
### RequestIncreasePosition__PuppetListLimitExceeded

```solidity
error RequestIncreasePosition__PuppetListLimitExceeded();
```

### RequestIncreasePosition__MatchRequestPending

```solidity
error RequestIncreasePosition__MatchRequestPending();
```

### RequestIncreasePosition__UnsortedPuppetList

```solidity
error RequestIncreasePosition__UnsortedPuppetList();
```

### RequestIncreasePosition__DuplicatesInPuppetList

```solidity
error RequestIncreasePosition__DuplicatesInPuppetList();
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    IWNT wnt;
    IGmxExchangeRouter gmxExchangeRouter;
    Router router;
    SubaccountStore subaccountStore;
    PositionStore positionStore;
    PuppetStore puppetStore;
    address gmxOrderReciever;
    address gmxOrderVault;
    bytes32 referralCode;
    uint callbackGasLimit;
    uint limitPuppetList;
    uint minimumMatchAmount;
    uint tokenTransferGasLimit;
}
```

### MatchCallParams

```solidity
struct MatchCallParams {
    address subaccountAddress;
    bytes32 positionKey;
    PuppetStore.Rule[] ruleList;
    uint[] activityList;
    uint[] balanceList;
    uint puppetLength;
    uint sizeDeltaMultiplier;
}
```

### AdjustCallParams

```solidity
struct AdjustCallParams {
    address subaccountAddress;
    bytes32 positionKey;
    PuppetStore.Rule[] ruleList;
    uint[] activityList;
    uint[] depositList;
    uint puppetLength;
    uint sizeDeltaMultiplier;
    uint mpLeverage;
    uint mpTargetLeverage;
    uint puppetReduceSizeDelta;
}
```

