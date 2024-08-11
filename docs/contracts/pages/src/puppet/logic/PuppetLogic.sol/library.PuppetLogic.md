# PuppetLogic
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/puppet/logic/PuppetLogic.sol)


## Functions
### deposit


```solidity
function deposit(PuppetStore store, IERC20 token, address user, uint amount) internal;
```

### withdraw


```solidity
function withdraw(PuppetStore store, IERC20 token, address user, address receiver, uint amount) internal;
```

### setRule


```solidity
function setRule(
    PuppetStore store,
    CallSetRuleConfig memory callConfig,
    IERC20 collateralToken,
    address puppet,
    address trader,
    PuppetStore.Rule calldata ruleParams
) internal;
```

### setRuleList


```solidity
function setRuleList(
    PuppetStore store,
    CallSetRuleConfig memory callConfig,
    address puppet,
    address[] calldata traderList,
    IERC20[] calldata collateralTokenList,
    PuppetStore.Rule[] calldata ruleParams
) internal;
```

### _setRule


```solidity
function _setRule(CallSetRuleConfig memory callConfig, PuppetStore.Rule memory storedRule, PuppetStore.Rule calldata ruleParams)
    internal
    view
    returns (PuppetStore.Rule memory);
```

### isArrayContains


```solidity
function isArrayContains(IERC20[] memory array, IERC20 value) public pure returns (bool);
```

### _validatePuppetTokenAllowanceList


```solidity
function _validatePuppetTokenAllowanceList(PuppetStore store, IERC20[] memory tokenList, address puppet) internal view;
```

### _validatePuppetTokenAllowance


```solidity
function _validatePuppetTokenAllowance(PuppetStore store, IERC20 token, address puppet) internal view returns (uint);
```

## Events
### PuppetLogic__SetRule

```solidity
event PuppetLogic__SetRule(bytes32 ruleKey, PuppetStore.Rule rule);
```

### PuppetLogic__Deposit

```solidity
event PuppetLogic__Deposit(IERC20 token, address user, uint amount);
```

### PuppetLogic__Withdraw

```solidity
event PuppetLogic__Withdraw(IERC20 token, address user, uint amount);
```

## Errors
### PuppetLogic__InvalidAllowanceRate

```solidity
error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
```

### PuppetLogic__ExpiredDate

```solidity
error PuppetLogic__ExpiredDate();
```

### PuppetLogic__NotFound

```solidity
error PuppetLogic__NotFound();
```

### PuppetLogic__TokenNotAllowed

```solidity
error PuppetLogic__TokenNotAllowed();
```

### PuppetLogic__AllowanceAboveLimit

```solidity
error PuppetLogic__AllowanceAboveLimit(uint allowanceCap);
```

### PuppetLogic__InvalidAmount

```solidity
error PuppetLogic__InvalidAmount();
```

### PuppetLogic__InsufficientBalance

```solidity
error PuppetLogic__InsufficientBalance();
```

## Structs
### CallSetRuleConfig

```solidity
struct CallSetRuleConfig {
    Router router;
    uint minExpiryDuration;
    uint minAllowanceRate;
    uint maxAllowanceRate;
}
```

