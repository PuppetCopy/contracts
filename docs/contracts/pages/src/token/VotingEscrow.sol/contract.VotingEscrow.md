# VotingEscrow
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/VotingEscrow.sol)

**Inherits:**
Permission, ERC20Votes

*lock tokens for a certain period to obtain governance voting power.
The lock duration is subject to a weighted average adjustment when additional tokens are locked for a new duration. Upon unlocking, tokens enter a
vesting period, the duration of which is determined by the weighted average of the lock durations. The vesting period is recalculated whenever
additional tokens are locked, incorporating the new amount and duration into the weighted average.*


## State Variables
### lockMap

```solidity
mapping(address => Lock) public lockMap;
```


### vestMap

```solidity
mapping(address => Vest) public vestMap;
```


### router

```solidity
Router public immutable router;
```


### token

```solidity
IERC20 public immutable token;
```


## Functions
### getLock


```solidity
function getLock(address _user) external view returns (Lock memory);
```

### getVest


```solidity
function getVest(address _user) external view returns (Vest memory);
```

### constructor


```solidity
constructor(IAuthority _authority, Router _router, IERC20 _token)
    Permission(_authority)
    ERC20("Puppet Voting Power", "vePUPPET")
    EIP712("Voting Escrow", "1");
```

### getClaimable


```solidity
function getClaimable(address _user) external view returns (uint);
```

### getVestingCursor


```solidity
function getVestingCursor(address _user) public view returns (Vest memory);
```

### transfer


```solidity
function transfer(address, uint) public pure override returns (bool);
```

### transferFrom


```solidity
function transferFrom(address, address, uint) public pure override returns (bool);
```

### lock


```solidity
function lock(address _depositor, address _user, uint _amount, uint _duration) external auth;
```

### vest


```solidity
function vest(address _user, address _receiver, uint _amount) external auth;
```

### claim


```solidity
function claim(address _user, address _receiver, uint _amount) external auth;
```

## Events
### VotingEscrow__Lock

```solidity
event VotingEscrow__Lock(address depositor, address user, Lock lock);
```

### VotingEscrow__Vest

```solidity
event VotingEscrow__Vest(address user, address receiver, Vest vest);
```

### VotingEscrow__Claim

```solidity
event VotingEscrow__Claim(address user, address receiver, uint amount);
```

## Errors
### VotingEscrow__ZeroAmount

```solidity
error VotingEscrow__ZeroAmount();
```

### VotingEscrow__Unsupported

```solidity
error VotingEscrow__Unsupported();
```

### VotingEscrow__ExceedMaxTime

```solidity
error VotingEscrow__ExceedMaxTime();
```

### VotingEscrow__ExceedingAccruedAmount

```solidity
error VotingEscrow__ExceedingAccruedAmount(uint accrued);
```

### VotingEscrow__ExceedingLockAmount

```solidity
error VotingEscrow__ExceedingLockAmount(uint amount);
```

## Structs
### Lock

```solidity
struct Lock {
    uint amount;
    uint duration;
}
```

### Vest

```solidity
struct Vest {
    uint amount;
    uint remainingDuration;
    uint lastAccruedTime;
    uint accrued;
}
```

