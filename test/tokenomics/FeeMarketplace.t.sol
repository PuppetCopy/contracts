// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";

contract FeeMarketplaceTest is BasicSetup {
    FeeMarketplaceStore feeMarketplaceStore;
    FeeMarketplace feeMarketplace;

    function setUp() public override {
        super.setUp();

        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({transferOutGasLimit: 200_000, distributionTimeframe: 1 days})
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.syncBalance.selector, users.owner);

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        dictator.registerContract(feeMarketplace);

        vm.startPrank(users.owner);
    }

    function testFullLifecycle() public {
        feeMarketplace.setAskPrice(usdc, 10e18);
        feeMarketplace.setAskPrice(wnt, 5e18);

        uint initialSupply = puppetToken.totalSupply();

        feeMarketplace.deposit(usdc, users.owner, 500e6);
        feeMarketplace.deposit(wnt, users.owner, 50e18);

        skip(1 days);

        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 250e6);
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 250e6);

        feeMarketplace.deposit(usdc, users.owner, 300e6);
        skip(12 hours);

        feeMarketplace.acceptOffer(usdc, users.owner, users.bob, 150e6);
        feeMarketplace.acceptOffer(wnt, users.owner, users.bob, 25e18);

        assertEq(usdc.balanceOf(users.alice), 500e6, "Alice should receive 500e6 USDC");
        assertEq(usdc.balanceOf(users.bob), 150e6, "Bob should receive 150e6 USDC");
        assertEq(wnt.balanceOf(users.bob), 25e18, "Bob should receive 25e18 WNT");

        uint totalBurned = 35e18;
        assertEq(initialSupply - puppetToken.totalSupply(), totalBurned, "Total supply must decrease by burned amount");

        assertEq(feeMarketplace.unclockedFees(usdc), 0, "USDC accrued fees must be 0");
        assertEq(feeMarketplace.unclockedFees(wnt), 25e18, "WNT accrued fees mismatch");
    }

    function testDepositUpdatesState() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "FeeMarketplaceStore balance mismatch after deposit");
        assertEq(
            feeMarketplace.lastDistributionTimestamp(usdc),
            block.timestamp,
            "lastUpdateTimestamp should equal current block time"
        );
        assertEq(feeMarketplace.unclockedFees(usdc), 0, "Accrued fees should be zero immediately after deposit");
    }

    function testBuyAndBurnSuccess() public {
        uint initialSupply = puppetToken.totalSupply();

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);

        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);

        assertEq(usdc.balanceOf(users.alice), 50e6, "Alice should receive 50e6 USDC");
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Protocol token supply decreased by burn amount");
        assertEq(feeMarketplace.unclockedFees(usdc), 50e6, "Remaining unlocked fee for USDC must be updated");
    }

    function testPartialUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(6 hours);
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 25e6, "Expected 25e6 pending unlock after 6 hours");
    }

    function testZeroBuybackQuote() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 0);
        skip(1 days);

        vm.expectRevert(Error.FeeMarketplace__NotAuctionableToken.selector);
        feeMarketplace.acceptOffer(puppetToken, users.owner, users.alice, 50e6);
    }

    function testUnauthorizedAccess() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Error.Permission__Unauthorized.selector));
        feeMarketplace.deposit(usdc, users.alice, 50e6);
    }

    function testMultipleDeposits() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours);

        uint totalUnlocked = feeMarketplace.getTotalUnlocked(usdc);
        assertEq(totalUnlocked, 125e6, "Multi-deposit drip mismatch");
    }

    function testConfigUpdate() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        FeeMarketplace.Config memory newConfig =
            FeeMarketplace.Config({transferOutGasLimit: 200_000, distributionTimeframe: 2 days});
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        skip(1 days);
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Updated config not resulting in correct unlock");
    }

    function testExactTimeUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(1 days + 1 seconds);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6, "After 1 day +, entire deposit should be unlocked");
    }

    function testSmallAmountPrecision() public {
        feeMarketplace.deposit(usdc, users.owner, 1);
        skip(12 hours);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 0, "Small deposit should not unlock fractions");
        skip(12 hours);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 1, "Fraction should round up after full time");
    }

    function testMaxPurchase() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint maxAmount = feeMarketplace.getTotalUnlocked(usdc);

        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, maxAmount);
        assertEq(usdc.balanceOf(users.alice), maxAmount, "Alice should receive full unlocked balance");
        assertEq(feeMarketplace.unclockedFees(usdc), 0, "No unlocked balance should remain");
    }

    function testZeroDepositReverts() public {
        vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
        feeMarketplace.deposit(usdc, users.owner, 0);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 0, "No tokens should be deposited for zero amount");
    }

    function testZeroPurchaseAmountReverts() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);

        vm.expectRevert(Error.FeeMarketplace__InvalidAmount.selector);
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 0);
    }

    function testSyncBalance() public {
        // Direct transfer to store (bypassing deposit)
        usdc.mint(users.alice, 100e6);
        vm.stopPrank();
        vm.prank(users.alice);
        require(usdc.transfer(address(feeMarketplaceStore), 100e6));

        // Balance is in store but not accounted - should not unlock
        assertEq(feeMarketplace.accountedBalance(usdc), 0, "Accounted balance should be 0");
        assertEq(feeMarketplace.getPendingUnlock(usdc), 0, "Pending should be 0 before sync");

        // Sync the balance
        vm.prank(users.owner);
        feeMarketplace.syncBalance(usdc);

        assertEq(feeMarketplace.accountedBalance(usdc), 100e6, "Accounted balance should be updated");
        assertEq(feeMarketplace.lastDistributionTimestamp(usdc), block.timestamp, "Timestamp should be set");

        // Now tokens should unlock over time
        skip(1 days);
        assertEq(feeMarketplace.getTotalUnlocked(usdc), 100e6, "Full amount should be unlocked after 1 day");
    }

    function testDirectTransferDoesNotUnlock() public {
        // Direct transfer to store without sync
        usdc.mint(users.alice, 100e6);
        vm.stopPrank();
        vm.prank(users.alice);
        require(usdc.transfer(address(feeMarketplaceStore), 100e6));

        skip(1 days);

        // Should NOT be unlocked since not synced
        assertEq(feeMarketplace.getTotalUnlocked(usdc), 0, "Direct transfers should not auto-unlock");
    }

    function testSyncBalanceNoNewTokensReverts() public {
        vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
        feeMarketplace.syncBalance(usdc);
    }
}
