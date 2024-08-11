# PuppetToken
[Git Source](https://github.com/GMX-Blueberry-Club/puppet-contracts/blob/2183e6f52c6ba1495da1bef62e515f52d5da1868/src/token/PuppetToken.sol)

**Inherits:**
Permission, ERC20, IERC20Mintable

*An ERC20 token with a mint rate limit designed to mitigate and provide feedback of a potential critical faults or bugs in the minting process.
The limit restricts the quantity of new tokens that can be minted within a given timeframe, proportional to the existing supply.
The mintCore function in the contract is designed to allocate tokens to the core contributors over time, with the allocation amount decreasing
as more time passes from the deployment of the contract. This is intended to gradually transfer governance power and incentivises broader ownership*


## State Variables
### CORE_RELEASE_DURATION_DIVISOR

```solidity
uint private constant CORE_RELEASE_DURATION_DIVISOR = 31560000;
```


### GENESIS_MINT_AMOUNT

```solidity
uint private constant GENESIS_MINT_AMOUNT = 100_000e18;
```


### config

```solidity
Config public config;
```


### lastMintTime

```solidity
uint lastMintTime = block.timestamp;
```


### emissionRate

```solidity
uint emissionRate;
```


### deployTimestamp

```solidity
uint public immutable deployTimestamp = block.timestamp;
```


### mintedCoreAmount

```solidity
uint public mintedCoreAmount = 0;
```


## Functions
### constructor


```solidity
constructor(IAuthority _authority, Config memory _config, address receiver) Permission(_authority) ERC20("Puppet Test", "PUPPET-TEST");
```

### getLockedAmount


```solidity
function getLockedAmount(address _user) public view returns (uint);
```

### getCoreShare


```solidity
function getCoreShare() public view returns (uint);
```

### getCoreShare


```solidity
function getCoreShare(uint _time) public view returns (uint);
```

### getMintableCoreAmount


```solidity
function getMintableCoreAmount(uint _lastMintTime) public view returns (uint);
```

### getLimitAmount


```solidity
function getLimitAmount() public view returns (uint);
```

### mint

*Mints new tokens with a governance-configured rate limit.*


```solidity
function mint(address _receiver, uint _amount) external auth returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_receiver`|`address`|The address to mint tokens to.|
|`_amount`|`uint256`|The amount of tokens to mint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of tokens minted.|


### mintCore

*Mints new tokens to the core with a time-based reduction release schedule.*


```solidity
function mintCore(address _receiver) external auth returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_receiver`|`address`|The address to mint tokens to.|


### setConfig

*Set the mint rate limit for the token.*


```solidity
function setConfig(Config calldata _config) external auth;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_config`|`Config`|The new rate limit configuration.|


### _setConfig


```solidity
function _setConfig(Config memory _config) internal;
```

## Events
### Puppet__SetConfig

```solidity
event Puppet__SetConfig(Config config);
```

### Puppet__MintCore

```solidity
event Puppet__MintCore(address operator, address indexed receiver, uint amount);
```

## Errors
### Puppet__InvalidRate

```solidity
error Puppet__InvalidRate();
```

### Puppet__ExceededRateLimit

```solidity
error Puppet__ExceededRateLimit(uint rateLimit, uint emissionRate);
```

### Puppet__CoreShareExceedsMining

```solidity
error Puppet__CoreShareExceedsMining();
```

## Structs
### Config

```solidity
struct Config {
    uint limitFactor;
    uint durationWindow;
}
```

