// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Error} from "src/utils/Error.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";

contract FeeMarketplaceTest is BasicSetup {
    TestStore testFundingStore;

    FeeMarketplaceStore feeMarketplaceStore;
    FeeMarketplace feeMarketplace;

    // Additional fee token used for multi-token tests.
    DummyToken dummyToken;

    function setUp() public override {
        super.setUp();

        testFundingStore = new TestStore(dictator, tokenRouter);
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                distributionTimeframe: 1 days,
                burnBasisPoints: 10000, // 100% burn
                feeDistributor: BankStore(address(0))
            })
        );

        // Set up permissions.
        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(testFundingStore, address(feeMarketplaceStore));

        // Initialize with a 1-day distribution timeframe, 100% burn, no distributor.
        dictator.initContract(feeMarketplace);

        dictator.setAccess(testFundingStore, address(users.owner));
        testFundingStore.syncTokenBalance(usdc);
        testFundingStore.syncTokenBalance(wnt);

        // Participants approval
        vm.startPrank(users.alice);
        puppetToken.approve(address(tokenRouter), type(uint).max);
        vm.startPrank(users.bob);
        puppetToken.approve(address(tokenRouter), type(uint).max);

        vm.startPrank(users.owner);

        // Prepare token balances.
        puppetToken.transfer(users.alice, 100e18);
        puppetToken.transfer(users.bob, 100e18);
        usdc.mint(address(testFundingStore), 1000e6);
        testFundingStore.syncTokenBalance(usdc);
        wnt.mint(address(testFundingStore), 1000e18);
        testFundingStore.syncTokenBalance(wnt);
        // Deploy a dummy token for multi-token tests and mint tokens.
        dummyToken = new DummyToken();
        dummyToken.mint(address(testFundingStore), 1000e18);
        testFundingStore.syncTokenBalance(dummyToken);

        // Approvals for router & FeeMarketplace.
        dummyToken.approve(address(tokenRouter), type(uint).max);
        wnt.approve(address(tokenRouter), type(uint).max);
        usdc.approve(address(tokenRouter), type(uint).max);
    }

    //----------------------------------------------------------------------------
    // Full Lifecycle & Basic Functionality Tests
    //----------------------------------------------------------------------------

    function testFullLifecycle() public {
        // Phase 1: Setup ask prices.
        feeMarketplace.setAskPrice(usdc, 10e18); // 10 protocol tokens per USDC.
        feeMarketplace.setAskPrice(wnt, 5e18); // 5 protocol tokens per WNT.
        usdc.mint(users.owner, 800e6);
        wnt.mint(users.owner, 80e18);

        // Capture initial puppet token supply.
        uint initialSupply = puppetToken.totalSupply();

        // Phase 2: Deposits (USDC and WNT).
        feeMarketplace.deposit(usdc, testFundingStore, 500e6);
        feeMarketplace.deposit(wnt, testFundingStore, 50e18);

        // Phase 3: Unlock fees after 1 day.
        skip(1 days);

        // Phase 4: Alice buys two batches of USDC fees.
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 250e6); // Burns 10e18.
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 250e6); // Burns another 10e18.

        // Phase 5: Second deposit and partial unlock.
        feeMarketplace.deposit(usdc, testFundingStore, 300e6);
        skip(12 hours); // Roughly 50% available (150e6 unlocked).

        // Phase 6: Bob completes purchases.
        puppetToken.approve(address(tokenRouter), 15e18);
        feeMarketplace.acceptOffer(usdc, users.bob, users.bob, 150e6); // Burns 10e18.
        feeMarketplace.acceptOffer(wnt, users.bob, users.bob, 25e18); // Burns 5e18.

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
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);

        assertEq(usdc.balanceOf(address(feeMarketplaceStore)), 100e6, "BankStore balance mismatch after deposit");
        assertEq(
            feeMarketplace.lastDistributionTimestamp(usdc),
            block.timestamp,
            "lastUpdateTimestamp should equal current block time"
        );
        assertEq(feeMarketplace.accruedFee(usdc), 0, "Accrued fees should be zero immediately after deposit");
    }

    function testBuyAndBurnSuccess() public {
        uint initialSupply = puppetToken.totalSupply();

        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);

        // Approve USDC for a single acceptOffer call by Alice.
        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);

        // Verify fee token transfer and supply burn.
        assertEq(usdc.balanceOf(users.alice), 50e6, "Alice should receive 50e6 USDC");
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Protocol token supply decreased by burn amount");
        assertEq(feeMarketplace.accruedFee(usdc), 50e6, "Remaining unlocked fee for USDC must be updated");
    }

    function testPartialUnlock2() public {
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        skip(6 hours); // 25% unlock over half a day.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 25e6, "Expected 25e6 pending unlock after 6 hours");
    }

    function testZeroBuybackQuote() public {
        // Deposit 100e6 USDC into the fee marketplace.
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);

        // Set the ask price for USDC to 0, making it non-auctionable.
        feeMarketplace.setAskPrice(usdc, 0);

        // Skip 1 day to allow any potential unlocks.
        skip(1 days);

        // Expect a revert with the NotAuctionableToken error when trying to accept an offer
        // for puppet tokens with a zero ask price.
        vm.expectRevert(Error.FeeMarketplace__NotAuctionableToken.selector);
        feeMarketplace.acceptOffer(puppetToken, users.alice, users.alice, 50e6);
    }

    function testUnauthorizedAccess() public {
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Error.Permission__Unauthorized.selector));
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
    }

    function testMultipleDeposits() public {
        // First deposit of 100e6 at time 0.
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        skip(12 hours); // First deposit accrues 50e6 (half unlocked).

        // Second deposit occurs at t = 12 hours.
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
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
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);

        // Update config: increase distribution timeframe to 2 days.
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 2 days,
            burnBasisPoints: 10000,
            feeDistributor: BankStore(address(0))
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        skip(1 days); // Now only about 50% (50e6) should have unlocked.
        uint pending = feeMarketplace.getPendingUnlock(usdc);
        assertEq(pending, 50e6, "Updated config not resulting in correct unlock");
    }

    function testBurnAddressReceipt() public {
        uint initialSupply = puppetToken.totalSupply();
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);

        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);
        // In 100% burn config, supply should decrease fully.
        assertEq(puppetToken.totalSupply(), initialSupply - 10e18, "Burn amount must equal ask price in full-burn mode");
    }

    function testExactTimeUnlock() public {
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        // Skip 1 day plus a few seconds.
        skip(1 days + 1 seconds);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 100e6, "After 1 day +, entire deposit should be unlocked");
    }

    function testSmallAmountPrecision() public {
        feeMarketplace.deposit(usdc, testFundingStore, 1); // Deposit 1 wei USDC.
        skip(12 hours);
        // Expect rounding down yields 0 pending unlock.
        assertEq(feeMarketplace.getPendingUnlock(usdc), 0, "Small deposit should not unlock fractions");
        skip(12 hours);
        assertEq(feeMarketplace.getPendingUnlock(usdc), 1, "Fraction should round up after full time");
    }

    function testMaxPurchase() public {
        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint maxAmount = feeMarketplace.getTotalUnlocked(usdc);

        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, maxAmount);
        assertEq(usdc.balanceOf(users.alice), maxAmount, "Alice should receive full unlocked balance");
        assertEq(feeMarketplace.accruedFee(usdc), 0, "No unlocked balance should remain");
    }

    function testPartialBurnWithRewards() public {
        BankStore feeDistributorStore = new TestStore(dictator, tokenRouter);
        // Change config: 50% burn, remaining to distributor.
        FeeMarketplace.Config memory newConfig = FeeMarketplace.Config({
            distributionTimeframe: 1 days,
            burnBasisPoints: 5000, // 50% burn.
            feeDistributor: feeDistributorStore
        });
        dictator.setConfig(feeMarketplace, abi.encode(newConfig));
        dictator.setAccess(feeMarketplaceStore, address(feeDistributorStore));
        dictator.setAccess(feeDistributorStore, address(feeMarketplace));

        feeMarketplace.deposit(usdc, testFundingStore, 100e6);
        feeMarketplace.setAskPrice(usdc, 10e18);
        skip(1 days);
        uint initialSupply = puppetToken.totalSupply();
        uint initialDistributorBal = puppetToken.balanceOf(address(feeDistributorStore));

        feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 50e6);
        // Expect 50% of 10e18 burned, 50% transferred to distributor.
        assertEq(puppetToken.totalSupply(), initialSupply - 5e18, "Total burned amount should be 5e18");
        assertEq(
            puppetToken.balanceOf(address(feeDistributorStore)),
            initialDistributorBal + 5e18,
            "Reward distributor did not receive correct amount"
        );
    }

    // //----------------------------------------------------------------------------
    // // Additional / Edge Case Tests
    // //----------------------------------------------------------------------------

    // // Test: Zero deposit should revert.
    // function testZeroDepositReverts() public {
    //     vm.expectRevert(Error.FeeMarketplace__ZeroDeposit.selector);
    //     feeMarketplace.deposit(usdc, testFundingStore, 0);
    // }

    // // Test: No pending unlock immediately after deposit.
    // function testNoPendingUnlockImmediately() public {
    //     feeMarketplace.deposit(usdc, testFundingStore, 100e6);
    //     uint pending = feeMarketplace.getPendingUnlock(usdc);
    //     assertEq(pending, 0, "Pending unlock should be zero immediately after deposit");
    // }

    // // Test: Multiple fee tokens are tracked independently.
    // function testMultipleFeeTokens() public {
    //     feeMarketplace.setAskPrice(usdc, 10e18);
    //     feeMarketplace.setAskPrice(dummyToken, 20e18);

    //     feeMarketplace.deposit(usdc, testFundingStore, 200e6);
    //     feeMarketplace.deposit(dummyToken, testFundingStore, 100e18);
    //     skip(1 days);
    //     uint usdcUnlocked = feeMarketplace.getTotalUnlocked(usdc);
    //     uint dummyUnlocked = feeMarketplace.getTotalUnlocked(dummyToken);
    //     assertEq(usdcUnlocked, 200e6, "USDC should be fully unlocked");
    //     assertEq(dummyUnlocked, 100e18, "Dummy token should be fully unlocked");
    // }

    // // Test: Repeated acceptOffer calls update state correctly.
    // function testRepeatedAcceptOfferUpdatesUnlocked() public {
    //     feeMarketplace.deposit(usdc, testFundingStore, 100e6);
    //     feeMarketplace.setAskPrice(usdc, 10e18);
    //     skip(1 days);
    //     uint initiallyUnlocked = feeMarketplace.getTotalUnlocked(usdc);
    //     assertEq(initiallyUnlocked, 100e6, "Expected full unlock before purchases");

    //     feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 60e6);
    //     assertEq(feeMarketplace.accruedFee(usdc), 40e6, "Remaining unlocked fee should be reduced to 40e6");
    //     feeMarketplace.acceptOffer(usdc, users.alice, users.alice, 40e6);
    //     assertEq(feeMarketplace.accruedFee(usdc), 0, "After full redemption, no unlocked fee should remain");
    // }
}

contract TestStore is BankStore {
    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}
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
