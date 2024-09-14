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
- [Low](#low)
    - [\[L-1\] Low/dust Puppet amount will revert locking of funds](#l-1-lowdust-puppet-amount-will-revert-locking-of-funds)
- [Informational](#informational)
    - [\[I-1\] Improve event name for more transparency](#i-1-improve-event-name-for-more-transparency)
- [Improved testing suite](#improved-testing-suite)

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
--- VotingEscrowLogic.sol
--- VotingEscrowStore.sol
--- CoreContract.sol
```

# Protocol Summary

The `VotingEscrowLogic` contract manages the locking of tokens to grant users governance voting power and time-based rewards. It allows users to lock tokens for a specified duration, during which they accrue voting power and potential rewards up to a fixed %, determined by the `baseMultiplier`, of their locked amount. Users can also claim their vested tokens, with the contract ensuring that only valid amounts are claimed.

## Issues found

| Severity          | Number of issues found |
| ----------------- | ---------------------- |
| High              | 0                      |
| Medium            | 0                      |
| Low               | 1                      |
| Info              | 1                      |
| Gas Optimizations | 0                      |
| Total             | 2                      |

# Findings

# Low

### [L-1] Low/dust Puppet amount will revert locking of funds

**Description:**
The `lock` function in the `VotingEscrowLogic` contract calculates a bonus amount to be minted based on the locked token amount and duration. However, when the locked amount is very low (a "dust" amount), the calculated bonus amount will be zero **due to rounding**. This results in the function reverting with the `VotingEscrowLogic__ZeroAmount()` error, preventing users from locking their tokens if they attempt to lock a small amount.

The minimum amount that has to be locked by a user for a particular `duration` is :

`uint minAmountToMint = (MAXTIME ** 2 / baseMultiplier) / duration ** 2 + 1;`

Any amount lesser will revert the whole tx.

**Impact:**

Users who attempt to lock a low amount of tokens will experience a transaction revert. If a user or protocol implements a logic that regurarly locks excess tokens into the VotingEscrowLogic, it could block there locking process. This could lead to user frustration and reduced participation in the protocol.

**Proof of Concept:**

```js
    function testCannotLockDustAmount() public {
        uint amount = 10 * 1e18;
        uint duration = 30 days;

        // Alice locks her tokens
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);

        uint256 rate = 1e30 / veLogic.config();
        uint minAmountToMint = (MAXTIME ** 2 * rate) / duration ** 2 + 1;
        console.log("minAmountToMint", minAmountToMint);

        veRouter.lock(minAmountToMint, duration);
        // Anything less will revert the tx
        vm.expectRevert(bytes4(abi.encodeWithSignature("VotingEscrowLogic__ZeroAmount()")));
        veRouter.lock(minAmountToMint - 1, duration);

        vm.stopPrank();
    }
```

**Recommended Mitigation:**

- Establish a minimum lock amount that ensures the `getVestedBonus` calculation never results in a zero bonus. This should proactively inform users of the minimum amount required to successfully lock their tokens.

# Informational

### [I-1] Improve event name for more transparency

**Description:**

Currently, the `EventEmitter` contract emits events using a generic event name, `logEvent`, for all logged activities, such as `claim()`, `vest()`... While the event parameters differ, the event name remains the same. This setup can make it challenging for users and developers to differentiate between different events when reviewing transaction logs on block explorers like Etherscan.

When all events share the same name, users have to rely on the event parameters to understand the context of each event which can be confusing. The lack of specific event names makes it harder to trace the exact nature of each transaction. Additionally, if a developer later integrates with the Puppet protocol and needs to interact with these logged events, it will be more difficult to collect them using web3 providers due to the identical event names. This will reduce user experience.

**Recommended Mitigation:**

- Use Specific Event Names:

```js
event Claim(...);
event Vest(...);
```

# Improved testing suite

Consider adding the diff content below and applying the changes with `git apply ...`.

```diff
diff --git a/test/tokenomics/VotingEscrow.t.sol b/test/tokenomics/VotingEscrow.t.sol
index 79f50b4..5f827d3 100644
--- a/test/tokenomics/VotingEscrow.t.sol
+++ b/test/tokenomics/VotingEscrow.t.sol
@@ -5,6 +5,7 @@ import {Router} from "src/shared/Router.sol";
 import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
 import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

+import {console} from "forge-std/src/Test.sol";
 import {BasicSetup} from "test/base/BasicSetup.t.sol";

 contract VotingEscrowTest is BasicSetup {
@@ -49,6 +50,8 @@ contract VotingEscrowTest is BasicSetup {
         puppetToken.mint(users.alice, 100 * 1e18);
         puppetToken.mint(users.bob, 100 * 1e18);
         puppetToken.mint(users.yossi, 100 * 1e18);
+
+        vm.stopPrank();
     }

     function testBonusMultiplier() public view {
@@ -187,6 +190,224 @@ contract VotingEscrowTest is BasicSetup {

         vm.stopPrank();
     }
+
+    function testCannotLockDustAmount() public {
+        uint amount = 10 * 1e18;
+        uint duration = 30 days;
+
+        // Alice locks her tokens
+        vm.startPrank(users.alice);
+        puppetToken.approve(address(router), amount);
+        uint256 rate = 1e30 / veLogic.config();
+        uint minAmountToMint = (MAXTIME ** 2 * rate) / duration ** 2 + 1;
+        console.log("minAmountToMint", minAmountToMint);
+        veRouter.lock(minAmountToMint, duration);
+
+        vm.expectRevert(bytes4(abi.encodeWithSignature("VotingEscrowLogic__ZeroAmount()")));
+        veRouter.lock(minAmountToMint - 1, duration);
+
+        vm.stopPrank();
+    }
+
+    function testLockAndClaimForDurationIncentives() public {
+        uint amount = 10 * 1e18;
+        uint duration = 10 days;
+
+        // Alice locks her tokens
+        vm.startPrank(users.alice);
+        puppetToken.approve(address(router), amount);
+        veRouter.lock(amount, duration);
+        veRouter.vest(amount);
+
+        skip(duration);
+        uint256 claimable = veLogic.getClaimable(users.alice);
+        veRouter.claim(claimable);
+
+        vm.stopPrank();
+
+        assertGt(claimable, amount);
+
+
+        uint amountBob = 10 * 1e18;
+        uint durationBob = MAXTIME;
+
+        // Bob locks his tokens
+        vm.startPrank(users.bob);
+        puppetToken.approve(address(router), amountBob);
+        veRouter.lock(amountBob, durationBob);
+        veRouter.vest(amountBob);
+
+        skip(durationBob);
+        uint256 claimableBob = veLogic.getClaimable(users.bob);
+        veRouter.claim(claimableBob);
+
+        vm.stopPrank();
+
+        assertGt(claimableBob, amountBob);
+
+        assertApproxEqAbs(claimableBob - claimable, 1 ether, 2e15); // @note About 10% of total lock increase in incentives for Bob
+    }
+
+    // function testLockVestAndClaim() public {
+    //     uint duration = 86400;
+    //     uint amount = 5337111;
+    //     uint timestamp = 1104;
+
+    //     vm.startPrank(users.alice);
+    //     puppetToken.approve(address(router), amount);
+
+    //     veRouter.lock(amount, duration);
+    //     veRouter.vest(amount);
+
+    //     skip(timestamp);
+    //     uint claimable = veLogic.getClaimable(users.alice);
+    //     if (claimable > 0) {
+    //         veRouter.claim(claimable);
+    //     }
+    // }
+
+    ///////////////////////////////////    Fuzzers   ////////////////////////////////////////////////////////////////
+    function testFuzzLockMultipleTimes(uint256[] calldata amounts, uint256[] calldata durations) public {
+        vm.assume(amounts.length == durations.length);
+        vm.assume(amounts.length > 0 && amounts.length <= 10); // Limit to 10 locks for practical reasons
+
+        uint256 totalAmount = 0;
+        uint256 totalDuration = 0;
+
+
+        for (uint256 i = 0; i < amounts.length; i++) {
+            uint256 duration = bound(durations[i], 1 days, MAXTIME); // Ensure valid durations
+            uint256 minAmountToMint = (MAXTIME ** 2 * 10) / duration ** 2 + 1;
+            uint256 amount = bound(amounts[i], minAmountToMint, 100e18); // Ensure reasonable amounts
+
+            totalAmount += amount;
+            totalDuration += duration;
+
+            vm.prank(users.owner);
+            puppetToken.mint(users.alice, amount);
+
+            vm.startPrank(users.alice);
+            puppetToken.approve(address(router), amount);
+            veRouter.lock(amount, duration);
+            vm.stopPrank();
+        }
+
+        assertEq(vPuppetToken.balanceOf(users.alice), totalAmount, "Total locked amount should be at least the sum of individual locks");
+        assertLe(veStore.getLockDuration(users.alice), MAXTIME, "Lock duration should not exceed MAXTIME");
+    }
+
+    function testFuzzVestPartial(uint256 lockAmount, uint256 lockDuration, uint256 vestAmount, uint256 timeElapsed) public {
+
+        lockDuration = bound(lockDuration, 1 days, MAXTIME);
+        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / lockDuration ** 2 + 1;
+        lockAmount = bound(lockAmount, minAmountToMint, 100e18);
+        vestAmount = bound(vestAmount, 1, lockAmount);
+        timeElapsed = bound(timeElapsed, 0, lockDuration);
+
+        vm.startPrank(users.alice);
+        puppetToken.approve(address(router), lockAmount);
+        veRouter.lock(lockAmount, lockDuration);
+
+        skip(timeElapsed);
+
+        veRouter.vest(vestAmount);
+        vm.stopPrank();
+
+        assertLe(vPuppetToken.balanceOf(users.alice), lockAmount, "vPuppet balance should decrease after vesting");
+        assertGe(veLogic.getVestingCursor(users.alice).amount, 0, "Vesting amount should be non-negative");
+    }
+
+    function testFuzzClaimPartial(uint256 lockAmount, uint256 lockDuration, uint256 timeElapsed, uint256 claimAmount) public {
+
+        lockDuration = bound(lockDuration, 1 days, MAXTIME);
+        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / lockDuration ** 2 + 1;
+        lockAmount = bound(lockAmount, minAmountToMint, 100e18);
+        timeElapsed = bound(timeElapsed, 0, lockDuration);
+
+        vm.startPrank(users.alice);
+        puppetToken.approve(address(router), lockAmount);
+        veRouter.lock(lockAmount, lockDuration);
+        veRouter.vest(lockAmount);
+
+        skip(timeElapsed);
+
+        uint256 claimable = veLogic.getClaimable(users.alice);
+        claimAmount = bound(claimAmount, 0, claimable);
+
+        uint256 balanceBefore = puppetToken.balanceOf(users.alice);
+        if (claimAmount > 0) {
+            veRouter.claim(claimAmount);
+        }
+        vm.stopPrank();
+
+        uint256 balanceAfter = puppetToken.balanceOf(users.alice);
+
+        assertEq(veLogic.getClaimable(users.alice), claimable - claimAmount, "Claimable amount should decrease after claiming");
+        assertEq(balanceAfter - balanceBefore, claimAmount, "User should receive claimed tokens");
+    }
+
+    function testFuzzLockVestAndClaim(uint256 amount, uint256 duration, uint256 timestamp) public {
+        // precision ranges
+        // duration = bound(duration, 0, MAXTIME);
+        duration = duration > MAXTIME ? MAXTIME : (duration < 1 days ? 1 days : duration);
+        // Remove dust Amounts which causes this VotingEscrowLogic__ZeroAmount
+        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / duration ** 2 + 1;
+        amount = amount > 100e18 ? 100e18 : (amount < minAmountToMint ? minAmountToMint : amount);
+        // amount = bound(amount, minAmountToMint, 100e18);
+        timestamp = timestamp > 63120001 ? 63120001 : timestamp;
+        // timestamp = bound(timestamp, 0, 63120001);
+
+        vm.startPrank(users.alice);
+        puppetToken.approve(address(router), amount);
+
+        veRouter.lock(amount, duration);
+        veRouter.vest(amount);
+
+        skip(timestamp);
+        uint256 claimable = veLogic.getClaimable(users.alice);
+        if (claimable > 0) {
+            veRouter.claim(claimable);
+        }
+
+        assert(true);
+    }
+
+    function testFuzzLockVestClaimMultiUser(uint256[3] memory amounts, uint256[3] memory durations, uint256 timeElapsed) public {
+        address payable[3] memory usersArray = [users.alice, users.bob, users.yossi];
+
+        for (uint256 i = 0; i < 3; i++) {
+
+            durations[i] = bound(durations[i], 1 days, MAXTIME);
+            uint256 minAmountToMint = (MAXTIME ** 2 * 10) / durations[i] ** 2 + 1;
+            amounts[i] = bound(amounts[i], minAmountToMint, 100e18);
+
+            vm.startPrank(usersArray[i]);
+            puppetToken.approve(address(router), amounts[i]);
+            veRouter.lock(amounts[i], durations[i]);
+            veRouter.vest(amounts[i]);
+            vm.stopPrank();
+        }
+
+        timeElapsed = bound(timeElapsed, 0, MAXTIME);
+        skip(timeElapsed);
+
+        uint256 balanceBefore;
+        uint256 balanceAfter;
+        for (uint256 i = 0; i < 3; i++) {
+            vm.startPrank(usersArray[i]);
+            balanceBefore = puppetToken.balanceOf(usersArray[i]);
+            uint256 claimable = veLogic.getClaimable(usersArray[i]);
+            if (claimable > 0) {
+                veRouter.claim(claimable);
+            }
+            balanceAfter = puppetToken.balanceOf(usersArray[i]);
+            vm.stopPrank();
+
+            assertEq(veLogic.getClaimable(usersArray[i]), 0, "All claimable tokens should be claimed");
+            assertEq(balanceAfter - balanceBefore, claimable, "User should receive claimed tokens");
+        }
+    }
+
 }

 contract VotingEscrowRouter {
```
