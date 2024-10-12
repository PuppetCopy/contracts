// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Error} from "src/shared/Error.sol";
import {Router} from "src/shared/Router.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

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

        veLogic = new VotingEscrowLogic(dictator, eventEmitter, veStore, puppetToken, vPuppetToken);
        dictator.setAccess(eventEmitter, address(veLogic));
        dictator.setPermission(veLogic, veLogic.setConfig.selector, users.owner);
        dictator.setAccess(veStore, address(veLogic));

        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.burn.selector, address(veLogic));

        veRouter = new VotingEscrowRouter(veLogic);
        dictator.setPermission(veLogic, veLogic.lock.selector, address(veRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(veRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(veRouter));
        dictator.setPermission(puppetToken, puppetToken.mint.selector, users.owner);

        // test setup
        veLogic.setConfig(VotingEscrowLogic.Config({baseMultiplier: 0.1e30}));

        puppetToken.mint(users.alice, 100 * 1e18);
        puppetToken.mint(users.bob, 100 * 1e18);
        puppetToken.mint(users.yossi, 100 * 1e18);
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
        vm.expectRevert(Error.VotingEscrowLogic__ExceedMaxTime.selector);
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
}

contract VotingEscrowRouter {
    VotingEscrowLogic votingEscrow;

    constructor(
        VotingEscrowLogic _votingEscrow
    ) {
        votingEscrow = _votingEscrow;
    }

    function lock(uint amount, uint duration) public {
        votingEscrow.lock(msg.sender, msg.sender, amount, duration);
    }

    function vest(
        uint amount
    ) public {
        votingEscrow.vest(msg.sender, msg.sender, amount);
    }

    function claim(
        uint amount
    ) public {
        votingEscrow.claim(msg.sender, msg.sender, amount);
    }
}
