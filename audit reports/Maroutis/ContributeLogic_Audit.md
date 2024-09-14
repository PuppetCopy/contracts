# PuppetToken Audit Report

Prepared by: [Maroutis](https://twitter.com/Maroutis)

# Table of Contents

- [PuppetToken Audit Report](#puppettoken-audit-report)
- [Table of Contents](#table-of-contents)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
- [Protocol Summary](#protocol-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [Medium](#medium)
    - [\[M-1\] Use safeTransfer instead of transfer when transfering Out tokens in `buyback`](#m-1-use-safetransfer-instead-of-transfer-when-transfering-out-tokens-in-buyback)
    - [\[M-2\] Fee-on-transfer tokens reduce contribution but the fees are not accounted for during claims](#m-2-fee-on-transfer-tokens-reduce-contribution-but-the-fees-are-not-accounted-for-during-claims)
- [Low](#low)
    - [\[L-1\] Consider adding emergency withdraw function for stuck/dust tokens](#l-1-consider-adding-emergency-withdraw-function-for-stuckdust-tokens)
- [Informational](#informational)
    - [\[I-1\] Consider making the contracts holding funds upgradeable](#i-1-consider-making-the-contracts-holding-funds-upgradeable)
    - [\[I-2\] Consider adding a reference to the logic contracts in the store contract holding funds](#i-2-consider-adding-a-reference-to-the-logic-contracts-in-the-store-contract-holding-funds)
    - [\[I-3\] Avoid using weird ERC20s like rebasing tokens](#i-3-avoid-using-weird-erc20s-like-rebasing-tokens)
    - [\[I-4\] Buyback function should use contract's token balance instead of user-specified amount](#i-4-buyback-function-should-use-contracts-token-balance-instead-of-user-specified-amount)
    - [Description:](#description)

# Disclaimer

Maroutis makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

# Audit Details

**The findings described in this document correspond the following commit hash:**

```
8677e2c42a2eca6e433544d8962fff2cedb0a801
```

## Scope

```
src/token/
--- ContributeLogic.sol
--- ContributeStore.sol
--- CoreContract.sol
--- BankStore.sol
```

# Protocol Summary

This protocol implements a token-based incentive buy-back system with a self-contained mechanism for reward distribution. It allows users to contribute various tokens and earn rewards in the form of a native token (PUPPET). The system operates without relying on external price oracles or individual liquidity pools for each contributed token.

## Issues found

| Severity          | Number of issues found |
| ----------------- | ---------------------- |
| High              | 0                      |
| Medium            | 2                      |
| Low               | 1                      |
| Info              | 4                      |
| Gas Optimizations | 0                      |
| Total             | 7                      |

# Findings

# Medium

### [M-1] Use safeTransfer instead of transfer when transfering Out tokens in `buyback`

**Description:**
In the `buyback` function of the `ContributeLogic` contract, the `transferOut` method is called on the `store` contract to transfer tokens to the receiver. This `transferOut` method uses the standard `transfer` function of the ERC20 token to transfer the tokens back to the receiver, which can be problematic for certain token implementations. Since some tokens do not return a bool on ERC20 methods.

**Impact:**
Some ERC20 tokens may not revert on failure. This can lead to silent failures where the token transfer appears to succeed but actually fails, potentially causing loss of funds for users.

**Proof of Concept:**

In ContributeLogic.sol:

```js
function buyback(IERC20 token, address depositor, address receiver, uint revenueAmount) external auth {
    // ...
    store.transferOut(token, receiver, revenueAmount);
    // ... .
}
```

This calls the transferOut function in `BankStore.sol`:

```js
function transferOut(IERC20 _token, address _receiver, uint _value) public auth {
@>  _token.transfer(_receiver, _value); // The transfer can fail without reverting the transaction
    tokenBalanceMap[_token] -= _value;
}
```

**Recommended Mitigation:**
Replace the transfer call with `safeTransfer` from OpenZeppelin's `SafeERC20` library or the `callTarget` from the `ExternalCallUtils` library. This ensures that the transfer either succeeds or reverts.

### [M-2] Fee-on-transfer tokens reduce contribution but the fees are not accounted for during claims

**Description:**
The `ContributeStore` contract does not account for fee-on-transfer tokens correctly. When users contribute using these types of tokens, the actual amount received by the contract is less than the amount sent due to the transfer fee. However, the contracts record the full amount for calculating rewards, leading to a discrepancy between the recorded contributions and the actual token balance.

**Impact:**
This discrepancy leads to either inflated or deflated reward calculations for users. When claims are processed, users may receive more (or less) rewards than they should based on the actual value of their contributions. This could lead to an unfair distribution of rewards.

**Proof of Concept:**

A test case demonstrates this issue, you execute the following test using `forge test --mt testFeeOnTransferTokensShouldReduceClaimAmounts -vv`:

```js
    function testFeeOnTransferTokensShouldReduceClaimAmounts() public {

        uint256 quoteAmount = 40 * 1e18;
        uint256 revenueAmount = 100 * 1e18;

        // Assume the token used for contribution is a fee-on-transfer token
        TransferFeeToken feeToken = new TransferFeeToken( 5e18);

        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(IERC20(address(feeToken)), quoteAmount);
        IERC20(address(feeToken)).approve(address(router), type(uint256).max);

        _dealERC20(address(feeToken), users.owner, revenueAmount + 20e18);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.alice, revenueAmount*25/100);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.alice, revenueAmount*15/100);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.bob, revenueAmount*40/100);
        vm.stopPrank();


        assertEq(feeToken.balanceOf(address(contributeStore)), 65e18);
        assertEq(contributeStore.getCursorBalance(IERC20(address(feeToken))), 80e18);

        // Alice buys back
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        contributeRouter.buyback(IERC20(address(feeToken)),  users.alice, feeToken.balanceOf(address(contributeStore)));
        vm.stopPrank();

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = IERC20(address(feeToken));

        uint256 claimableAmountAlice = contributeLogic.getClaimable(tokenList, users.alice);
        uint256 claimableAmountBob = contributeLogic.getClaimable(tokenList, users.bob);

        assertEq(claimableAmountAlice, 20e18);
        assertEq(claimableAmountBob, 20e18);

        // However the real amount should be :
        // 30e18 * 40e18 *e30 / (65e18*e30) which after rounding down gives 18e18. This is the amount that should be claimable by Alice

        uint256 realAmountToClaimAlice = uint256((30e18 * 40e18 * 1e30)) /uint256((65e18 * 1e30));
        uint256 realAmountToClaimBob = uint256((35e18 * 40e18 * 1e30)) /uint256((65e18 * 1e30));

        assertApproxEqAbs(realAmountToClaimAlice , 18.4e18, 1e17);
        assertApproxEqAbs(realAmountToClaimBob , 21.5e18, 1e17);
    }
```

This test shows that while the contract calculates claimable amounts of `20e18` for both Alice and Bob, the actual amounts they should be able to claim (based on the real token balance after fees) are approximately `18.4e18` and `21.5e18` respectively.

**Recommended Mitigation:**

Update the `contribute` function in `ContributeStore` as the following:

```js
function contribute(IERC20 _token, address _depositor, address _user, uint _amount) external auth {
    uint balanceBefore = _token.balanceOf(address(this));
    transferIn(_token, _depositor, _amount);
    uint actualAmount = _token.balanceOf(address(this)) - balanceBefore;

    uint _cursor = cursorMap[_token];
    uint _userCursor = userCursorMap[_token][_user];

    _updateCursorReward(_token, _user, _cursor, _userCursor);
    userContributionBalanceMap[_token][_user] += actualAmount;
    cursorBalanceMap[_token] += actualAmount;
}
```

# Low

### [L-1] Consider adding emergency withdraw function for stuck/dust tokens

**Description:**
The `ContributeStore` contracts lacks a mechanism to withdraw tokens that may become stuck in the contract. This includes both potential dust amounts of various tokens and the reward tokens (`puppyToken`) that are transferred into the `ContributeStore` contract during the `buyback` process.

**Impact:**

- Various tokens may accumulate over time and become effectively locked in the contract.
- The reward tokens (puppyTokens) transferred during buyback cannot be retrieved if needed.

**Proof of Concept:**
Various functions from the `ContributeLogic` and `ContributeStore` contracts allow to transfer tokens into the store. However, there's no function in either of them to withdraw stuck tokens or the reward tokens that are sent back to the contract.

**Recommended Mitigation:**

Implement an emergency withdrawal function in the `ContributeStore` contract:

```js
function emergencyWithdraw(IERC20 token, address recipient, uint256 amount) external auth {
    require(recipient != address(0), "Invalid recipient");
    token.safeTransfer(recipient, amount);
}
```

# Informational

### [I-1] Consider making the contracts holding funds upgradeable

**Description:**

The `ContributeStore` contract, which inherits from `BankStore`, holds funds but is not upgradeable. This could make it difficult to fix bugs or add features in the future without migrating all funds to a new contract.

**Recommended Mitigation:**

Consider implementing an upgradeable pattern, to allow for future improvements without requiring fund migration.

### [I-2] Consider adding a reference to the logic contracts in the store contract holding funds

**Description:**

The `ContributeStore` contract, is the contract that holds all the funds and should be the one to point to any contract that holds logic and not the other way around. In the future, if a new logic contract has to be implemented, migrating can become much easier.

**Recommended Mitigation:**

Add a function that references the logic contract `ContributeLogic` and adds the necessary accesses.

### [I-3] Avoid using weird ERC20s like rebasing tokens

**Description:**

Rebasing tokens like stETH can have their balance increase or decrease depending on market conditions and slashing events. This can cause accounting issues.

### [I-4] Buyback function should use contract's token balance instead of user-specified amount

### Description:

In the `buyback` function of the ContributeLogic contract, the `revenueAmount` parameter allows users to specify the amount of tokens to be bought back. This approach can be a source of user error, as users might not input the maximum available amount, leading to loss of funds.

```js
function buyback(IERC20 token, address depositor, address receiver, uint revenueAmount) external auth { // use all the contract balance for the specified token
    uint quoteAmount = store.getBuybackQuote(token);

    if (quoteAmount == 0) revert ContributeLogic__InvalidBuybackToken();

    store.transferIn(rewardToken, depositor, quoteAmount);
    store.transferOut(token, receiver, revenueAmount);
    // ...
}
```

**Recommended Mitigation:**

```js
function buyback(IERC20 token, address depositor, address receiver) external auth {
    uint quoteAmount = store.getBuybackQuote(token);

    if (quoteAmount == 0) revert ContributeLogic__InvalidBuybackToken();

    uint revenueAmount = token.balanceOf(address(this));

    store.transferIn(rewardToken, depositor, quoteAmount);
    store.transferOut(token, receiver, revenueAmount);

    // ...
}
```
