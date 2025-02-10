// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Error} from "src/shared/Error.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {FeeMarketplaceStore} from "src/tokenomics/store/FeeMarketplaceStore.sol";

contract FeeMarketplaceTest is BasicSetup {
    FeeMarketplaceStore public feeMarketplaceStore;
    FeeMarketplace public feeMarketplace;

    // Additional fee token used for multi-token tests.
    DummyToken public dummyToken;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);

        // Set up permissions.
        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplace));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        // Initialize with a 1-day distribution timeframe, 100% burn, no distributor.
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

        // Prepare token balances.
        _dealERC20(address(puppetToken), users.alice, 100e18);
        _dealERC20(address(puppetToken), users.bob, 100e18);
        _dealERC20(address(usdc), users.owner, 1000e6);

        // Approvals for router & FeeMarketplace.
        wnt.approve(address(tokenRouter), type(uint).max);
        usdc.approve(address(tokenRouter), type(uint).max);
        usdc.approve(address(feeMarketplace), type(uint).max);

        // Deploy a dummy token for multi-token tests and mint tokens.
        dummyToken = new DummyToken();
        dummyToken.mint(users.owner, 1000e18);

        vm.stopPrank();
    }

    //----------------------------------------------------------------------------
    // Full Lifecycle & Basic Functionality Tests
    //----------------------------------------------------------------------------

    function testFullLifecycle() public {
        // Phase 1: Setup ask prices.
        vm.startPrank(users.owner);
        feeMarketplace.setAskPrice(usdc, 10e18); // 10 protocol tokens per USDC.
        feeMarketplace.setAskPrice(wnt, 5e18); // 5 protocol tokens per WNT.
        _dealERC20(address(usdc), users.owner, 800e6);
        _dealERC20(address(wnt), users.owner, 80e18);
        vm.stopPrank();

        // Capture initial puppet token supply.
        uint initialSupply = puppetToken.totalSupply();

        // Phase 2: Deposits (USDC and WNT).
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 500e6);
        vm.prank(users.owner);
        feeMarketplace.deposit(wnt, users.owner, 50e18);

        // Phase 3: Unlock fees after 1 day.
        skip(1 days);

        // Phase 4: Alice buys two batches of USDC fees.
        vm.startPrank(users.alice);
        // Ensure sufficient protocol token allowance.
        puppetToken.approve(address(tokenRouter), 20e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 250e6); // Burns 10e18.
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 250e6); // Burns another 10e18.
        vm.stopPrank();

        // Phase 5: Second deposit and partial unlock.
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 300e6);
        skip(12 hours); // Roughly 50% available (150e6 unlocked).

        // Phase 6: Bob completes purchases.
        vm.startPrank(users.bob);
        puppetToken.approve(address(tokenRouter), 15e18);
        feeMarketplace.acceptOffer(usdc, users.bob, users.bob, 150e6); // Burns 10e18.
        feeMarketplace.acceptOffer(wnt, users.bob, users.bob, 25e18); // Burns 5e18.
        vm.stopPrank();

        // Final verifications.
        assertEq(usdc.balanceOf(users.alice), 500e6, "Alice should receive 500e6 USDC");
        assertEq(usdc.balanceOf(users.bob), 150e6, "Bob should receive 150e6 USDC");
        assertEq(wnt.balanceOf(users.bob), 25e18, "Bob should receive 25e18 WNT");

        uint totalBurned = 35e18; // 10 + 10 + 10 + 5.
        assertEq(initialSupply - puppetToken.totalSupply(), totalBurned, "Total supply must decrease by burned amount");

        // Check accrued fees for each token.
        assertEq(feeMarketplace.accruedFee(usdc), 0, "USDC accrued fees must be 0");
        assertEq(feeMarketplace.accruedFee(wnt), 25e18, "WNT accrued fees mismatch");
    }

    function testDepositUpdatesState() public {
        vm.prank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "BankStore balance mismatch after deposit");
        assertEq(
            feeMarketplace.lastDistributionTimestamp(usdc),
            block.timestamp,
            "lastUpdateTimestamp should equal current block time"
        );
        assertEq(feeMarketplace.accruedFee(usdc), 0, "No fees should be unlocked immediately at deposit");
    }

    function testBuyAndBurnSuccess() public {
        uint initialSupply = puppetToken.totalSupply();

        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        vm.stopPrank();

        vm.startPrank(users.alice);
        // Approve for one acceptOffer call.
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);

        // Verify fee token transfer and supply burn.
        assertEq(usdc.balanceOf(users.alice), 50e6, "Alice should receive 50e6 USDC");
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Protocol token supply decreased by burn amount");
        assertEq(feeMarketplace.accruedFee(usdc), 50e6, "Remaining unlocked fee for USDC must be updated");
        vm.stopPrank();
    }

    function testPartialUnlock() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        skip(6 hours); // 25% unlock over half a day.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 25e6, "Expected 25e6 pending unlock after 6 hours");
        vm.stopPrank();
    }

    function testInsufficientUnlocked() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days / 2); // Only half the deposit unlocked (50e6 available).
        vm.stopPrank();

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        vm.expectRevert(abi.encodeWithSelector(Error.FeeMarketplace__InsufficientUnlockedBalance.selector, 50e6));
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 100e6);
        vm.stopPrank();
    }

    function testZeroBuybackQuote() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 0);
        skip(1 days);
        vm.stopPrank();

        vm.startPrank(users.alice);
        vm.expectRevert(Error.FeeMarketplace__NotAuctionableToken.selector);
        feeMarketplace.acceptOffer(puppetToken, users.alice, users.alice, 50e6);
        vm.stopPrank();
    }

    function testUnauthorizedAccess() public {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Error.Permission__Unauthorized.selector, users.alice));
        feeMarketplace.deposit(usdc, users.owner, 100e6);
    }

    function testMultipleDeposits() public {
        vm.startPrank(users.owner);
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
        vm.stopPrank();
    }

    function testConfigUpdate() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);

        // Update config: increase distribution timeframe to 2 days.
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 2 days,
            burnBasisPoints: 10000,
            rewardDistributor: address(0)
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        skip(1 days); // Now only about 50% (50e6) should have unlocked.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Updated config not resulting in correct unlock");
        vm.stopPrank();
    }

    function testBurnAddressReceipt() public {
        uint initialSupply = puppetToken.totalSupply();
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        vm.stopPrank();

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);
        // In 100% burn config, supply should decrease fully.
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Burn amount must equal ask price in full-burn mode");
        vm.stopPrank();
    }

    function testExactTimeUnlock() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        // Skip 1 day plus a few seconds.
        skip(1 days + 1 seconds);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6, "After 1 day +, entire deposit should be unlocked");
        vm.stopPrank();
    }

    function testSmallAmountPrecision() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 1); // Deposit 1 wei USDC.
        skip(12 hours);
        // Expect rounding down yields 0 pending unlock.
        assertEq(feeMarketplace.getPendingUnlock(usdc), 0, "Small deposit should not unlock fractions");
        skip(12 hours);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 1, "Fraction should round up after full time");
        vm.stopPrank();
    }

    function testMaxPurchase() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint maxAmount = feeMarketplace.getTotalUnlocked(usdc);
        vm.stopPrank();

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, maxAmount);
        assertEq(usdc.balanceOf(users.alice), maxAmount, "Alice should receive full unlocked balance");
        assertEq(feeMarketplace.accruedFee(usdc), 0, "No unlocked balance should remain");
        vm.stopPrank();
    }

    function testPartialBurnWithRewards() public {
        vm.startPrank(users.owner);
        // Change config: 50% burn, remaining to distributor.
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 1 days,
            burnBasisPoints: 5000, // 50% burn.
            rewardDistributor: address(0x1234)
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));

        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint initialSupply = puppetToken.totalSupply();
        uint initialDistributorBal = puppetToken.balanceOf(address(0x1234));
        vm.stopPrank();

        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), 10e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);
        // Expect 50% of 10e18 burned, 50% transferred to distributor.
        assertEq(puppetToken.totalSupply(), initialSupply - 5e18, "Total burned amount should be 5e18");
        assertEq(
            puppetToken.balanceOf(address(0x1234)),
            initialDistributorBal + 5e18,
            "Reward distributor did not receive correct amount"
        );
        vm.stopPrank();
    }

    //----------------------------------------------------------------------------
    // Additional / Edge Case Tests
    //----------------------------------------------------------------------------

    // Test: Zero deposit should revert.
    function testZeroDepositReverts() public {
        vm.startPrank(users.owner);
        vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
        feeMarketplace.deposit(usdc, users.owner, 0);
        vm.stopPrank();
    }

    // Test: No pending unlock immediately after deposit.
    function testNoPendingUnlockImmediately() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 0, "Pending unlock should be zero immediately after deposit");
        vm.stopPrank();
    }

    // Test: Multiple fee tokens are tracked independently.
    function testMultipleFeeTokens() public {
        vm.startPrank(users.owner);
        feeMarketplace.setAskPrice(usdc, 10e18);
        feeMarketplace.setAskPrice(dummyToken, 20e18);

        feeMarketplace.deposit(usdc, users.owner, 200e6);
        dummyToken.approve(address(tokenRouter), type(uint).max);
        feeMarketplace.deposit(dummyToken, users.owner, 100e18);
        skip(1 days);
        uint usdcUnlocked = feeMarketplace.getTotalUnlocked(usdc);
        uint dummyUnlocked = feeMarketplace.getTotalUnlocked(dummyToken);
        assertEq(usdcUnlocked, 200e6, "USDC should be fully unlocked");
        assertEq(dummyUnlocked, 100e18, "Dummy token should be fully unlocked");
        vm.stopPrank();
    }

    // Test: Repeated acceptOffer calls update state correctly.
    function testRepeatedAcceptOfferUpdatesUnlocked() public {
        vm.startPrank(users.owner);
        feeMarketplace.deposit(usdc, users.owner, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint initiallyUnlocked = feeMarketplace.getTotalUnlocked(usdc);
        assertEq(initiallyUnlocked, 100e6, "Expected full unlock before purchases");
        vm.stopPrank();

        vm.startPrank(users.alice);
        // Provide enough approval for two calls.
        puppetToken.approve(address(tokenRouter), 20e18);
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 60e6);
        assertEq(feeMarketplace.accruedFee(usdc), 40e6, "Remaining unlocked fee should be reduced to 40e6");
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 40e6);
        assertEq(feeMarketplace.accruedFee(usdc), 0, "After full redemption, no unlocked fee should remain");
        vm.stopPrank();
    }
}

//-----------------------------------------------------------------------------
// DummyToken used for multi-fee token tests.
//-----------------------------------------------------------------------------

contract DummyToken is IERC20 {
    string public constant name = "DummyToken";
    string public constant symbol = "DUM";
    uint8 public constant decimals = 18;
    uint private _totalSupply;
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;

    function totalSupply() external view override returns (uint) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) external view override returns (uint) {
        return _balances[account];
    }

    function transfer(address recipient, uint amount) external override returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) external override returns (bool) {
        require(_balances[sender] >= amount, "Insufficient balance");
        require(_allowances[sender][msg.sender] >= amount, "Allowance too low");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;
        return true;
    }

    // Mint function for tests.
    function mint(address recipient, uint amount) public {
        _totalSupply += amount;
        _balances[recipient] += amount;
    }
}
