// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

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
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000,
                distributionTimeframe: 1 days,
                burnBasisPoints: 10000 // 100% burn
            })
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.collectDistribution.selector, users.owner);

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        dictator.initContract(feeMarketplace);

        vm.startPrank(users.owner);
    }

    //----------------------------------------------------------------------------
    // Full Lifecycle & Basic Functionality Tests
    //----------------------------------------------------------------------------

    function testFullLifecycle() public {
        // Phase 1: Setup ask prices.
        feeMarketplace.setAskPrice(usdc, 10e18); // 10 protocol tokens per USDC.
        feeMarketplace.setAskPrice(wnt, 5e18); // 5 protocol tokens per WNT.

        // Capture initial puppet token supply.
        uint initialSupply = puppetToken.totalSupply();

        // Phase 2: Deposit tokens
        feeMarketplace.deposit(usdc, users.owner, 500e6);
        feeMarketplace.deposit(wnt, users.owner, 50e18);

        // Phase 3: Unlock fees after 1 day.
        skip(1 days);

        // Phase 4: Owner accepts offers on behalf of Alice
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 250e6); // Burns 10e18.
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 250e6); // Burns another 10e18.

        // Phase 5: Second deposit and partial unlock.
        feeMarketplace.deposit(usdc, users.owner, 300e6);
        skip(12 hours); // Roughly 50% available (150e6 unlocked).

        // Phase 6: Owner accepts offers on behalf of Bob
        feeMarketplace.acceptOffer(usdc, users.owner, users.bob, 150e6); // Burns 10e18.
        feeMarketplace.acceptOffer(wnt, users.owner, users.bob, 25e18); // Burns 5e18.

        // Final verifications.
        assertEq(usdc.balanceOf(users.alice), 500e6, "Alice should receive 500e6 USDC");
        assertEq(usdc.balanceOf(users.bob), 150e6, "Bob should receive 150e6 USDC");
        assertEq(wnt.balanceOf(users.bob), 25e18, "Bob should receive 25e18 WNT");

        uint totalBurned = 35e18; // 10 + 10 + 10 + 5.
        assertEq(initialSupply - puppetToken.totalSupply(), totalBurned, "Total supply must decrease by burned amount");

        // Check accrued fees for each token.
        assertEq(feeMarketplace.unclockedFees(usdc), 0, "USDC accrued fees must be 0");
        assertEq(feeMarketplace.unclockedFees(wnt), 25e18, "WNT accrued fees mismatch");
    }

    function testDepositUpdatesState() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "BankStore balance mismatch after deposit");
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

        // Owner accepts offer on behalf of Alice
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);

        // Verify fee token transfer and supply burn.
        assertEq(usdc.balanceOf(users.alice), 50e6, "Alice should receive 50e6 USDC");
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Protocol token supply decreased by burn amount");
        assertEq(feeMarketplace.unclockedFees(usdc), 50e6, "Remaining unlocked fee for USDC must be updated");
    }

    function testPartialUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(6 hours); // 25% unlock over half a day.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 25e6, "Expected 25e6 pending unlock after 6 hours");
    }

    function testZeroBuybackQuote() public {
        // Deposit 100e6 USDC into the fee marketplace.
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Set the ask price for USDC to 0, making it non-auctionable.
        feeMarketplace.setAskPrice(usdc, 0);

        // Skip 1 day to allow any potential unlocks.
        skip(1 days);

        // Expect a revert with the NotAuctionableToken error when trying to accept an offer
        // for puppet tokens with a zero ask price.
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
        // First deposit of 100e6 at time 0.
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // First deposit accrues 50e6 (half unlocked).

        // Second deposit occurs at t = 12 hours.
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // At t = 24 hours total.

        // Now, due to the deposit updates, the expected total unlocked amount is 125e6.
        // Explanation:
        // - First deposit: 50e6 (already unlocked within the first 12 hours, then no further accrual as
        // lastUpdateTimestamp resets).
        // - Second deposit: pending unlock = min( (netNewDeposits * 12h / 1 day), netNewDeposits )
        //   where netNewDeposits for USDC is now (200e6 - alreadyUnlocked) = 150e6, so it adds 75e6.
        // Total unlocked = 50e6 + 75e6 = 125e6.
        uint totalUnlocked = feeMarketplace.getTotalUnlocked(usdc);
        assertEq(totalUnlocked, 125e6, "Multi-deposit drip mismatch");
    }

    function testConfigUpdate() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Update config: increase distribution timeframe to 2 days.
        FeeMarketplace.Config memory newConfig =
            FeeMarketplace.Config({transferOutGasLimit: 200_000, distributionTimeframe: 2 days, burnBasisPoints: 10000});
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        skip(1 days); // Now only about 50% (50e6) should have unlocked.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Updated config not resulting in correct unlock");
    }

    function testBurnAddressReceipt() public {
        uint initialSupply = puppetToken.totalSupply();
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);

        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);
        // In 100% burn config, supply should decrease fully.
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Burn amount must equal ask price in full-burn mode");
    }

    function testExactTimeUnlock() public {
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        // Skip 1 day plus a few seconds.
        skip(1 days + 1 seconds);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6, "After 1 day +, entire deposit should be unlocked");
    }

    function testSmallAmountPrecision() public {
        feeMarketplace.deposit(usdc, users.owner, 1); // Deposit 1 wei USDC.
        skip(12 hours);
        // Expect rounding down yields 0 pending unlock.
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

    function testPartialBurnWithDistribution() public {
        // Change config: 50% burn, remaining for distribution.
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            transferOutGasLimit: 200_000,
            distributionTimeframe: 1 days,
            burnBasisPoints: 5000 // 50% burn.
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint initialSupply = puppetToken.totalSupply();
        uint initialDistributionBalance = feeMarketplace.distributionBalance();

        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);
        // Expect 50% of 10e18 burned, 50% added to distribution balance.
        assertEq(puppetToken.totalSupply(), initialSupply - 5e18, "Total burned amount should be 5e18");
        assertEq(
            feeMarketplace.distributionBalance(),
            initialDistributionBalance + 5e18,
            "Distribution balance should increase by 5e18"
        );
    }

    function testCollectDistribution() public {
        // Set up partial burn config
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            transferOutGasLimit: 200_000,
            distributionTimeframe: 1 days,
            burnBasisPoints: 5000 // 50% burn
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));

        // Create distribution balance
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        feeMarketplace.acceptOffer(usdc, users.owner, users.alice, 50e6);

        uint distributionBalance = feeMarketplace.distributionBalance();
        assertEq(distributionBalance, 5e18, "Distribution balance should be 5e18");

        uint initialBobBalance = puppetToken.balanceOf(users.bob);

        // Collect partial distribution
        feeMarketplace.collectDistribution(users.bob, 3e18);

        assertEq(puppetToken.balanceOf(users.bob), initialBobBalance + 3e18, "Bob should receive 3e18 tokens");
        assertEq(feeMarketplace.distributionBalance(), 2e18, "Distribution balance should be reduced to 2e18");
    }

    function testCollectDistributionInvalidReceiver() public {
        vm.expectRevert(Error.FeeMarketplace__InvalidReceiver.selector);
        feeMarketplace.collectDistribution(address(0), 1e18);
    }

    function testCollectDistributionInvalidAmount() public {
        vm.expectRevert(Error.FeeMarketplace__InvalidAmount.selector);
        feeMarketplace.collectDistribution(users.alice, 0);
    }

    function testCollectDistributionInsufficientBalance() public {
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientDistributionBalance.selector, 1e18, 0));
        feeMarketplace.collectDistribution(users.alice, 1e18);
    }

    function testZeroDepositReverts() public {
        // With the new deposit signature, zero amounts should be handled gracefully
        // The transfer layer silently returns on zero amounts
        feeMarketplace.deposit(usdc, users.owner, 0);

        // Verify no tokens were actually deposited
        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 0, "No tokens should be deposited for zero amount");
    }
}
