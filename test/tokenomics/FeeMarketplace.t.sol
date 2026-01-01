// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";

contract FeeMarketplaceTest is BasicSetup {
    FeeMarketplaceStore feeMarketplaceStore;
    FeeMarketplace feeMarketplace;

    uint constant UNLOCK_TIMEFRAME = 1 days;
    uint constant ASK_DECAY_TIMEFRAME = 1 days;
    uint constant ASK_START = 100e18;

    function setUp() public override {
        super.setUp();

        feeMarketplaceStore = new FeeMarketplaceStore(dictator, puppetToken);
        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000,
                unlockTimeframe: UNLOCK_TIMEFRAME,
                askDecayTimeframe: ASK_DECAY_TIMEFRAME,
                askStart: ASK_START
            })
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.recordTransferIn.selector, users.owner);

        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        dictator.registerContract(address(feeMarketplace));

        vm.startPrank(users.owner);

        // Approve feeMarketplaceStore to pull tokens for deposits and acceptOffer
        usdc.approve(address(feeMarketplaceStore), type(uint).max);
        wnt.approve(address(feeMarketplaceStore), type(uint).max);
        puppetToken.approve(address(feeMarketplaceStore), type(uint).max);
    }

    // Helper to accept offer for all unlocked fees
    function _acceptOfferAll(address token, address receiver) internal {
        uint amount = feeMarketplace.getUnlockedBalance(IERC20(token));
        feeMarketplace.acceptOffer(IERC20(token), users.owner, receiver, amount);
    }

    function testDepositUpdatesState() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "Store balance mismatch");
        assertEq(feeMarketplace.lastUnlockTimestampMap(usdc), block.timestamp, "lastUnlockTimestamp should be set");
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 0, "Unlocked fees should be zero immediately");
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 100e6, "Accounted balance should match deposit");
    }

    function testPartialUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Expected 50% unlock after 12 hours");
    }

    function testFullUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME + 1);

        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6, "Full deposit should unlock after timeframe");
    }

    function testAskDecaysWithTime() public {
        // Before any redemption, ask is always config.askStart
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask should start at askStart");

        // First redeem to start the decay clock
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.alice);
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask resets to askStart after redeem");

        // New deposit to have something to redeem
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Now check decay over time
        skip(12 hours);
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START / 2, "Ask should halve at mid timeframe");

        skip(12 hours);
        assertEq(feeMarketplace.getAskPrice(usdc), 0, "Ask should be 0 after full decay");
    }

    function testAcceptOfferBurnsTokens() public {
        uint initialSupply = puppetToken.totalSupply();

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        uint askBefore = feeMarketplace.getAskPrice(usdc);
        _acceptOfferAll(address(usdc), users.alice);

        assertEq(usdc.balanceOf(users.alice), 100e6, "Alice should receive all unlocked fees");
        assertEq(puppetToken.totalSupply(), initialSupply - askBefore, "PUPPET should be burned");
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 0, "Unlocked fees should be zero after redeem");
    }

    function testAcceptOfferResetsAsk() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        _acceptOfferAll(address(usdc), users.alice);

        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask should reset to askStart after redeem");
        assertEq(feeMarketplace.lastAskResetTimestampMap(usdc), block.timestamp, "Reset timestamp should be updated");
    }

    function testAcceptOfferAtZeroCostWhenDecayed() public {
        uint initialSupply = puppetToken.totalSupply();

        // First cycle: deposit and redeem to start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);
        uint supplyAfterFirstRedeem = puppetToken.totalSupply();

        // Second deposit - decay clock is now running
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(ASK_DECAY_TIMEFRAME + 1);

        assertEq(feeMarketplace.getAskPrice(usdc), 0, "Ask should be 0");

        _acceptOfferAll(address(usdc), users.alice);

        assertEq(usdc.balanceOf(users.alice), 100e6, "Alice should receive fees");
        assertEq(puppetToken.totalSupply(), supplyAfterFirstRedeem, "No PUPPET should be burned at 0 ask");
    }

    function testMultipleDepositsUnlockCorrectly() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        uint totalUnlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(totalUnlocked, 125e6, "Multi-deposit unlock calculation mismatch");
    }

    function testZeroDepositReverts() public {
        vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
        feeMarketplace.deposit(usdc, users.owner, 0);
    }

    function testAcceptOfferWithNothingUnlockedReverts() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Try to redeem 50e6 when nothing is unlocked
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientUnlockedBalance.selector, 0));
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);
    }

    function testUnauthorizedAccess() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Error.Permission__Unauthorized.selector));
        feeMarketplace.deposit(usdc, users.alice, 50e6);
    }

    function testRecordTransferIn() public {
        usdc.mint(users.alice, 100e6);
        vm.stopPrank();
        vm.prank(users.alice);
        usdc.transfer(address(feeMarketplaceStore), 100e6);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 0, "Accounted balance should be 0 before sync");

        vm.prank(users.owner);
        feeMarketplace.recordTransferIn(usdc);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 100e6, "Accounted balance should update after sync");
        assertEq(feeMarketplace.lastUnlockTimestampMap(usdc), block.timestamp, "Timestamp should be set");

        skip(UNLOCK_TIMEFRAME);
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 100e6, "Full amount should unlock");
    }

    function testRecordTransferInNoTokensReverts() public {
        vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
        feeMarketplace.recordTransferIn(usdc);
    }

    function testDirectTransferDoesNotUnlock() public {
        usdc.mint(users.alice, 100e6);
        vm.stopPrank();
        vm.prank(users.alice);
        usdc.transfer(address(feeMarketplaceStore), 100e6);

        skip(UNLOCK_TIMEFRAME);

        assertEq(feeMarketplace.getUnlockedBalance(usdc), 0, "Direct transfers should not auto-unlock");
    }

    function testConfigValidation() public {
        vm.expectRevert(Error.FeeMarketplace__InvalidConfig.selector);
        new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000, unlockTimeframe: 2 days, askDecayTimeframe: 1 days, askStart: 100e18
            })
        );
    }

    function testFairness_WaitingReducesCost() public {
        // Initial setup: deposit, wait for full unlock, redeem to start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.owner);

        // Deposit new fees
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Check cost per USDC at different points in the decay cycle
        skip(6 hours); // 25% through decay
        uint ask25 = feeMarketplace.getAskPrice(usdc);
        uint unlocked25 = feeMarketplace.getUnlockedBalance(usdc);
        uint costPerUsdc25 = unlocked25 > 0 ? (ask25 * 1e6) / unlocked25 : type(uint).max;

        skip(6 hours); // 50% through decay
        uint ask50 = feeMarketplace.getAskPrice(usdc);
        uint unlocked50 = feeMarketplace.getUnlockedBalance(usdc);
        uint costPerUsdc50 = unlocked50 > 0 ? (ask50 * 1e6) / unlocked50 : type(uint).max;

        skip(6 hours); // 75% through decay
        uint ask75 = feeMarketplace.getAskPrice(usdc);
        uint unlocked75 = feeMarketplace.getUnlockedBalance(usdc);
        uint costPerUsdc75 = unlocked75 > 0 ? (ask75 * 1e6) / unlocked75 : type(uint).max;

        // Verify: waiting longer = lower cost per USDC
        assertGt(costPerUsdc25, costPerUsdc50, "Cost at 25% should be higher than at 50%");
        assertGt(costPerUsdc50, costPerUsdc75, "Cost at 50% should be higher than at 75%");

        // Verify ask decays
        assertGt(ask25, ask50, "Ask at 25% should be higher than at 50%");
        assertGt(ask50, ask75, "Ask at 50% should be higher than at 75%");

        // Verify unlock increases
        assertLt(unlocked25, unlocked50, "Unlocked at 25% should be less than at 50%");
        assertLt(unlocked50, unlocked75, "Unlocked at 50% should be less than at 75%");
    }

    function testFairness_GradualUnlockPreventsSpike() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        _acceptOfferAll(address(usdc), users.alice);

        feeMarketplace.deposit(usdc, users.owner, 1000e6);

        uint immediateUnlock = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(immediateUnlock, 0, "New deposit should not immediately unlock");

        skip(12 hours);
        uint partialUnlock = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(partialUnlock, 500e6, "Should unlock 50% after half timeframe");
    }

    function testFairness_AskResetsAfterAcceptOffer() public {
        // First cycle to start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);

        // Second cycle - let ask decay to 0
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(ASK_DECAY_TIMEFRAME);

        assertEq(feeMarketplace.getAskPrice(usdc), 0, "Ask decayed to 0");

        _acceptOfferAll(address(usdc), users.alice);

        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask should reset after redeem");

        // Third cycle - verify decay continues from reset
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        uint newAsk = feeMarketplace.getAskPrice(usdc);
        assertEq(newAsk, 0, "Ask continues decay from reset point");
    }

    function testFairness_NoFreeExtractionWhenConstraintHolds() public {
        uint totalBurned = 0;
        uint totalReceived = 0;

        feeMarketplace.deposit(usdc, users.owner, 100e6);

        for (uint i = 0; i < 3; i++) {
            skip(UNLOCK_TIMEFRAME / 3);

            uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
            if (unlocked == 0) continue;

            uint askBefore = feeMarketplace.getAskPrice(usdc);
            uint supplyBefore = puppetToken.totalSupply();

            _acceptOfferAll(address(usdc), users.owner);

            totalBurned += supplyBefore - puppetToken.totalSupply();
            totalReceived += unlocked;
        }

        assertGt(totalBurned, 0, "Should burn some PUPPET across redemptions");
    }

    // ==================== EDGE CASES ====================

    function testEdge_AcceptOfferAtExactUnlockBoundary() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME); // Exactly at boundary

        uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlocked, 100e6, "Should be fully unlocked at exact boundary");

        _acceptOfferAll(address(usdc), users.alice);
        assertEq(usdc.balanceOf(users.alice), 100e6, "Should receive full amount");
    }

    function testEdge_AcceptOfferAtExactAskDecayBoundary() public {
        // Start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);

        // New deposit, skip exactly to decay boundary
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(ASK_DECAY_TIMEFRAME); // Exactly at boundary

        uint ask = feeMarketplace.getAskPrice(usdc);
        assertEq(ask, 0, "Ask should be 0 at exact decay boundary");
    }

    function testEdge_DepositImmediatelyAfterRedeem() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.alice);

        // Deposit in same block as redeem
        feeMarketplace.deposit(usdc, users.owner, 50e6);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 50e6, "New deposit accounted");
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 0, "No unlocked fees yet");
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask just reset");
    }

    function testEdge_VerySmallDeposit() public {
        feeMarketplace.deposit(usdc, users.owner, 1); // 1 wei

        skip(UNLOCK_TIMEFRAME);
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 1, "Even 1 wei unlocks");

        _acceptOfferAll(address(usdc), users.alice);
        assertEq(usdc.balanceOf(users.alice), 1, "Received 1 wei");
    }

    function testEdge_VeryLargeDeposit() public {
        uint largeAmount = 1_000_000_000e6; // 1 billion USDC
        usdc.mint(users.owner, largeAmount);

        feeMarketplace.deposit(usdc, users.owner, largeAmount);

        skip(UNLOCK_TIMEFRAME);
        assertEq(feeMarketplace.getUnlockedBalance(usdc), largeAmount, "Large amount fully unlocks");

        _acceptOfferAll(address(usdc), users.alice);
        assertEq(usdc.balanceOf(users.alice), largeAmount, "Received large amount");
    }

    function testEdge_ManySmallDeposits() public {
        // 10 deposits of 10 USDC each
        for (uint i = 0; i < 10; i++) {
            feeMarketplace.deposit(usdc, users.owner, 10e6);
            skip(1 hours);
        }

        uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertGt(unlocked, 0, "Some amount unlocked");
        assertLt(unlocked, 100e6, "Not fully unlocked yet");

        skip(UNLOCK_TIMEFRAME);
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 100e6, "All eventually unlocks");
    }

    function testEdge_MultipleTokensIndependent() public {
        // Deposit different tokens
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.deposit(wnt, users.owner, 1e18);

        skip(12 hours);

        // Check they unlock independently
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 50e6, "USDC 50% unlocked");
        assertEq(feeMarketplace.getUnlockedBalance(wnt), 0.5e18, "WNT 50% unlocked");

        // Redeem one token
        _acceptOfferAll(address(usdc), users.alice);

        // Other token unaffected
        assertEq(feeMarketplace.getUnlockedBalance(wnt), 0.5e18, "WNT still 50%");
        assertEq(feeMarketplace.accountedBalanceMap(wnt), 1e18, "WNT accounted unchanged");
    }

    function testEdge_FirstDepositStartsBothClocks() public {
        // First deposit to empty marketplace starts both clocks
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(feeMarketplace.lastUnlockTimestampMap(usdc), block.timestamp, "Unlock clock started");
        assertEq(feeMarketplace.lastAskResetTimestampMap(usdc), block.timestamp, "Ask clock started");
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "Ask at askStart immediately after deposit");

        // Immediately redeem (0 unlocked) should fail
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientUnlockedBalance.selector, 0));
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 100e6);
    }

    function testEdge_DepositWhileUnlockedFeesWaiting() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // 50% unlocked

        uint unlockedBefore = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlockedBefore, 50e6, "50% unlocked");

        // New deposit checkpoints the unlock
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // unlockedFees should now include the 50e6
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 50e6, "Unlocked fees checkpointed");
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 200e6, "Total accounted");

        // After deposit, unlock rate considers new total locked
        skip(12 hours);
        uint unlockedAfter = feeMarketplace.getUnlockedBalance(usdc);
        // 50e6 already unlocked + 50% of remaining 150e6 = 50 + 75 = 125
        assertEq(unlockedAfter, 125e6, "Correct unlock after new deposit");
    }

    function testEdge_RecordTransferInAfterDirectTransfer() public {
        // Direct transfer (not through deposit)
        usdc.mint(users.alice, 100e6);
        vm.stopPrank();
        vm.prank(users.alice);
        usdc.transfer(address(feeMarketplaceStore), 100e6);

        // State not updated
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 0, "Not accounted yet");

        // recordTransferIn picks up the transfer
        vm.startPrank(users.owner);
        feeMarketplace.recordTransferIn(usdc);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 100e6, "Now accounted");

        // Can redeem after unlock
        skip(UNLOCK_TIMEFRAME);
        feeMarketplace.acceptOffer(usdc, users.owner, users.bob, 100e6);
        assertEq(usdc.balanceOf(users.bob), 100e6, "Received synced balance");
    }

    function testEdge_RecordTransferInWithExistingDeposit() public {
        // Normal deposit
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Direct transfer on top
        usdc.mint(users.alice, 50e6);
        vm.stopPrank();
        vm.prank(users.alice);
        usdc.transfer(address(feeMarketplaceStore), 50e6);

        // recordTransferIn picks up only the unaccounted portion
        vm.prank(users.owner);
        feeMarketplace.recordTransferIn(usdc);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 150e6, "Both amounts accounted");
    }

    function testEdge_AcceptOfferPartialThenFull() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Partial redeem at 50%
        skip(12 hours);
        _acceptOfferAll(address(usdc), users.alice);
        assertEq(usdc.balanceOf(users.alice), 50e6, "Got 50%");

        // Remaining 50e6 still locked, wait for full unlock
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);
        assertEq(usdc.balanceOf(users.bob), 50e6, "Got remaining 50%");

        // Nothing left
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 0, "All redeemed");
    }

    function testEdge_UnlockCalculationNeverExceedsLocked() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Skip way past unlock timeframe
        skip(UNLOCK_TIMEFRAME * 10);

        uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlocked, 100e6, "Capped at total deposited");
    }

    function testEdge_ZeroTimeElapsedAfterDeposit() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // No time skip
        assertEq(feeMarketplace.getPendingUnlock(usdc), 0, "No unlock at t=0");
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 0, "Nothing unlocked");
    }

    function testEdge_AcceptOfferInsufficientPuppetBalance() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // 50% unlocked, ask at 50%

        // Burn all PUPPET from owner
        uint ownerBalance = puppetToken.balanceOf(users.owner);
        vm.stopPrank();
        vm.prank(users.owner);
        puppetToken.transfer(users.alice, ownerBalance);

        // Try to redeem - should fail due to insufficient PUPPET (ask is 50% of askStart)
        vm.startPrank(users.owner);
        vm.expectRevert();
        feeMarketplace.acceptOffer(usdc, users.owner, users.owner, 50e6);
    }

    function testEdge_AskDecayPastTimeframe() public {
        // Start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);

        // New deposit, skip way past decay timeframe
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(ASK_DECAY_TIMEFRAME * 10);

        uint ask = feeMarketplace.getAskPrice(usdc);
        assertEq(ask, 0, "Ask stays at 0, never goes negative");
    }

    function testEdge_DepositResetsUnlockClock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        uint timestampBefore = feeMarketplace.lastUnlockTimestampMap(usdc);

        skip(1 hours);
        feeMarketplace.deposit(usdc, users.owner, 50e6);

        uint timestampAfter = feeMarketplace.lastUnlockTimestampMap(usdc);
        assertGt(timestampAfter, timestampBefore, "Unlock timestamp updated on deposit");
    }

    function testEdge_ConsecutiveRedeemsRequireNewDeposits() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.alice);

        // Try to redeem again without new deposit
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientUnlockedBalance.selector, 0));
        feeMarketplace.acceptOffer(usdc, users.owner, users.bob, 50e6);
    }

    function testEdge_PendingUnlockWhenFullyUnlocked() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        // All is unlocked (view function shows pending + already unlocked)
        assertEq(feeMarketplace.getUnlockedBalance(usdc), 100e6, "Fully unlocked");

        // Before checkpoint, pending equals the full locked amount
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 100e6, "Pending equals locked amount before checkpoint");

        // After checkpoint via deposit, the pending gets moved to unlockedFees
        feeMarketplace.deposit(usdc, users.owner, 1); // Minimal deposit to trigger sync
        pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 0, "No pending after checkpoint when fully unlocked");

        // unlockedFees now holds the checkpointed amount
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 100e6, "Unlocked fees checkpointed");
    }

    function testEdge_RoundingOnSmallUnlock() public {
        // Deposit amount that doesn't divide evenly by unlock timeframe
        feeMarketplace.deposit(usdc, users.owner, 7); // 7 wei

        // Skip 1 second - should unlock 7 * 1 / 86400 = 0 (rounds down)
        skip(1);
        uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlocked, 0, "Rounds down to 0 for tiny time");

        // Skip to exactly half - 7 * 43200 / 86400 = 3
        skip(UNLOCK_TIMEFRAME / 2 - 1);
        unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlocked, 3, "Rounds down on partial unlock");

        // Full unlock
        skip(UNLOCK_TIMEFRAME);
        unlocked = feeMarketplace.getUnlockedBalance(usdc);
        assertEq(unlocked, 7, "Full amount unlocks");
    }

    function testEdge_RoundingOnAskDecay() public {
        // Start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);

        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Skip 1 second - ask = askStart - (askStart * 1 / 86400)
        skip(1);
        uint ask = feeMarketplace.getAskPrice(usdc);
        uint expected = ASK_START - (ASK_START * 1) / ASK_DECAY_TIMEFRAME;
        assertEq(ask, expected, "Ask decay rounds down");
    }

    function testEdge_AskPriceIndependentPerToken() public {
        // Both tokens get deposits at same time - both clocks start
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.deposit(wnt, users.owner, 1e18);

        skip(12 hours);

        // Both should have decayed 50%
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START / 2, "USDC ask decayed 50%");
        assertEq(feeMarketplace.getAskPrice(wnt), ASK_START / 2, "WNT ask decayed 50%");

        // Redeem USDC - resets USDC ask
        _acceptOfferAll(address(usdc), users.alice);
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "USDC ask reset");

        // WNT ask unaffected
        assertEq(feeMarketplace.getAskPrice(wnt), ASK_START / 2, "WNT ask still at 50%");
    }

    function testEdge_AcceptOfferDoesNotAffectOtherTokenAsk() public {
        // Setup both tokens with decay clocks running
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.deposit(wnt, users.owner, 1e18);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.alice);
        _acceptOfferAll(address(wnt), users.alice);

        // Deposit more to both
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.deposit(wnt, users.owner, 1e18);

        skip(12 hours);

        // Redeem USDC - resets USDC ask
        _acceptOfferAll(address(usdc), users.bob);
        assertEq(feeMarketplace.getAskPrice(usdc), ASK_START, "USDC ask reset");

        // WNT ask should still be at 50% decay
        assertEq(feeMarketplace.getAskPrice(wnt), ASK_START / 2, "WNT ask unaffected");
    }

    function testEdge_DepositFromDifferentDepositors() public {
        // Owner deposits
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Alice deposits (via authorized call) - need to approve feeMarketplaceStore
        usdc.mint(users.alice, 50e6);
        vm.stopPrank();
        vm.prank(users.alice);
        usdc.approve(address(feeMarketplaceStore), 50e6);
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.alice, 50e6);

        assertEq(feeMarketplace.accountedBalanceMap(usdc), 150e6, "Both deposits accounted");
    }

    function testEdge_AcceptOfferToSelf() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        uint balanceBefore = usdc.balanceOf(users.owner);
        _acceptOfferAll(address(usdc), users.owner);

        assertEq(usdc.balanceOf(users.owner), balanceBefore + 100e6, "Received to self");
    }

    function testEdge_AcceptOfferToDifferentReceiver() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);

        uint ownerBalanceBefore = usdc.balanceOf(users.owner);
        uint aliceBalanceBefore = usdc.balanceOf(users.alice);

        _acceptOfferAll(address(usdc), users.alice);

        assertEq(usdc.balanceOf(users.owner), ownerBalanceBefore, "Owner balance unchanged");
        assertEq(usdc.balanceOf(users.alice), aliceBalanceBefore + 100e6, "Alice received");
    }

    function testEdge_UnlockProgressPreservedAcrossDeposits() public {
        // First deposit
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // 50% unlocked = 50e6

        // Second deposit checkpoints and adds more
        feeMarketplace.deposit(usdc, users.owner, 200e6);

        // State after checkpoint:
        // unlockedFees = 50e6 (checkpointed)
        // accountedBalance = 300e6
        // locked = 250e6

        assertEq(feeMarketplace.unlockedFeesMap(usdc), 50e6, "Previous unlock checkpointed");

        // Wait 6 hours - 25% of locked = 62.5e6 pending
        skip(6 hours);
        uint unlocked = feeMarketplace.getUnlockedBalance(usdc);
        // 50e6 + 250e6 * 6h / 24h = 50e6 + 62.5e6 = 112.5e6
        assertEq(unlocked, 112500000, "Unlock progress preserved");
    }

    function testEdge_ZeroAskMeansFreeFees() public {
        uint initialSupply = puppetToken.totalSupply();

        // First cycle to start decay clock
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);

        // Second cycle - wait for full decay
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(ASK_DECAY_TIMEFRAME + 1);

        uint supplyBefore = puppetToken.totalSupply();
        _acceptOfferAll(address(usdc), users.alice);

        // No PUPPET burned
        assertEq(puppetToken.totalSupply(), supplyBefore, "Zero PUPPET burned at 0 ask");
        assertEq(usdc.balanceOf(users.alice), 100e6, "Still received fees");
    }

    function testEdge_UnlockNeverCreatesNegativeLocked() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Partial redeem
        skip(12 hours);
        _acceptOfferAll(address(usdc), users.alice);

        // accountedBalance = 50e6, unlockedFees = 0 (reset after redeem)
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 50e6, "50e6 remains");
        assertEq(feeMarketplace.unlockedFeesMap(usdc), 0, "Unlocked reset to 0");

        // getPendingUnlock should never return more than locked
        skip(UNLOCK_TIMEFRAME * 100);
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Pending capped at remaining");
    }

    function testEdge_SequentialRedeemsSameToken() public {
        // Cycle 1
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.alice);
        assertEq(usdc.balanceOf(users.alice), 100e6, "Cycle 1: Alice got 100");

        // Cycle 2
        feeMarketplace.deposit(usdc, users.owner, 200e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.bob);
        assertEq(usdc.balanceOf(users.bob), 200e6, "Cycle 2: Bob got 200");

        // Cycle 3
        feeMarketplace.deposit(usdc, users.owner, 50e6);
        skip(UNLOCK_TIMEFRAME);
        _acceptOfferAll(address(usdc), users.owner);

        // Final state
        assertEq(feeMarketplace.accountedBalanceMap(usdc), 0, "All fees distributed");
    }
}
