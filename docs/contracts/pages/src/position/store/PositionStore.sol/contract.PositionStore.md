# PositionStore
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/store/PositionStore.sol)

**Inherits:**
BankStore


## State Variables
### requestAdjustmentMap

```solidity
mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
```


### requestMatchMap

```solidity
mapping(bytes32 positionKey => RequestMatch) public requestMatchMap;
```


### positionMap

```solidity
mapping(bytes32 positionKey => MirrorPosition) public positionMap;
```


### unhandledCallbackMap

```solidity
mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, Router _router) BankStore(_authority, _router);
```

### getRequestAdjustment


```solidity
function getRequestAdjustment(bytes32 _key) external view returns (RequestAdjustment memory);
```

### setRequestAdjustment


```solidity
function setRequestAdjustment(bytes32 _key, RequestAdjustment calldata _ra) external auth;
```

### removeRequestAdjustment


```solidity
function removeRequestAdjustment(bytes32 _key) external auth;
```

### getRequestMatch


```solidity
function getRequestMatch(bytes32 _key) external view returns (RequestMatch memory);
```

### setRequestMatch


```solidity
function setRequestMatch(bytes32 _key, RequestMatch calldata _rm) external auth;
```

### removeRequestMatch


```solidity
function removeRequestMatch(bytes32 _key) external auth;
```

### removeRequestDecrease


```solidity
function removeRequestDecrease(bytes32 _key) external auth;
```

### getMirrorPosition


```solidity
function getMirrorPosition(bytes32 _key) external view returns (MirrorPosition memory);
```

### setMirrorPosition


```solidity
function setMirrorPosition(bytes32 _key, MirrorPosition calldata _mp) external auth;
```

### removeMirrorPosition


```solidity
function removeMirrorPosition(bytes32 _key) external auth;
```

### setUnhandledCallback


```solidity
function setUnhandledCallback(
    GmxPositionUtils.OrderExecutionStatus _status,
    GmxPositionUtils.Props calldata _order,
    bytes32 _key,
    bytes calldata _eventData
) external auth;
```

### getUnhandledCallback


```solidity
function getUnhandledCallback(bytes32 _key) external view returns (UnhandledCallback memory);
```

### removeUnhandledCallback


```solidity
function removeUnhandledCallback(bytes32 _key) external auth;
```

## Structs
### RequestMatch

```solidity
struct RequestMatch {
    address trader;
    address[] puppetList;
}
```

### RequestAdjustment

```solidity
struct RequestAdjustment {
    uint[] puppetCollateralDeltaList;
    uint sizeDelta;
    uint collateralDelta;
    uint transactionCost;
}
```

### MirrorPosition

```solidity
struct MirrorPosition {
    address trader;
    address[] puppetList;
    uint[] collateralList;
    uint size;
    uint collateral;
    uint cumulativeTransactionCost;
}
```

### UnhandledCallback

```solidity
struct UnhandledCallback {
    GmxPositionUtils.OrderExecutionStatus status;
    GmxPositionUtils.Props order;
    bytes eventData;
}
```

