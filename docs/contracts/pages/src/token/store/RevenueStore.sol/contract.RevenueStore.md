# RevenueStore
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/store/RevenueStore.sol)

**Inherits:**
BankStore


## State Variables
### tokenPerContributionCursorMap

```solidity
mapping(IERC20 => uint) tokenPerContributionCursorMap;
```


### tokenBuybackOfferMap

```solidity
mapping(IERC20 => uint) tokenBuybackOfferMap;
```


### userTokenPerContributionMap

```solidity
mapping(IERC20 token => mapping(address user => uint)) userTokenPerContributionMap;
```


### userContributionBalanceMap

```solidity
mapping(IERC20 => mapping(address => uint)) userContributionBalanceMap;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, Router _router, IERC20[] memory _tokenBuybackThresholdList, uint[] memory _tokenBuybackThresholdAmountList)
    BankStore(_authority, _router);
```

### increaseTokenPerContributionCursor


```solidity
function increaseTokenPerContributionCursor(IERC20 _token, uint _value) external auth returns (uint);
```

### getTokenPerContributionCursor


```solidity
function getTokenPerContributionCursor(IERC20 _token) external view returns (uint);
```

### getTokenBuybackOffer


```solidity
function getTokenBuybackOffer(IERC20 _token) external view returns (uint);
```

### setTokenBuybackOffer


```solidity
function setTokenBuybackOffer(IERC20 _token, uint _value) external auth;
```

### getUserContributionBalance


```solidity
function getUserContributionBalance(IERC20 _token, address _user) external view returns (uint);
```

### setUserContributionBalance


```solidity
function setUserContributionBalance(IERC20 _token, address _user, uint _value) external auth;
```

### commitReward


```solidity
function commitReward(IERC20 _token, address _source, address _user, uint _value) external auth;
```

### commitRewardList


```solidity
function commitRewardList(
    IERC20 _token,
    address _source,
    address[] calldata _userList,
    uint[] calldata _valueList,
    address _trader,
    uint _performanceFee
) external auth;
```

### getUserTokenPerContributionCursor


```solidity
function getUserTokenPerContributionCursor(IERC20 _token, address _user) external view returns (uint);
```

### setUserTokenPerContributionCursor


```solidity
function setUserTokenPerContributionCursor(IERC20 _token, address _user, uint _amount) external auth;
```

### transferOut


```solidity
function transferOut(IERC20 _token, address _receiver, uint _value) external auth;
```

### transferIn


```solidity
function transferIn(IERC20 _token, address _depositor, uint _value) external auth;
```

## Errors
### RewardStore__InvalidLength

```solidity
error RewardStore__InvalidLength();
```

