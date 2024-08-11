# PuppetRouter
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/puppet/PuppetRouter.sol)

**Inherits:**
Auth, EIP712, ReentrancyGuardTransient


## State Variables
### callConfig

```solidity
CallConfig callConfig;
```


### store

```solidity
PuppetStore store;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, PuppetStore _store, CallConfig memory _callConfig) Auth(_authority) EIP712("Puppet Router", "1");
```

### deposit


```solidity
function deposit(IERC20 token, uint amount) external nonReentrant;
```

### withdraw


```solidity
function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant;
```

### setRule


```solidity
function setRule(IERC20 collateralToken, address trader, PuppetStore.Rule calldata ruleParams) external nonReentrant;
```

### setRuleList


```solidity
function setRuleList(PuppetStore.Rule[] calldata ruleParams, address[] calldata traderList, IERC20[] calldata collateralTokenList)
    external
    nonReentrant;
```

### setConfig


```solidity
function setConfig(CallConfig memory _callConfig) external auth;
```

### _setConfig


```solidity
function _setConfig(CallConfig memory _callConfig) internal;
```

## Events
### PuppetRouter__SetConfig

```solidity
event PuppetRouter__SetConfig(uint timestamp, CallConfig callConfig);
```

## Errors
### PuppetRouter__InvalidPuppet

```solidity
error PuppetRouter__InvalidPuppet();
```

### PuppetRouter__InvalidAllowance

```solidity
error PuppetRouter__InvalidAllowance();
```

## Structs
### CallConfig

```solidity
struct CallConfig {
    PuppetLogic.CallSetRuleConfig setRule;
}
```

