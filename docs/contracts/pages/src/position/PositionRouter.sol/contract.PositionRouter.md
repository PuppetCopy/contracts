# PositionRouter
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/PositionRouter.sol)

**Inherits:**
Permission, EIP712, ReentrancyGuardTransient, IGmxOrderCallbackReceiver


## State Variables
### callConfig

```solidity
CallConfig callConfig;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("Position Router", "1");
```

### requestIncrease


```solidity
function requestIncrease(PositionUtils.TraderCallParams calldata traderCallParams, address[] calldata puppetList) external payable nonReentrant;
```

### requestDecrease


```solidity
function requestDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external payable nonReentrant;
```

### afterOrderExecution


```solidity
function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth;
```

### afterOrderCancellation


```solidity
function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth;
```

### afterOrderFrozen


```solidity
function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth;
```

### proxyRequestIncrease


```solidity
function proxyRequestIncrease(PositionUtils.TraderCallParams calldata traderCallParams, address[] calldata puppetList) external payable auth;
```

### proxyRequestDecrease


```solidity
function proxyRequestDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external payable auth;
```

### executeUnhandledExecutionCallback


```solidity
function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant auth;
```

### setConfig


```solidity
function setConfig(CallConfig memory _callConfig) external auth;
```

### storeUnhandledCallback


```solidity
function storeUnhandledCallback(
    GmxPositionUtils.OrderExecutionStatus status,
    GmxPositionUtils.Props calldata order,
    bytes32 key,
    bytes calldata eventData
) internal auth;
```

### _setConfig


```solidity
function _setConfig(CallConfig memory _callConfig) internal;
```

## Events
### PositionRouter__SetConfig

```solidity
event PositionRouter__SetConfig(uint timestamp, CallConfig callConfig);
```

### PositionRouter__UnhandledCallback

```solidity
event PositionRouter__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData);
```

## Errors
### PositionRouter__InvalidOrderType

```solidity
error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
```

### PositionRouter__SenderNotMatchingTrader

```solidity
error PositionRouter__SenderNotMatchingTrader();
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    RequestIncreasePosition.CallConfig increase;
    RequestDecreasePosition.CallConfig decrease;
    ExecuteIncreasePosition.CallConfig executeIncrease;
    ExecuteDecreasePosition.CallConfig executeDecrease;
}
```

