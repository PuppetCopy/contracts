# RewardStore
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/store/RewardStore.sol)

**Inherits:**
Auth


## State Variables
### userEmissionRewardMap

```solidity
mapping(IERC20 token => mapping(address user => UserEmissionCursor)) userEmissionRewardMap;
```


### tokenEmissionRewardPerTokenCursorMap

```solidity
mapping(IERC20 => uint) tokenEmissionRewardPerTokenCursorMap;
```


### tokenEmissionRateMap

```solidity
mapping(IERC20 => uint) tokenEmissionRateMap;
```


### tokenEmissionTimestampMap

```solidity
mapping(IERC20 => uint) tokenEmissionTimestampMap;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, Router _router) Auth(_authority);
```

### getTokenEmissionRewardPerTokenCursor


```solidity
function getTokenEmissionRewardPerTokenCursor(IERC20 _token) external view returns (uint);
```

### increaseTokenEmissionRewardPerTokenCursor


```solidity
function increaseTokenEmissionRewardPerTokenCursor(IERC20 _token, uint _amount) external auth returns (uint);
```

### getTokenEmissionRate


```solidity
function getTokenEmissionRate(IERC20 _token) external view returns (uint);
```

### setTokenEmissionRate


```solidity
function setTokenEmissionRate(IERC20 _token, uint _value) external auth;
```

### getTokenEmissionTimestamp


```solidity
function getTokenEmissionTimestamp(IERC20 _token) external view returns (uint);
```

### setTokenEmissionTimestamp


```solidity
function setTokenEmissionTimestamp(IERC20 _token, uint _value) external auth;
```

### getUserEmissionReward


```solidity
function getUserEmissionReward(IERC20 _token, address _user) external view returns (UserEmissionCursor memory);
```

### setUserEmissionReward


```solidity
function setUserEmissionReward(IERC20 _token, address _user, UserEmissionCursor calldata cursor) external auth;
```

## Errors
### RewardStore__InvalidLength

```solidity
error RewardStore__InvalidLength();
```

## Structs
### UserEmissionCursor

```solidity
struct UserEmissionCursor {
    uint rewardPerToken;
    uint accruedReward;
}
```

