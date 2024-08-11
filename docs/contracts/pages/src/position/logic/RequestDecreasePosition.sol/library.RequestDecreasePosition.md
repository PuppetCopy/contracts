# RequestDecreasePosition
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/position/logic/RequestDecreasePosition.sol)


## Functions
### traderDecrease


```solidity
function traderDecrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams) internal;
```

### proxyDecrease


```solidity
function proxyDecrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams) internal;
```

### decrease


```solidity
function decrease(
    CallConfig memory callConfig,
    PositionStore.RequestAdjustment memory request,
    PositionStore.MirrorPosition memory mirrorPosition,
    PositionUtils.TraderCallParams calldata traderCallParams,
    Subaccount subaccount,
    address subaccountAddress
) internal;
```

## Events
### RequestDecreasePosition__Request

```solidity
event RequestDecreasePosition__Request(
    PositionStore.RequestAdjustment request, address subaccount, bytes32 requestKey, uint traderSizeDelta, uint traderCollateralDelta
);
```

## Errors
### RequestDecreasePosition__SubaccountNotFound

```solidity
error RequestDecreasePosition__SubaccountNotFound(address user);
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    IWNT wnt;
    IGmxExchangeRouter gmxExchangeRouter;
    PositionStore positionStore;
    SubaccountStore subaccountStore;
    address gmxOrderReciever;
    address gmxOrderVault;
    bytes32 referralCode;
    uint callbackGasLimit;
}
```

