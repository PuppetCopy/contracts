# ExecuteIncreasePosition
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/logic/ExecuteIncreasePosition.sol)


## Functions
### increase


```solidity
function increase(CallConfig memory callConfig, bytes32 key, GmxPositionUtils.Props memory order) external;
```

## Errors
### ExecuteIncreasePosition__UnauthorizedCaller

```solidity
error ExecuteIncreasePosition__UnauthorizedCaller();
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    PositionStore positionStore;
    address gmxOrderHandler;
}
```

