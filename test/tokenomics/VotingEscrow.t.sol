// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Router} from "src/shared/Router.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

import {console} from "forge-std/src/Test.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract VotingEscrowTest is BasicSetup {
    uint constant MAXTIME = 106 weeks; // about 2 years

    VotingEscrowStore veStore;
    VotingEscrowLogic veLogic;
    VotingEscrowRouter veRouter;

    function setUp() public override {
        BasicSetup.setUp();

        veStore = new VotingEscrowStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(veStore));

        allowNextLoggerAccess();
        veLogic = new VotingEscrowLogic(
            dictator, //
            eventEmitter,
            veStore,
            puppetToken,
            vPuppetToken,
            VotingEscrowLogic.Config({baseMultiplier: 0.1e30})
        );

        dictator.setAccess(eventEmitter, address(veLogic));
        dictator.setAccess(veStore, address(veLogic));

        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.burn.selector, address(veLogic));

        // test setup

        veRouter = new VotingEscrowRouter(veLogic);
        dictator.setPermission(veLogic, veLogic.lock.selector, address(veRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(veRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(veRouter));

        dictator.setPermission(puppetToken, puppetToken.mint.selector, users.owner);

        puppetToken.mint(users.alice, 100 * 1e18);
        puppetToken.mint(users.bob, 100 * 1e18);
        puppetToken.mint(users.yossi, 100 * 1e18);

        vm.stopPrank();
    }

    function testBonusMultiplier() public view {
        uint amount = 100e18; // The locked amount

        assertEq(veLogic.getVestedBonus(amount, 0), 0, "Bonus amount should be zero for zero duration");
        assertEq(veLogic.getVestedBonus(amount, MAXTIME / 2), 2.5e18, "Bonus amount should be zero for half duration");
        assertEq(veLogic.getVestedBonus(amount, 1 * MAXTIME), 10e18, "Bonus amount should be zero for full duration");
        assertEq(veLogic.getVestedBonus(amount, 2 * MAXTIME), 40e18, "Bonus amount should be zero for double duration");
    }

    function testLock() public {
        skip(MAXTIME);

        uint amount = 10e18;
        uint duration = MAXTIME;

        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);

        veRouter.lock(amount, duration);
        vm.stopPrank();

        uint bonusAmount = veLogic.getVestedBonus(amount, duration);

        assertEq(veLogic.getClaimable(users.alice), 0, "Vested amount should match");
        assertEq(vPuppetToken.balanceOf(users.alice), amount, "Lock amount should match");
        assertEq(veLogic.getVestingCursor(users.alice).amount, bonusAmount, "Bonus amount should match");
        assertEq(veLogic.getVestingCursor(users.alice).remainingDuration, duration, "Bonus duration should match");

        skip(duration);

        assertEq(veStore.getLockDuration(users.alice), duration, "Lock duration should remain the same");
        assertEq(vPuppetToken.balanceOf(users.alice), amount, "Lock amount should remain the same");
        assertEq(veLogic.getClaimable(users.alice), bonusAmount, "Vested amount should match");
    }

    function testClaim() public {
        uint amount = 100e18;
        uint duration = MAXTIME;
        uint halfDuration = duration / 2;

        // Alice locks her tokens
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);
        veRouter.lock(amount, duration);
        vm.stopPrank();

        // Simulate time passing
        skip(halfDuration);

        // Alice claims her vested tokens
        vm.startPrank(users.alice);
        uint claimableAmount = veLogic.getClaimable(users.alice);
        veRouter.claim(claimableAmount);
        vm.stopPrank();

        // Check that Alice's claimable amount is now 0
        assertEq(veLogic.getClaimable(users.alice), 0, "Alice should have no claimable tokens after claiming");

        // Check that Alice received her tokens
        assertEq(puppetToken.balanceOf(users.alice), claimableAmount, "Alice should have received her claimed tokens");
    }

    function testRelockAndClaim() public {
        uint amount = 100e18;
        uint bonus = veLogic.getVestedBonus(amount / 2, MAXTIME);

        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);

        veRouter.lock(amount / 2, MAXTIME);
        skip((MAXTIME / 2) + 1);

        veRouter.claim(bonus / 2);

        veRouter.lock(amount / 2, MAXTIME);

        vm.expectRevert();
        veRouter.claim(bonus);

        skip(MAXTIME / 2);

        veRouter.claim(bonus / 2);

        assertEq(puppetToken.balanceOf(users.alice), bonus, "Alice should have received her claimed tokens");

        veLogic.getClaimable(users.alice);

        assertEq(vPuppetToken.totalSupply(), amount, "vPuppet supply should be back to 0 after burning");

        veRouter.vest(amount);
        skip(MAXTIME);

        veRouter.claim(amount);

        assertEq(vPuppetToken.totalSupply(), 0, "vPuppet supply should be back to 0 after burning");
        assertEq(puppetToken.balanceOf(users.alice), amount + bonus, "Alice should have received her claimed tokens");
    }

    function testLockExceedMaxTimeReverts() public {
        uint amount = 10 * 1e18;
        uint durationExceedingMax = MAXTIME + 1;

        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);

        // Expect the transaction to revert because the duration exceeds MAXTIME
        vm.expectRevert(VotingEscrowLogic.VotingEscrowLogic__ExceedMaxTime.selector);
        veRouter.lock(amount, durationExceedingMax);

        vm.stopPrank();
    }

    function testClaimExceedsAccruedReverts() public {
        uint amount = 10 * 1e18;
        uint duration = MAXTIME / 2;

        // Alice locks her tokens
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);
        veRouter.lock(amount, duration);
        vm.stopPrank();

        // Simulate time passing
        skip(duration / 4);

        // Alice tries to claim more than her accrued amount
        vm.startPrank(users.alice);
        uint claimableAmount = veLogic.getClaimable(users.alice);
        uint excessAmount = claimableAmount + 1e18; // Excess amount

        // Expect the transaction to revert because the claim amount exceeds accrued tokens
        vm.expectRevert();
        veRouter.claim(excessAmount);

        vm.stopPrank();
    }

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

        vm.expectRevert(bytes4(abi.encodeWithSignature("VotingEscrowLogic__ZeroAmount()")));
        veRouter.lock(minAmountToMint - 1, duration);

        vm.stopPrank();
    }

    function testLockAndClaimForDurationIncentives() public {
        uint amount = 10 * 1e18;
        uint duration = 10 days;

        // Alice locks her tokens
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);
        veRouter.lock(amount, duration);
        veRouter.vest(amount);

        skip(duration);
        uint256 claimable = veLogic.getClaimable(users.alice);
        veRouter.claim(claimable);

        vm.stopPrank();

        assertGt(claimable, amount);


        uint amountBob = 10 * 1e18;
        uint durationBob = MAXTIME;

        // Bob locks his tokens
        vm.startPrank(users.bob);
        puppetToken.approve(address(router), amountBob);
        veRouter.lock(amountBob, durationBob);
        veRouter.vest(amountBob);

        skip(durationBob);
        uint256 claimableBob = veLogic.getClaimable(users.bob);
        veRouter.claim(claimableBob);

        vm.stopPrank();

        assertGt(claimableBob, amountBob);

        assertApproxEqAbs(claimableBob - claimable, 1 ether, 2e15); // @note About 10% of total lock increase in incentives for Bob
    }

    // function testLockVestAndClaim() public {
    //     uint duration = 86400;
    //     uint amount = 5337111;
    //     uint timestamp = 1104;

    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);

    //     veRouter.lock(amount, duration);
    //     veRouter.vest(amount);

    //     skip(timestamp);
    //     uint claimable = veLogic.getClaimable(users.alice);
    //     if (claimable > 0) {
    //         veRouter.claim(claimable);
    //     }
    // }

    ///////////////////////////////////    Fuzzers   ////////////////////////////////////////////////////////////////
    function testFuzzLockMultipleTimes(uint256[] calldata amounts, uint256[] calldata durations) public {
        vm.assume(amounts.length == durations.length);
        vm.assume(amounts.length > 0 && amounts.length <= 10); // Limit to 10 locks for practical reasons
    
        uint256 totalAmount = 0;
        uint256 totalDuration = 0;
    

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 duration = bound(durations[i], 1 days, MAXTIME); // Ensure valid durations
            uint256 minAmountToMint = (MAXTIME ** 2 * 10) / duration ** 2 + 1;
            uint256 amount = bound(amounts[i], minAmountToMint, 100e18); // Ensure reasonable amounts
    
            totalAmount += amount;
            totalDuration += duration;

            vm.prank(users.owner);
            puppetToken.mint(users.alice, amount);

            vm.startPrank(users.alice);
            puppetToken.approve(address(router), amount);
            veRouter.lock(amount, duration);
            vm.stopPrank();
        }
    
        assertEq(vPuppetToken.balanceOf(users.alice), totalAmount, "Total locked amount should be at least the sum of individual locks");
        assertLe(veStore.getLockDuration(users.alice), MAXTIME, "Lock duration should not exceed MAXTIME");
    }
    
    function testFuzzVestPartial(uint256 lockAmount, uint256 lockDuration, uint256 vestAmount, uint256 timeElapsed) public {
    
        lockDuration = bound(lockDuration, 1 days, MAXTIME);
        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / lockDuration ** 2 + 1;
        lockAmount = bound(lockAmount, minAmountToMint, 100e18);
        vestAmount = bound(vestAmount, 1, lockAmount);
        timeElapsed = bound(timeElapsed, 0, lockDuration);
    
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), lockAmount);
        veRouter.lock(lockAmount, lockDuration);
    
        skip(timeElapsed);
    
        veRouter.vest(vestAmount);
        vm.stopPrank();
    
        assertLe(vPuppetToken.balanceOf(users.alice), lockAmount, "vPuppet balance should decrease after vesting");
        assertGe(veLogic.getVestingCursor(users.alice).amount, 0, "Vesting amount should be non-negative");
    }
    
    function testFuzzClaimPartial(uint256 lockAmount, uint256 lockDuration, uint256 timeElapsed, uint256 claimAmount) public {

        lockDuration = bound(lockDuration, 1 days, MAXTIME);
        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / lockDuration ** 2 + 1;
        lockAmount = bound(lockAmount, minAmountToMint, 100e18);
        timeElapsed = bound(timeElapsed, 0, lockDuration);
    
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), lockAmount);
        veRouter.lock(lockAmount, lockDuration);
        veRouter.vest(lockAmount);
    
        skip(timeElapsed);
    
        uint256 claimable = veLogic.getClaimable(users.alice);
        claimAmount = bound(claimAmount, 0, claimable);
        
        uint256 balanceBefore = puppetToken.balanceOf(users.alice);
        if (claimAmount > 0) {
            veRouter.claim(claimAmount);
        }
        vm.stopPrank();

        uint256 balanceAfter = puppetToken.balanceOf(users.alice);
    
        assertEq(veLogic.getClaimable(users.alice), claimable - claimAmount, "Claimable amount should decrease after claiming");
        assertEq(balanceAfter - balanceBefore, claimAmount, "User should receive claimed tokens");
    }

    function testFuzzLockVestAndClaim(uint256 amount, uint256 duration, uint256 timestamp) public {
        // precision ranges
        // duration = bound(duration, 0, MAXTIME);
        duration = duration > MAXTIME ? MAXTIME : (duration < 1 days ? 1 days : duration);
        // Remove dust Amounts which causes this VotingEscrowLogic__ZeroAmount
        uint256 minAmountToMint = (MAXTIME ** 2 * 10) / duration ** 2 + 1;
        amount = amount > 100e18 ? 100e18 : (amount < minAmountToMint ? minAmountToMint : amount);
        // amount = bound(amount, minAmountToMint, 100e18);
        timestamp = timestamp > 63120001 ? 63120001 : timestamp;
        // timestamp = bound(timestamp, 0, 63120001);
        
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), amount);

        veRouter.lock(amount, duration);
        veRouter.vest(amount);

        skip(timestamp);
        uint256 claimable = veLogic.getClaimable(users.alice);
        if (claimable > 0) {
            veRouter.claim(claimable);
        }

        assert(true);
    }
    
    function testFuzzLockVestClaimMultiUser(uint256[3] memory amounts, uint256[3] memory durations, uint256 timeElapsed) public {
        address payable[3] memory usersArray = [users.alice, users.bob, users.yossi];
    
        for (uint256 i = 0; i < 3; i++) {
            
            durations[i] = bound(durations[i], 1 days, MAXTIME);
            uint256 minAmountToMint = (MAXTIME ** 2 * 10) / durations[i] ** 2 + 1;
            amounts[i] = bound(amounts[i], minAmountToMint, 100e18);
    
            vm.startPrank(usersArray[i]);
            puppetToken.approve(address(router), amounts[i]);
            veRouter.lock(amounts[i], durations[i]);
            veRouter.vest(amounts[i]);
            vm.stopPrank();
        }
    
        timeElapsed = bound(timeElapsed, 0, MAXTIME);
        skip(timeElapsed);
        
        uint256 balanceBefore;
        uint256 balanceAfter;
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(usersArray[i]);
            balanceBefore = puppetToken.balanceOf(usersArray[i]);
            uint256 claimable = veLogic.getClaimable(usersArray[i]);
            if (claimable > 0) {
                veRouter.claim(claimable);
            }
            balanceAfter = puppetToken.balanceOf(usersArray[i]);
            vm.stopPrank();
    
            assertEq(veLogic.getClaimable(usersArray[i]), 0, "All claimable tokens should be claimed");
            assertEq(balanceAfter - balanceBefore, claimable, "User should receive claimed tokens");
        }
    }

}

contract VotingEscrowRouter {
    VotingEscrowLogic votingEscrow;

    constructor(VotingEscrowLogic _votingEscrow) {
        votingEscrow = _votingEscrow;
    }

    function lock(uint amount, uint duration) public {
        votingEscrow.lock(msg.sender, msg.sender, amount, duration);
    }

    function vest(uint amount) public {
        votingEscrow.vest(msg.sender, msg.sender, amount);
    }

    function claim(uint amount) public {
        votingEscrow.claim(msg.sender, msg.sender, amount);
    }
}
