// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Router} from "src/shared/Router.sol";

import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract VotingEscrowTest is BasicSetup {
    uint private constant MAXTIME = 2 * 365 * 86400; // 4 years

    PuppetVoteToken puppetVoteToken;
    VotingEscrowStore veStore;
    VotingEscrowLogic veLogic;
    VotingEscrowRouter veRouter;

    function setUp() public override {
        BasicSetup.setUp();

        puppetVoteToken = new PuppetVoteToken(dictator);
        veStore = new VotingEscrowStore(dictator, router);

        veLogic = new VotingEscrowLogic(
            dictator, //
            eventEmitter,
            veStore,
            puppetToken,
            puppetVoteToken,
            VotingEscrowLogic.Config({baseMultiplier: 0.5e30})
        );
        veRouter = new VotingEscrowRouter(veLogic);

        dictator.setAccess(eventEmitter, address(veLogic));
        dictator.setAccess(veStore, address(veLogic));

        dictator.setPermission(puppetToken, address(veLogic), puppetToken.mint.selector);
        dictator.setAccess(puppetVoteToken, address(veLogic));

        // test setup
        dictator.setPermission(puppetToken, users.owner, puppetToken.mint.selector);

        puppetToken.mint(users.alice, 100 * 1e18);
        puppetToken.mint(users.bob, 100 * 1e18);
        puppetToken.mint(users.yossi, 100 * 1e18);

        dictator.setAccess(router, address(veLogic));
        dictator.setAccess(veLogic, address(veRouter));

        vm.stopPrank();
    }

    // function testBonusMultiplier() public view {
    //     uint amount = 100e18; // The locked amount

    //     assertEq(veLogic.getBonusAmount(amount, 0), 0, "Bonus amount should be zero for zero duration");
    //     assertEq(
    //         veLogic.getBonusAmount(amount, 365 days / 2), 3.125e18, "Bonus amount should be zero for half duration"
    //     );
    //     assertEq(veLogic.getBonusAmount(amount, 1 * 365 days), 12.5e18, "Bonus amount should be zero for full
    // duration");
    //     assertEq(veLogic.getBonusAmount(amount, 2 * 365 days), 50e18, "Bonus amount should be zero for double
    // duration");
    // }

    // function testLock() public {
    //     uint amount = 10 * 1e18;
    //     uint duration = 365 days;

    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);
    //     vm.stopPrank();

    //     uint bonusAmount = veLogic.getBonusAmount(amount, duration);

    //     uint lock = veStore.getLockDuration(users.alice);
    //     assertEq(lock.amount, amount + bonusAmount, "Lock amount should match");
    //     assertEq(lock.duration, duration, "Lock duration should match");
    // }

    // function testLockAveraging() public {
    //     uint initialAmount = 10 * 1e18;
    //     uint additionalAmount = 20 * 1e18;
    //     uint initialDuration = 365 days;
    //     uint additionalDuration = 730 days; // 2 years

    //     // Alice locks an initial amount with a certain duration
    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), initialAmount + additionalAmount);
    //     veRouter.lock(initialAmount, initialDuration);

    //     // Alice locks an additional amount with a different duration
    //     veRouter.lock(additionalAmount, additionalDuration);
    //     vm.stopPrank();

    //     // Calculate the expected average duration
    //     uint expectedAverageDuration = (initialAmount * initialDuration + additionalAmount * additionalDuration)
    //         / (initialAmount + additionalAmount);

    //     // Retrieve the lock information from the contract
    //     VotingEscrowStore.Lock memory lock = veStore.getLocked(users.alice);

    //     // Check that the total locked amount is the sum of the initial and additional amounts
    //     assertEq(lock.amount, initialAmount + additionalAmount, "Total locked amount should match");

    //     // Check that the lock duration is correctly averaged
    //     assertEq(lock.duration, expectedAverageDuration, "Lock duration should be correctly averaged");
    // }

    // function testVest() public {
    //     uint amount = 10 * 1e18;
    //     uint duration = 365 days;

    //     // Alice locks tokens
    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);

    //     // Alice vests a portion of the locked tokens
    //     uint vestAmount = 5 * 1e18;
    //     veRouter.vest(vestAmount);
    //     vm.stopPrank();

    //     // Check the vesting schedule
    //     VotingEscrowStore.Vested memory vest = veStore.getVested(users.alice);
    //     assertEq(vest.amount, amount - vestAmount, "Vested amount should be reduced from total locked amount");
    //     assertEq(vest.accrued, 0, "Accrued amount should be zero initially");
    //     assertGt(vest.remainingDuration, 0, "Remaining duration should be greater than zero");
    // }

    // function testClaim() public {
    //     uint amount = 10e18;
    //     uint duration = 365 days;

    //     // Alice locks tokens
    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);

    //     // Alice vests all locked tokens
    //     veRouter.vest(amount);

    //     // Simulate time passing
    //     uint timePassed = duration / 2;
    //     skip(timePassed);

    //     // uint accruedAmount = votingEscrow.getVestingCursor(users.alice).accrued;

    //     // Alice claims a portion of the vested tokens
    //     veRouter.claim(1);

    //     // Check the vesting schedule after claiming
    //     VotingEscrowStore.Vested memory vest = veStore.getVested(users.alice);
    //     assertApproxEqAbs(amount / 2, amount / 2, 0.01e18, "Accrued amount should match the claimed amount");
    //     assertEq(vest.remainingDuration, duration - timePassed, "Remaining duration should be reduced by time
    // passed");
    //     // vm.stopPrank();
    // }

    // function testFailClaimTooMuch() public {
    //     uint amount = 10 * 1e18;
    //     uint duration = 365 days;

    //     // Alice locks tokens
    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);

    //     // Alice vests all locked tokens
    //     veRouter.vest(amount);

    //     // Simulate time passing
    //     uint timePassed = duration / 2;
    //     vm.warp(block.timestamp + timePassed);

    //     // Alice tries to claim more than the vested amount
    //     uint claimAmount = amount * 2; // Excessive claim amount
    //     veRouter.claim(claimAmount); // This should fail
    //     vm.stopPrank();
    // }

    // function testVestMoreThanLocked() public {
    //     uint amount = 10 * 1e18;
    //     uint duration = 365 days;

    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(VotingEscrowLogic.VotingEscrowLogic__ExceedingLockAmount.selector, amount)
    //     );
    //     veRouter.vest(amount + 1); // Attempt to vest more than locked amount, should fail
    //     vm.stopPrank();
    // }

    // function testClaimMoreThanVested() public {
    //     uint amount = 10 * 1e18;
    //     uint duration = 365 days;

    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), amount);
    //     veRouter.lock(amount, duration);
    //     veRouter.vest(amount);
    //     skip(block.timestamp + duration + 10); // Fast-forward time
    //     vm.expectRevert(
    //         abi.encodeWithSelector(VotingEscrowLogic.VotingEscrowLogic__ExceedingAccruedAmount.selector, amount)
    //     );
    //     veRouter.claim(amount + 1); // Attempt to claim more than vested amount, should fail
    //     vm.stopPrank();
    // }

    // function testZeroAmount() public {
    //     uint zeroAmount = 0;
    //     uint duration = 365 days;

    //     vm.startPrank(users.alice);
    //     puppetToken.approve(address(router), zeroAmount);
    //     vm.expectRevert(abi.encodeWithSelector(VotingEscrowLogic.VotingEscrowLogic__ZeroAmount.selector));
    //     veRouter.lock(zeroAmount, duration);
    //     vm.stopPrank();
    // }

    // function testAliceLockVestAndPartialClaimOverTime() public {
    //     uint aliceAmount = 10e18;
    //     uint aliceDuration = 365 days;

    //     vm.startPrank(users.alice);

    //     // Alice locks tokens
    //     puppetToken.approve(address(router), aliceAmount);
    //     veRouter.lock(aliceAmount, aliceDuration);

    //     // Alice vests some of her tokens
    //     veRouter.vest(aliceAmount / 2);
    //     skip(aliceDuration / 2);
    //     veRouter.vest(aliceAmount / 2);
    //     skip(aliceDuration);

    //     // Check that the claimed amount is correct
    //     assertApproxEqAbs(
    //         veStore.getVested(users.alice).accrued,
    //         aliceAmount / 4,
    //         1e8,
    //         "Alice's accrued amount should match the first claimed amount"
    //     );

    //     // Simulate more time passing for Alice to claim the second portion
    //     assertApproxEqAbs(
    //         votingEscrow.getClaimable(users.alice),
    //         aliceAmount,
    //         1e8,
    //         "Alice's total accrued amount should match the total claimed amount"
    //     );

    //     // Alice claims a portion of her vested tokens
    //     veRouter.claim(aliceAmount);
    // }
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
