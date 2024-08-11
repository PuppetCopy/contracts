# RevenueLogic
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/RevenueLogic.sol)

**Inherits:**
Permission, EIP712, ReentrancyGuardTransient

*buyback functionality where the protocol publicly offers to buy back Protocol tokens using accumulated ETH fees once a predefined threshold is
reached. This incentivizes participants to sell tokens for whitelisted revenue tokens without relying on price oracles per revenue token.*


## State Variables
### store

```solidity
RevenueStore immutable store;
```


### buybackToken

```solidity
IERC20 immutable buybackToken;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, IERC20 _buybackToken, RevenueStore _store) Permission(_authority) EIP712("Revenue Logic", "1");
```

### getRevenueBalance


```solidity
function getRevenueBalance(IERC20 token) external view returns (uint);
```

### buybackRevenue


```solidity
function buybackRevenue(address source, address depositor, address reciever, IERC20 revenueToken, uint amount) external auth;
```

## Events
### RewardLogic__Buyback

```solidity
event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);
```

## Errors
### RewardLogic__InvalidClaimToken

```solidity
error RewardLogic__InvalidClaimToken();
```

