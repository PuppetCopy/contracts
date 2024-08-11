# PuppetStore
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/puppet/store/PuppetStore.sol)

**Inherits:**
BankStore


## State Variables
### tokenAllowanceCapMap

```solidity
mapping(IERC20 token => uint) public tokenAllowanceCapMap;
```


### balanceMap

```solidity
mapping(address puppet => mapping(IERC20 token => uint) name) balanceMap;
```


### ruleMap

```solidity
mapping(bytes32 ruleKey => Rule) public ruleMap;
```


### fundingActivityMap

```solidity
mapping(address puppet => mapping(address trader => uint) name) public fundingActivityMap;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, Router _router, IERC20[] memory _tokenAllowanceCapList, uint[] memory _tokenAllowanceConfigList)
    BankStore(_authority, _router);
```

### getTokenAllowanceCap


```solidity
function getTokenAllowanceCap(IERC20 _token) external view returns (uint);
```

### setTokenAllowanceCap


```solidity
function setTokenAllowanceCap(IERC20 _token, uint _value) external auth;
```

### getBalance


```solidity
function getBalance(IERC20 _token, address _account) external view returns (uint);
```

### getBalanceList


```solidity
function getBalanceList(IERC20 _token, address[] calldata _accountList) external view returns (uint[] memory);
```

### increaseBalance


```solidity
function increaseBalance(IERC20 _token, address _depositor, uint _value) external auth;
```

### increaseBalanceList


```solidity
function increaseBalanceList(IERC20 _token, address _depositor, address[] calldata _accountList, uint[] calldata _valueList) external auth;
```

### decreaseBalance


```solidity
function decreaseBalance(IERC20 _token, address _user, address _receiver, uint _value) public auth;
```

### getRule


```solidity
function getRule(bytes32 _key) external view returns (Rule memory);
```

### setRule


```solidity
function setRule(bytes32 _key, Rule calldata _rule) external auth;
```

### decreaseBalanceList


```solidity
function decreaseBalanceList(IERC20 _token, address _receiver, address[] calldata _accountList, uint[] calldata _valueList) external auth;
```

### getRuleList


```solidity
function getRuleList(bytes32[] calldata _keyList) external view returns (Rule[] memory);
```

### setRuleList


```solidity
function setRuleList(bytes32[] calldata _keyList, Rule[] calldata _rules) external auth;
```

### getFundingActivityList


```solidity
function getFundingActivityList(address trader, address[] calldata puppetList) external view returns (uint[] memory);
```

### setFundingActivityList


```solidity
function setFundingActivityList(address trader, address[] calldata puppetList, uint[] calldata _timeList) external auth;
```

### setFundingActivity


```solidity
function setFundingActivity(address puppet, address trader, uint _time) external auth;
```

### getFundingActivity


```solidity
function getFundingActivity(address puppet, address trader) external view returns (uint);
```

### getBalanceAndActivityList


```solidity
function getBalanceAndActivityList(IERC20 collateralToken, address trader, address[] calldata _puppetList)
    external
    view
    returns (Rule[] memory _ruleList, uint[] memory _fundingActivityList, uint[] memory _valueList);
```

### decreaseBalanceAndSetActivityList


```solidity
function decreaseBalanceAndSetActivityList(
    IERC20 _token,
    address _receiver,
    address _trader,
    uint _activityTime,
    address[] calldata _puppetList,
    uint[] calldata _valueList
) external auth;
```

## Errors
### PuppetStore__InvalidLength

```solidity
error PuppetStore__InvalidLength();
```

## Structs
### Rule

```solidity
struct Rule {
    uint throttleActivity;
    uint allowanceRate;
    uint expiry;
}
```

