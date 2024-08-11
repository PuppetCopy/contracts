# RewardLogic
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/RewardLogic.sol)

**Inherits:**
Permission, EIP712, ReentrancyGuardTransient


## State Variables
### config

```solidity
Config config;
```


### votingEscrow

```solidity
VotingEscrow immutable votingEscrow;
```


### puppetToken

```solidity
PuppetToken immutable puppetToken;
```


### store

```solidity
RewardStore immutable store;
```


### revenueStore

```solidity
RevenueStore immutable revenueStore;
```


## Functions
### getClaimableEmission


```solidity
function getClaimableEmission(IERC20 token, address user) public view returns (uint);
```

### getBonusReward


```solidity
function getBonusReward(uint durationBonusMultiplier, uint reward, uint duration) public view returns (uint);
```

### constructor


```solidity
constructor(
    IAuthority _authority,
    VotingEscrow _votingEscrow,
    PuppetToken _puppetToken,
    RewardStore _store,
    RevenueStore _revenueStore,
    Config memory _callConfig
) Permission(_authority) EIP712("Reward Logic", "1");
```

### lock


```solidity
function lock(IERC20 token, uint duration) public nonReentrant returns (uint);
```

### exit


```solidity
function exit(IERC20 token) external nonReentrant;
```

### lockToken


```solidity
function lockToken(address user, uint unlockDuration, uint amount) external nonReentrant returns (uint);
```

### vestTokens


```solidity
function vestTokens(uint amount) public nonReentrant;
```

### veClaim


```solidity
function veClaim(address user, address receiver, uint amount) public nonReentrant;
```

### claimEmission


```solidity
function claimEmission(IERC20 token, address receiver) public nonReentrant returns (uint);
```

### distributeEmission


```solidity
function distributeEmission(IERC20 token) public nonReentrant returns (uint);
```

### setConfig


```solidity
function setConfig(Config memory _callConfig) external auth;
```

### transferReferralOwnership


```solidity
function transferReferralOwnership(IGmxReferralStorage _referralStorage, bytes32 _code, address _newOwner) external auth;
```

### getDurationBonusMultiplier


```solidity
function getDurationBonusMultiplier(uint durationBonusMultiplier, uint duration) internal pure returns (uint);
```

### getPendingEmission


```solidity
function getPendingEmission(IERC20 token) internal view returns (uint);
```

### getUserPendingReward


```solidity
function getUserPendingReward(uint cursor, uint userCursor, uint userBalance) internal pure returns (uint);
```

### _setConfig


```solidity
function _setConfig(Config memory _callConfig) internal;
```

## Events
### RewardLogic__SetConfig

```solidity
event RewardLogic__SetConfig(uint timestmap, Config callConfig);
```

### RewardLogic__Lock

```solidity
event RewardLogic__Lock(IERC20 token, uint baselineEmissionRate, address user, uint accuredReward, uint duration, uint rewardInToken);
```

### RewardLogic__Exit

```solidity
event RewardLogic__Exit(IERC20 token, uint baselineEmissionRate, address user, uint rewardInToken);
```

### RewardLogic__Claim

```solidity
event RewardLogic__Claim(address user, address receiver, uint rewardPerTokenCursor, uint amount);
```

### RewardLogic__Distribute

```solidity
event RewardLogic__Distribute(IERC20 token, uint distributionTimeframe, uint supply, uint nextRewardPerTokenCursor);
```

### RewardLogic__Buyback

```solidity
event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);
```

## Errors
### RewardLogic__NoClaimableAmount

```solidity
error RewardLogic__NoClaimableAmount();
```

### RewardLogic__UnacceptableTokenPrice

```solidity
error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
```

### RewardLogic__InvalidClaimPrice

```solidity
error RewardLogic__InvalidClaimPrice();
```

### RewardLogic__InvalidDuration

```solidity
error RewardLogic__InvalidDuration();
```

### RewardLogic__NotingToClaim

```solidity
error RewardLogic__NotingToClaim();
```

### RewardLogic__AmountExceedsContribution

```solidity
error RewardLogic__AmountExceedsContribution();
```

### RewardLogic__InvalidWeightFactors

```solidity
error RewardLogic__InvalidWeightFactors();
```

## Structs
### Config

```solidity
struct Config {
    uint baselineEmissionRate;
    uint optionLockTokensBonusMultiplier;
    uint lockLiquidTokensBonusMultiplier;
    uint distributionTimeframe;
}
```

