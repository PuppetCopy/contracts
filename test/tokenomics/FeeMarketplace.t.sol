// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Error} from "src/shared/Error.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {FeeMarketplaceStore} from "src/tokenomics/store/FeeMarketplaceStore.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";

contract FeeMarketplaceTest is BasicSetup {
    FeeMarketplaceStore public feeMarketplaceStore;
    FeeMarketplace public feeMarketplace;
    IERC20 public protocolToken;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);

        // Set up permissions
        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskAmount.selector, users.owner);
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplace));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        // Initialize with 1 day distribution timeframe, 100% burn, and no distributor
        dictator.initContract(
            feeMarketplace,
            abi.encode(
                FeeMarketplace.Config({
                    distributionTimeframe: 1 days,
                    burnBasisPoints: 10000, // 100% burn
                    rewardDistributor: address(0)
                })
            )
        );

        // Prepare token balances
        _dealERC20(address(puppetToken), users.alice, 100e18);
        _dealERC20(address(puppetToken), users.bob, 100e18);
        _dealERC20(address(usdc), users.owner, 1000e6);
        // Router approvals
        wnt.approve(address(tokenRouter), type(uint).max);
        usdc.approve(address(tokenRouter), type(uint).max);

        usdc.approve(address(feeMarketplace), type(uint).max);

        vm.stopPrank();
    }

    function testFullLifecycle() public {
        // Phase 1: Setup with 1-day timeframe
        vm.startPrank(users.owner);
        feeMarketplace.setAskAmount(usdc, 10e18); // 10 protocol tokens per USDC
        feeMarketplace.setAskAmount(wnt, 5e18); // 5 protocol tokens per WETH

        // Initial balances
        _dealERC20(address(usdc), users.owner, 800e6);
        _dealERC20(address(wnt), users.owner, 80e18);
        vm.stopPrank();

        // Capture initial supply before any burns
        uint initialSupply = puppetToken.totalSupply();

        // Phase 2: First deposit cycle
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 500e6);
        vm.prank(users.owner);
        feeMarketplace.deposit(wnt, users.owner, 50e18);

        // Phase 3: Full unlock after 1 day
        skip(1 days);

        // Alice buys USDC
        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 20e18);
        feeMarketplace.acceptOffer(usdc, users.alice, 250e6); // Burns 10e18
        feeMarketplace.acceptOffer(usdc, users.alice, 250e6); // Burns another 10e18
        vm.stopPrank();

        // Phase 4: Second deposit + partial unlock
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 300e6);
        skip(12 hours); // Unlocks 150e6 (300e6 * 0.5)

        // Phase 5: Final purchases
        vm.startPrank(users.bob);
        puppetToken.approve(address(tokenRouter), 15e18);
        feeMarketplace.acceptOffer(usdc, users.bob, 150e6); // Burns 10e18
        feeMarketplace.acceptOffer(wnt, users.bob, 25e18); // Burns 5e18
        vm.stopPrank();

        // Phase 6: Final verification
        // USDC Balances
        assertEq(usdc.balanceOf(users.alice), 500e6, "Alice USDC");
        assertEq(usdc.balanceOf(users.bob), 150e6, "Bob USDC");

        // WNT Balances
        assertEq(wnt.balanceOf(users.bob), 25e18, "Bob WETH");

        // Burn verification via supply decrease
        uint totalBurned = 35e18; // 10+10+10+5
        assertEq(
            initialSupply - puppetToken.totalSupply(), totalBurned, "Total supply should decrease by burned amount"
        );

        // Accured fees
        assertEq(feeMarketplace.accuredFeeBalance(usdc), 0, "USDC accrued");
        assertEq(feeMarketplace.accuredFeeBalance(wnt), 25e18, "WETH accrued");
    }

    // Test 1: Deposit updates state correctly
    function testDepositUpdatesState() public {
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "Balance mismatch");
        assertEq(feeMarketplace.lastUpdateTimestamp(usdc), block.timestamp, "Timestamp not updated");
        assertEq(feeMarketplace.accuredFeeBalance(usdc), 0, "Accured fee incorrect");
    }

    // Test 2: Successful buyAndBurn execution
    function testBuyAndBurnSuccess() public {
        uint initialSupply = puppetToken.totalSupply();

        // Setup
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 10e18); // 10 protocol tokens per burn
        skip(1 days); // Full unlock

        // Execute
        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, 50e6);

        // Verify
        assertEq(usdc.balanceOf(users.alice), 50e6, "Fee tokens not received");
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Supply not updated");
        assertEq(feeMarketplace.accuredFeeBalance(usdc), 50e6, "Accured not updated");
    }

    // Test 3: Partial fee unlocking
    function testPartialUnlock() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(6 hours); // 25% unlocked (1/4 of 1 day)

        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 25e6, "Incorrect partial unlock");
    }

    // Test 4: Insufficient unlocked balance
    function testInsufficientUnlocked() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 10e18);

        skip(1 days / 2);

        puppetToken.approve(address(tokenRouter), 10e18);
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientUnlockedBalance.selector, 50e6));
        feeMarketplace.acceptOffer(usdc, users.alice, 100e6);
    }

    // Test 5: Zero buyback quote rejection
    function testZeroBuybackQuote() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 0);
        skip(1 days);

        vm.expectRevert(Error.FeeMarketplace__NotAuctionableToken.selector);
        feeMarketplace.acceptOffer(puppetToken, users.alice, 50e6);
    }

    // Test 6: Authorization checks
    function testUnauthorizedAccess() public {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Error.Permission__Unauthorized.selector, users.alice));
        feeMarketplace.deposit(usdc, users.owner, 100e6);
    }

    // Test 7: Multiple deposits with drip
    function testMultipleDeposits() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(12 hours); // Unlocks 50e6

        feeMarketplace.deposit(usdc, users.owner, 100e6); // New deposit
        skip(12 hours); // 50% of new deposit (50e6) + remaining 50e6 from first

        uint pending = feeMarketplace.getTotalUnlocked(usdc);
        assertEq(pending, 100e6 + 25e6, "Multi-deposit drip mismatch");
    }

    // Test 8: Config update affects drip rate
    function testConfigUpdate() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Update to 2 day timeframe with valid parameters
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 2 days,
            burnBasisPoints: 10000, // Maintain 100% burn
            rewardDistributor: address(0)
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        skip(1 days); // Now only 50% unlocked

        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Config update not reflected");
    }

    function testBurnAddressReceipt() public {
        uint initialSupply = puppetToken.totalSupply();

        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 10e18);
        skip(1 days);

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, 50e6);

        assertEq(puppetToken.totalSupply(), initialSupply - 10e18);
    }

    function testExactTimeUnlock() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        skip(1 days + 1 seconds);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6);
    }

    function testSmallAmountPrecision() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 1); // 1 wei-sized USDC
        skip(12 hours);

        assertEq(feeMarketplace.getPendingUnlock(usdc), 0); // Should round down
        skip(12 hours);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 1);
    }

    function testMaxPurchase() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 10e18);
        skip(1 days);

        uint maxAmount = feeMarketplace.getTotalUnlocked(usdc);

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, maxAmount);

        assertEq(usdc.balanceOf(users.alice), maxAmount);
        assertEq(feeMarketplace.accuredFeeBalance(usdc), 0);
    }

    function testPartialBurnWithRewards() public {
        vm.startPrank(users.owner);
        // Set config with 50% burn and valid distributor
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 1 days,
            burnBasisPoints: 5000, // 50% burn
            rewardDistributor: address(0x1234) // Valid non-zero address
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskAmount(usdc, 10e18);
        skip(1 days);

        uint initialSupply = puppetToken.totalSupply();
        uint initialBalance = puppetToken.balanceOf(address(0x1234));

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, 50e6);

        // Verify 50% burned and 50% sent to distributor
        assertEq(puppetToken.totalSupply(), initialSupply - 5e18, "Incorrect burn");
        assertEq(puppetToken.balanceOf(address(0x1234)), initialBalance + 5e18, "Reward not sent");
    }
}
