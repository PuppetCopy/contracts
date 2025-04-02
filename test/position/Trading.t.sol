// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol"; // Import Vm for expectRevert etc.

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {AllocationAccountUtils} from "src/position/utils/AllocationAccountUtils.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol"; // Added for OrderType
import {PositionUtils} from "src/position/utils/PositionUtils.sol";

import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Error} from "src/shared/Error.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/tokenomics/FeeMarketplaceStore.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";
import {Address} from "script/Const.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

contract TradingTest is BasicSetup {
    AllocationStore internal allocationStore;
    MatchRule internal matchRule;
    FeeMarketplace internal feeMarketplace;
    MirrorPosition internal mirrorPosition;
    MockGmxExchangeRouter internal mockGmxExchangeRouter;
    FeeMarketplaceStore internal feeMarketplaceStore;

    uint internal constant LEVERAGE_TOLERANCE_BP = 5; // Use slightly larger tolerance for e30 math

    MirrorPosition.CallPosition defaultCallPosition = MirrorPosition.CallPosition({
        collateralToken: usdc,
        trader: users.bob,
        market: Address.gmxEthUsdcMarket,
        isIncrease: true,
        isLong: true, // Match original direction
        executionFee: 5_000_000 * 1 gwei,
        collateralDelta: 100e6, // Close full trader collateral
        sizeDeltaInUsd: 1000e30, // 1000 USD (10x leverage implied)
        acceptablePrice: 0,
        triggerPrice: 0,
        mirrorExecutionFee: 0 // Mirror execution fee (not used in this test)
    });

    // Removed CallAllocation struct - not used anymore1

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        allocationStore = new AllocationStore(dictator, tokenRouter);
        // Pass the predicted MirrorPosition address to MatchRule constructor
        matchRule = new MatchRule(dictator, allocationStore, MirrorPosition(_getNextContractAddress(3)));
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);
        mirrorPosition = new MirrorPosition(dictator, allocationStore, matchRule, feeMarketplace);

        // Config
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = wnt;
        tokenAllowanceCapList[1] = usdc;
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        // Configure contracts
        dictator.initContract(
            matchRule,
            abi.encode(
                MatchRule.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100, // 1 basis points = 1%
                    maxAllowanceRate: 10000, // 100%
                    minActivityThrottle: 1 hours,
                    maxActivityThrottle: 30 days,
                    tokenAllowanceList: tokenAllowanceCapList,
                    tokenAllowanceAmountList: tokenAllowanceCapAmountList
                })
            )
        );

        dictator.initContract(
            feeMarketplace,
            abi.encode(
                FeeMarketplace.Config({
                    distributionTimeframe: 1 days,
                    burnBasisPoints: 10000,
                    feeDistributor: BankStore(address(0))
                })
            )
        );

        dictator.initContract(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: mockGmxExchangeRouter,
                    callbackHandler: address(mirrorPosition), // Self-callback for tests
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 20,
                    minExecutionCostRate: 1000 // 1000 basis points = 10%
                })
            )
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        // mirrorPosition permissions (owner for most actions in tests)
        // dictator.setPermission(mirrorPosition, mirrorPosition.allocate.selector, users.owner); // REMOVED
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.adjust.selector, users.owner); // Added adjust permission
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, users.owner);
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.initializeTraderActivityThrottle.selector,
            address(matchRule) // MatchRule initializes throttle
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        feeMarketplace.setAskPrice(usdc, 100e18);

        dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);

        // Pre-approve token allowances
        vm.startPrank(users.alice); // Example user for createPuppet
        usdc.approve(address(tokenRouter), type(uint).max);
        wnt.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();

        vm.startPrank(users.bob);
        usdc.approve(address(tokenRouter), type(uint).max);
        wnt.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();

        vm.startPrank(users.owner); // Ensure owner is pranked by default
    }

    function testSettlementMultipleTokens() public {
        // 1. Setup
        address trader = defaultCallPosition.trader;
        MockERC20 allocationCollateral = usdc;
        MockERC20 secondaryToken = wnt;
        uint feeFactor = _getPlatformSettleFeeFactor();

        uint puppet1InitialBalance = 100e6;
        uint puppet2InitialBalance = 200e6;
        address puppet1 = _createPuppet(allocationCollateral, trader, "multiTokenPuppet1", puppet1InitialBalance);
        address puppet2 = _createPuppet(allocationCollateral, trader, "multiTokenPuppet2", puppet2InitialBalance);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // 2. Initial Mirror (combines allocation and opening)
        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        // allocationId: 0 // Ignored by mirror()

        // Call mirror for initial opening
        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(openKey, bytes32(0), "Open key should not be zero");
        assertNotEq(allocationId, 0, "Allocation ID should not be zero");

        bytes32 matchKey = PositionUtils.getMatchKey(allocationCollateral, trader);
        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Verify allocation happened within mirror()
        uint puppet1Allocation = _allocationPuppetMap(allocationKey, puppet1); // Expected 10e6
        uint puppet2Allocation = _allocationPuppetMap(allocationKey, puppet2); // Expected 20e6
        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // Expected 30e6
        uint netAllocated = totalAllocation - callOpen.mirrorExecutionFee; // Collateral actually transferred
        assertEq(totalAllocation, 30e6, "Total allocation mismatch");
        assertEq(totalAllocation, puppet1Allocation + puppet2Allocation, "Sum check mismatch");
        // Check if net collateral was transferred out
        // Note: This check assumes transfer happens to GMX Order Vault directly in mirror()
        // Check balance of AllocationStore OR GMX Order Vault depending on exact implementation detail
        // assertEq(allocationCollateral.balanceOf(Address.gmxOrderVault), netAllocated); // Check vault balance
        // increased

        // 3. Execute Open
        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        assertGt(currentPos.size, 0, "Position size should be greater than 0 after opening");

        // 4. Adjust Position (Full Close) using adjust()
        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.isIncrease = false;

        bytes32 closeKey = mirrorPosition.adjust{value: callClose.executionFee}(callClose, puppetList, allocationId);
        mirrorPosition.execute(closeKey); // Position closed in MirrorPosition state
        MirrorPosition.Position memory closedPos = mirrorPosition.getPosition(allocationKey);
        assertEq(closedPos.size, 0, "Position size should be 0 after closing");

        // 5. Simulate Receiving Multiple Tokens in AllocationAccount
        uint usdcProfit = totalAllocation / 2; // 15e6 USDC profit (50%)
        uint usdcSettledAmount = netAllocated + usdcProfit; // Return of NET collateral + profit = (30e6 - fee) + 15e6
        uint wethSettledAmount = 0.1e18; // Simulate 0.1 WETH received

        // Adjust the deal to account for execution fee already deducted
        deal(address(allocationCollateral), allocationAddress, usdcSettledAmount);
        deal(address(secondaryToken), allocationAddress, wethSettledAmount);

        assertEq(allocationCollateral.balanceOf(allocationAddress), usdcSettledAmount, "Deal USDC failed");
        assertEq(secondaryToken.balanceOf(allocationAddress), wethSettledAmount, "Deal WETH failed");

        // 6. Record Balances Before Settlement
        uint p1USDC_Before = allocationStore.userBalanceMap(allocationCollateral, puppet1);
        uint p2USDC_Before = allocationStore.userBalanceMap(allocationCollateral, puppet2);
        uint p1WETH_Before = allocationStore.userBalanceMap(secondaryToken, puppet1);
        uint p2WETH_Before = allocationStore.userBalanceMap(secondaryToken, puppet2);
        uint feeStoreUSDC_Before = allocationCollateral.balanceOf(address(feeMarketplaceStore));
        uint feeStoreWETH_Before = secondaryToken.balanceOf(address(feeMarketplaceStore));

        // 7. Settle USDC
        MirrorPosition.CallSettle memory settleUSDC = MirrorPosition.CallSettle({
            allocationToken: allocationCollateral, // Token used for original allocation ratios
            distributeToken: allocationCollateral, // Token being distributed now
            trader: trader,
            allocationId: allocationId // settle() needs allocationId
        });
        mirrorPosition.settle(settleUSDC, puppetList);

        // 8. Verify USDC Settlement
        assertEq(allocationCollateral.balanceOf(allocationAddress), 0, "USDC not cleared from AllocAccount");
        uint usdcPlatformFee = Precision.applyFactor(feeFactor, usdcSettledAmount); // Fee on settled amount
        uint usdcAmountDistributed = usdcSettledAmount - usdcPlatformFee;
        uint p1ExpectedUSDCShare = Math.mulDiv(usdcAmountDistributed, puppet1Allocation, totalAllocation); // Use TOTAL
            // allocation for ratio
        uint p2ExpectedUSDCShare = Math.mulDiv(usdcAmountDistributed, puppet2Allocation, totalAllocation);

        uint p1USDC_After = allocationStore.userBalanceMap(allocationCollateral, puppet1);
        uint p2USDC_After = allocationStore.userBalanceMap(allocationCollateral, puppet2);
        uint feeStoreUSDC_After = allocationCollateral.balanceOf(address(feeMarketplaceStore));

        assertEq(p1USDC_After - p1USDC_Before, p1ExpectedUSDCShare, "Puppet1 USDC share mismatch");
        assertEq(p2USDC_After - p2USDC_Before, p2ExpectedUSDCShare, "Puppet2 USDC share mismatch");
        assertEq(feeStoreUSDC_After - feeStoreUSDC_Before, usdcPlatformFee, "FeeStore USDC mismatch");

        // 9. Settle WETH
        MirrorPosition.CallSettle memory settleWETH = MirrorPosition.CallSettle({
            allocationToken: allocationCollateral, // STILL use the original allocation token basis
            distributeToken: secondaryToken, // Distributing WETH now
            trader: trader,
            allocationId: allocationId // settle() needs allocationId
        });
        mirrorPosition.settle(settleWETH, puppetList);

        // 10. Verify WETH Settlement
        assertEq(secondaryToken.balanceOf(allocationAddress), 0, "WETH not cleared from AllocAccount");
        uint wethPlatformFee = Precision.applyFactor(feeFactor, wethSettledAmount);
        uint wethAmountDistributed = wethSettledAmount - wethPlatformFee;

        // Use the *original allocation ratio* (based on USDC contribution) to distribute WETH
        uint p1ExpectedWETHShare = Math.mulDiv(wethAmountDistributed, puppet1Allocation, totalAllocation);
        uint p2ExpectedWETHShare = Math.mulDiv(wethAmountDistributed, puppet2Allocation, totalAllocation);

        uint p1WETH_After = allocationStore.userBalanceMap(secondaryToken, puppet1);
        uint p2WETH_After = allocationStore.userBalanceMap(secondaryToken, puppet2);
        uint feeStoreWETH_After = secondaryToken.balanceOf(address(feeMarketplaceStore));

        assertEq(p1WETH_After - p1WETH_Before, p1ExpectedWETHShare, "Puppet1 WETH share mismatch");
        assertEq(p2WETH_After - p2WETH_Before, p2ExpectedWETHShare, "Puppet2 WETH share mismatch");
        assertEq(feeStoreWETH_After - feeStoreWETH_Before, wethPlatformFee, "FeeStore WETH mismatch");
    }

    function testSimpleExecutionResult() public {
        uint initialPuppetBalance = 100e6;
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 10);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationStoreBalanceBefore = usdc.balanceOf(address(allocationStore));

        // 1. Initial Mirror (combines allocation & opening)
        MirrorPosition.CallPosition memory callIncrease = defaultCallPosition;

        (uint allocationId, bytes32 increaseRequestKey) =
            mirrorPosition.mirror{value: callIncrease.executionFee}(callIncrease, puppetList);
        assertNotEq(increaseRequestKey, bytes32(0));
        assertNotEq(allocationId, 0);

        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint totalAllocated = mirrorPosition.getAllocation(allocationKey);
        uint netAllocated = totalAllocated - callIncrease.mirrorExecutionFee;
        // Expect 10 puppets * 100e6 balance * 10% rule = 100e6
        assertEq(totalAllocated, 100e6, "Total allocation should be 100e6");

        // Check balance change in AllocationStore OR GMX Vault after mirror()
        // Mirror transfers NET allocated amount to vault
        // assertEq(usdc.balanceOf(Address.gmxOrderVault), netAllocated, "Vault balance after mirror mismatch");
        // Alternatively check AllocationStore balance decreased
        uint allocationStoreBalanceAfterMirror = allocationStoreBalanceBefore - totalAllocated; // Store balance reduces
            // by TOTAL allocated
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            allocationStoreBalanceAfterMirror,
            "AllocStore balance after mirror"
        );

        // 2. Execute Increase
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);

        // Calculate expected initial size based on the new logic in mirror()
        uint expectedInitialMirroredSize = _calculateExpectedInitialMirrorSize(
            callIncrease.sizeDeltaInUsd, callIncrease.collateralDelta, totalAllocated, callIncrease.mirrorExecutionFee
        );
        // Expected: 1000e30 * (100e6 - fee) / 100e6 ~= 1000e30 (if fee is small relative to allocation)
        // Let's use the helper: 1000e30 * (100e6 - 0.005e6) / 100e6 = 999.95e30
        assertEq(
            expectedInitialMirroredSize,
            Math.mulDiv(defaultCallPosition.sizeDeltaInUsd, netAllocated, defaultCallPosition.collateralDelta),
            "Calculated initial mirrored size mismatch"
        );

        assertEq(pos1.traderSize, defaultCallPosition.sizeDeltaInUsd, "pos1.traderSize");
        assertEq(pos1.traderCollateral, defaultCallPosition.collateralDelta, "pos1.traderCollateral");
        assertEq(pos1.size, expectedInitialMirroredSize, "pos1.size mismatch"); // Mirrored size based on new calc

        // 3. Adjust Decrease (Full Close) using adjust()
        MirrorPosition.CallPosition memory callDecrease = defaultCallPosition;
        callDecrease.collateralDelta = pos1.traderCollateral; // Decrease by current trader collateral
        callDecrease.sizeDeltaInUsd = pos1.traderSize; // Decrease by current trader size
        callDecrease.isIncrease = false; // Decrease position

        // allocationId: allocationId // NEEDED for adjust
        // Use adjust() for the close
        bytes32 decreaseRequestKey =
            mirrorPosition.adjust{value: callDecrease.executionFee}(callDecrease, puppetList, allocationId);
        assertNotEq(decreaseRequestKey, bytes32(0));

        // 4. Simulate Profit & Execute Decrease
        uint profit = netAllocated; // 100% profit on NET allocated capital
        uint settledAmount = netAllocated + profit; // Return = netAllocated + profit
        // uint platformFee = Precision.applyFactor(getPlatformSettleFeeFactor(), settledAmount); // Fee calculated on
        // settled amount
        deal(address(usdc), allocationAddress, settledAmount); // Deal funds to allocation account
        mirrorPosition.execute(decreaseRequestKey); // Simulate GMX callback executing the close

        // Check position is closed
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos2.traderSize, 0, "pos2.traderSize should be 0");
        assertEq(pos2.traderCollateral, 0, "pos2.traderCollateral should be 0");
        assertEq(pos2.size, 0, "pos2.size should be 0");

        // 5. Settle
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original allocation basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId // NEEDED for settle
        });
        mirrorPosition.settle(callSettle, puppetList);

        uint platformFee = Precision.applyFactor(_getPlatformSettleFeeFactor(), settledAmount); // Fee calculated on
            // settled amount
        assertEq(platformFee, Precision.applyFactor(_getPlatformSettleFeeFactor(), netAllocated + profit));

        // Check store balance increased by (settled amount - fee), relative to balance *after mirror*
        // The starting point for comparison is allocationStoreBalanceAfterMirror
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            allocationStoreBalanceAfterMirror + settledAmount - platformFee,
            "Allocation store final balance mismatch"
        );

        // 6. Check puppet balances
        uint amountDistributed = settledAmount - platformFee;
        uint totalContributionsCheck = 0;
        for (uint i = 0; i < puppetList.length; i++) {
            totalContributionsCheck += _allocationPuppetMap(allocationKey, puppetList[i]);
        }
        assertEq(totalContributionsCheck, totalAllocated, "Sanity check total contributions"); // Compare with TOTAL
            // allocated

        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            uint contribution = _allocationPuppetMap(allocationKey, puppet); // Should be 10e6 each
            assertEq(
                contribution, 10e6, string(abi.encodePacked("Puppet ", Strings.toString(i), " contribution mismatch"))
            );

            // Calculate expected share based on TOTAL allocation ratio: amountDistributed * contribution /
            // totalAllocation
            uint expectedShare = Math.mulDiv(amountDistributed, contribution, totalAllocated); // Use TOTAL allocation
                // for ratio

            // Balance check: Initial Balance - Contribution + Share = Final Balance
            // Balance *after mirror* was (Initial - Contribution). So Final = (Balance After Mirror) + Share
            uint balanceAfterMirror = initialPuppetBalance - contribution; // 100e6 - 10e6 = 90e6
            uint expectedFinalBalance = balanceAfterMirror + expectedShare;

            assertEq(
                allocationStore.userBalanceMap(usdc, puppet),
                expectedFinalBalance,
                string(abi.encodePacked("Puppet ", Strings.toString(i), " final balance mismatch"))
            );
        }
    }

    function testExecutionRequestMissingError() public {
        bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));
        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);
    }

    // Changed test: Test calling ADJUST with a non-existent allocationId
    function testAdjustNonExistentPositionError() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);
        uint nonExistentAllocationId = 99999; // An ID for which mirror was not called

        // Try to call adjust() with the non-existent ID
        MirrorPosition.CallPosition memory callAdjust = defaultCallPosition;
        // allocationId: nonExistentAllocationId // Use the non-existent ID

        // adjust() first checks if position.size > 0 for the derived allocationKey
        bytes32 nonExistentMatchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 nonExistentAllocationKey = _getAllocationKey(puppetList, nonExistentMatchKey, nonExistentAllocationId);
        MirrorPosition.Position memory nonExistentPos = mirrorPosition.getPosition(nonExistentAllocationKey);
        assertEq(nonExistentPos.size, 0); // Pre-condition: Position should not exist

        vm.expectRevert(Error.MirrorPosition__PositionNotFound.selector);
        mirrorPosition.adjust{value: callAdjust.executionFee}(callAdjust, puppetList, nonExistentAllocationId);
    }

    function testNoSettledFundsError() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 10);

        // Initial Mirror (combines allocation and opening)
        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        // allocationId: 0 // Ignored

        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror(callOpen, puppetList);
        assertNotEq(allocationId, 0);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Check account is empty before settlement (mirror transfers out, nothing comes back yet)
        assertEq(usdc.balanceOf(allocationAddress), 0, "Allocation account should be empty before settlement");

        // Try to settle without any funds being dealt/returned to allocationAddress
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc,
            distributeToken: usdc,
            trader: trader,
            allocationId: allocationId // NEEDED for settle
        });
        vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
        mirrorPosition.settle(callSettle, puppetList);
    }

    function testSizeAdjustmentsMatchMirrorPositionLogic() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // 1. Initial Mirror
        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        // allocationId: 0 // Ignored

        (uint allocationId, bytes32 openRequestKey) =
            mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(openRequestKey, bytes32(0));
        assertNotEq(allocationId, 0);

        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        uint totalAllocated = mirrorPosition.getAllocation(allocationKey); // Should be 2 * 100e6 * 10% = 20e6
        uint netAllocated = totalAllocated - callOpen.mirrorExecutionFee;
        assertEq(totalAllocated, 20e6, "Initial total allocation should be 20e6");

        // Check stored adjustment data for the *initial* mirror call
        MirrorPosition.RequestAdjustment memory req1 = mirrorPosition.getRequestAdjustment(openRequestKey);
        uint expectedInitialMirrorSizeDelta = _calculateExpectedInitialMirrorSize(
            callOpen.sizeDeltaInUsd, callOpen.collateralDelta, totalAllocated, callOpen.mirrorExecutionFee
        );
        // Expected: 1000e30 * (20e6 - fee) / 100e6 ~= 200e30
        assertEq(
            expectedInitialMirrorSizeDelta,
            Math.mulDiv(callOpen.sizeDeltaInUsd, netAllocated, callOpen.collateralDelta),
            "Calculated initial mirror size delta mismatch"
        );

        assertEq(req1.allocationKey, allocationKey, "Stored allocationKey mismatch req1");
        assertEq(req1.sizeDelta, expectedInitialMirrorSizeDelta, "Stored sizeDelta for initial open mismatch");
        assertEq(req1.traderCollateralDelta, callOpen.collateralDelta);
        assertEq(req1.traderSizeDelta, callOpen.sizeDeltaInUsd);
        assertEq(req1.traderIsIncrease, true); // Initial must be increase
        assertEq(req1.targetLeverage, Precision.toBasisPoints(callOpen.sizeDeltaInUsd, callOpen.collateralDelta));

        // 2. Execute Open
        mirrorPosition.execute(openRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos1.traderSize, defaultCallPosition.sizeDeltaInUsd, "Pos1 TSize");
        assertEq(pos1.traderCollateral, defaultCallPosition.collateralDelta, "Pos1 TCollat");
        assertEq(pos1.size, expectedInitialMirrorSizeDelta, "Pos1 MSize"); // Check actual mirrored size
        assertApproxEqAbs(
            Precision.toBasisPoints(pos1.size, netAllocated), // Mirror leverage (using netAllocated as base)
            Precision.toBasisPoints(pos1.traderSize, pos1.traderCollateral), // Trader leverage
            LEVERAGE_TOLERANCE_BP,
            "Pos1 Leverage mismatch"
        );

        // 3. Adjust Partial Decrease (50% Trader Size, 0 Trader Collat) -> Trader Lev 10x -> 5x
        MirrorPosition.CallPosition memory partialDecreaseParams = defaultCallPosition;
        partialDecreaseParams.collateralDelta = 0; // No change in trader collateral
        partialDecreaseParams.sizeDeltaInUsd = pos1.traderSize / 2; // Decrease trader size by 50% (500e30)
        partialDecreaseParams.isIncrease = false; // Decrease position

        // allocationId: allocationId // NEEDED for adjust

        uint expectedTraderSize2 = pos1.traderSize - partialDecreaseParams.sizeDeltaInUsd; // 500e30
        uint expectedTraderCollat2 = pos1.traderCollateral; // 100e6
        // Calculate expected mirror delta using ADJUSTMENT helper
        (uint expectedMirrorDelta2, bool deltaIsIncrease2) =
            _calculateExpectedMirrorAdjustmentDelta(pos1, expectedTraderSize2, expectedTraderCollat2);
        assertEq(deltaIsIncrease2, false, "PartialDec: Delta direction should be false");
        // Expected: Trader Lev 10x -> 5x. Mirror Delta = currentMirrorSize * (10x - 5x) / 10x = pos1.size * 0.5
        assertEq(expectedMirrorDelta2, pos1.size / 2, "PartialDec: Expected Delta mismatch");

        // Use adjust()
        bytes32 partialDecreaseKey = mirrorPosition.adjust{value: partialDecreaseParams.executionFee}(
            partialDecreaseParams, puppetList, allocationId
        );
        assertNotEq(partialDecreaseKey, bytes32(0));
        // Check stored adjustment data
        MirrorPosition.RequestAdjustment memory req2 = mirrorPosition.getRequestAdjustment(partialDecreaseKey);
        assertEq(req2.allocationKey, allocationKey, "Stored allocationKey mismatch req2");
        assertEq(req2.sizeDelta, expectedMirrorDelta2, "Stored sizeDelta for partial decrease mismatch");
        assertEq(req2.traderCollateralDelta, partialDecreaseParams.collateralDelta);
        assertEq(req2.traderSizeDelta, partialDecreaseParams.sizeDeltaInUsd);
        assertEq(req2.traderIsIncrease, false);
        assertEq(req2.targetLeverage, Precision.toBasisPoints(expectedTraderSize2, expectedTraderCollat2));

        // 4. Execute Partial Decrease
        mirrorPosition.execute(partialDecreaseKey);
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos2.traderSize, expectedTraderSize2, "Pos2 TSize");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "Pos2 TCollat");
        assertEq(pos2.size, pos1.size - expectedMirrorDelta2, "Pos2 MSize"); // Apply the delta
        assertApproxEqAbs(
            Precision.toBasisPoints(pos2.size, netAllocated), // Mirror leverage
            Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral), // Trader leverage
            LEVERAGE_TOLERANCE_BP,
            "Pos2 Leverage mismatch"
        );

        // 5. Adjust Partial Increase (Back to original trader size) -> Trader Lev 5x -> 10x
        MirrorPosition.CallPosition memory partialIncreaseParams = defaultCallPosition;
        partialIncreaseParams.collateralDelta = 0; // No change in trader collateral
        partialIncreaseParams.sizeDeltaInUsd = pos1.traderSize / 2; // Increase trader size by 500e30

        // allocationId: allocationId // NEEDED for adjust

        uint expectedTraderSize3 = pos2.traderSize + partialIncreaseParams.sizeDeltaInUsd; // 1000e30
        uint expectedTraderCollat3 = pos2.traderCollateral; // 100e6
        // Calculate expected mirror delta using ADJUSTMENT helper
        (uint expectedMirrorDelta3, bool deltaIsIncrease3) =
            _calculateExpectedMirrorAdjustmentDelta(pos2, expectedTraderSize3, expectedTraderCollat3);
        assertEq(deltaIsIncrease3, true, "PartialInc: Delta direction should be true");
        // Expected: Trader Lev 5x -> 10x. Mirror Delta = currentMirrorSize * (10x - 5x) / 5x = pos2.size * 1 =
        // pos2.size
        assertEq(expectedMirrorDelta3, pos2.size, "PartialInc: Expected Delta mismatch");

        // Use adjust()
        bytes32 partialIncreaseKey = mirrorPosition.adjust{value: partialIncreaseParams.executionFee}(
            partialIncreaseParams, puppetList, allocationId
        );
        assertNotEq(partialIncreaseKey, bytes32(0));
        MirrorPosition.RequestAdjustment memory req3 = mirrorPosition.getRequestAdjustment(partialIncreaseKey);
        assertEq(req3.allocationKey, allocationKey, "Stored allocationKey mismatch req3");
        assertEq(req3.sizeDelta, expectedMirrorDelta3, "Stored sizeDelta for partial increase mismatch");
        assertEq(req3.traderCollateralDelta, partialIncreaseParams.collateralDelta);
        assertEq(req3.traderSizeDelta, partialIncreaseParams.sizeDeltaInUsd);
        assertEq(req3.traderIsIncrease, true);
        assertEq(req3.targetLeverage, Precision.toBasisPoints(expectedTraderSize3, expectedTraderCollat3));

        // 6. Execute Partial Increase
        mirrorPosition.execute(partialIncreaseKey);
        MirrorPosition.Position memory pos3 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos3.traderSize, expectedTraderSize3, "Pos3 TSize");
        assertEq(pos3.traderCollateral, expectedTraderCollat3, "Pos3 TCollat");
        assertEq(pos3.size, pos2.size + expectedMirrorDelta3, "Pos3 MSize"); // Apply delta
        assertApproxEqAbs(
            Precision.toBasisPoints(pos3.size, netAllocated), // Mirror leverage
            Precision.toBasisPoints(pos3.traderSize, pos3.traderCollateral), // Trader leverage
            LEVERAGE_TOLERANCE_BP,
            "Pos3 Leverage mismatch"
        );
        // Check we are back to original mirrored size
        assertEq(pos3.size, expectedInitialMirrorSizeDelta, "Pos3 MSize should equal original mirrored size");

        // 7. Adjust Full Close
        MirrorPosition.CallPosition memory fullDecreaseParams = defaultCallPosition;
        fullDecreaseParams.collateralDelta = pos3.traderCollateral; // Close full trader collateral
        fullDecreaseParams.sizeDeltaInUsd = pos3.traderSize; // Close full trader size
        fullDecreaseParams.isIncrease = false; // Decrease position

        // allocationId: allocationId // NEEDED for adjust
        // Calculate expected mirror delta for full close (target trader size/collat = 0) using ADJUSTMENT helper
        (uint expectedMirrorDelta4, bool deltaIsIncrease4) = _calculateExpectedMirrorAdjustmentDelta(pos3, 0, 0);
        assertEq(deltaIsIncrease4, false, "FullClose: Delta direction should be false");
        // Expected: Close full current mirrored size
        assertEq(expectedMirrorDelta4, pos3.size, "FullClose: Expected Delta should be full current size");

        // Use adjust()
        bytes32 fullDecreaseKey =
            mirrorPosition.adjust{value: fullDecreaseParams.executionFee}(fullDecreaseParams, puppetList, allocationId);
        assertNotEq(fullDecreaseKey, bytes32(0));
        MirrorPosition.RequestAdjustment memory req4 = mirrorPosition.getRequestAdjustment(fullDecreaseKey);
        assertEq(req4.allocationKey, allocationKey, "Stored allocationKey mismatch req4");
        assertEq(req4.sizeDelta, expectedMirrorDelta4, "Stored sizeDelta for full close mismatch");
        assertEq(req4.traderCollateralDelta, fullDecreaseParams.collateralDelta);
        assertEq(req4.traderSizeDelta, fullDecreaseParams.sizeDeltaInUsd);
        assertEq(req4.traderIsIncrease, false);
        assertEq(req4.targetLeverage, 0); // Target leverage is 0 for full close

        // 8. Execute Full Close
        mirrorPosition.execute(fullDecreaseKey);
        MirrorPosition.Position memory pos4 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos4.traderSize, 0, "Pos4 TSize");
        assertEq(pos4.traderCollateral, 0, "Pos4 TCollat");
        assertEq(pos4.size, 0, "Pos4 MSize"); // pos3.size - expectedMirrorDelta4 should be 0
    }

    // Changed test: Test calling mirror() with too many puppets
    function testMirrorExceedingMaximumPuppets() public {
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList; // Should be 20
        address trader = defaultCallPosition.trader;
        // Create one more puppet address than allowed
        address[] memory tooManyPuppets = new address[](limitAllocationListLength + 1);
        for (uint i = 0; i < tooManyPuppets.length; i++) {
            tooManyPuppets[i] = address(uint160(uint(keccak256(abi.encodePacked("dummyPuppet", i)))));
        }

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        // allocationId: 0 // Ignored

        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, tooManyPuppets);
    }

    // Adjusted profit/loss tests to use mirror/adjust flow
    function testPositionSettlementWithProfit() public {
        address trader = defaultCallPosition.trader;
        uint feeFactor = _getPlatformSettleFeeFactor();

        address puppet1 = _createPuppet(usdc, trader, "profitPuppet1", 100e6);
        address puppet2 = _createPuppet(usdc, trader, "profitPuppet2", 200e6);
        address puppet3 = _createPuppet(usdc, trader, "profitPuppet3", 300e6);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // Store balances *before* mirror call deducts contributions
        uint puppet1BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet1); // 100e6
        uint puppet2BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet2); // 200e6
        uint puppet3BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet3); // 300e6

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(allocationId, 0);

        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // Use contract's total (60e6)
        uint netAllocated = totalAllocation - callOpen.mirrorExecutionFee;
        uint puppet1Allocation = _allocationPuppetMap(allocationKey, puppet1); // 10e6
        uint puppet2Allocation = _allocationPuppetMap(allocationKey, puppet2); // 20e6
        uint puppet3Allocation = _allocationPuppetMap(allocationKey, puppet3); // 30e6
        assertEq(totalAllocation, 60e6, "Initial allocation total should be 60e6");
        assertEq(puppet1Allocation + puppet2Allocation + puppet3Allocation, totalAllocation, "Sum check mismatch");

        // Check balances *after* mirror call (contributions deducted)
        uint puppet1BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet1); // 100e6 - 10e6 = 90e6
        uint puppet2BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet2); // 200e6 - 20e6 = 180e6
        uint puppet3BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet3); // 300e6 - 30e6 = 270e6
        assertEq(
            puppet1BalanceBeforeMirror - puppet1BalanceAfterMirror, puppet1Allocation, "P1 contribution deduct failed"
        );
        assertEq(
            puppet2BalanceBeforeMirror - puppet2BalanceAfterMirror, puppet2Allocation, "P2 contribution deduct failed"
        );
        assertEq(
            puppet3BalanceBeforeMirror - puppet3BalanceAfterMirror, puppet3Allocation, "P3 contribution deduct failed"
        );

        // Execute Open
        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);

        // Adjust Close using adjust()
        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.collateralDelta = currentPos.traderCollateral; // Decrease by current trader collateral
        callClose.sizeDeltaInUsd = currentPos.traderSize; // Decrease by current trader size
        callClose.isIncrease = false; // Decrease

        // allocationId: allocationId // NEEDED for adjust

        bytes32 closeKey = mirrorPosition.adjust{value: callClose.executionFee}(callClose, puppetList, allocationId);

        // Simulate Profit: return NET allocated + 100% profit on NET allocated
        uint profitAmount = netAllocated;
        uint settledAmount = netAllocated + profitAmount;
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey); // Execute the close order simulation

        // Settle funds
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId // NEEDED for settle
        });
        mirrorPosition.settle(callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        uint platformFee = Precision.applyFactor(feeFactor, settledAmount); // Fee on settled amount
        uint amountAfterFee = settledAmount - platformFee;

        // Calculate expected share additions based on ORIGINAL contributions ratio applied to amountAfterFee
        uint puppet1ExpectedShare = Math.mulDiv(amountAfterFee, puppet1Allocation, totalAllocation); // Use TOTAL
            // allocation for ratio
        uint puppet2ExpectedShare = Math.mulDiv(amountAfterFee, puppet2Allocation, totalAllocation);
        uint puppet3ExpectedShare = Math.mulDiv(amountAfterFee, puppet3Allocation, totalAllocation);

        // Assert the balance INCREASE (from afterMirror state) matches the expected share
        assertEq(puppet1BalanceAfterSettle - puppet1BalanceAfterMirror, puppet1ExpectedShare, "Puppet1 share mismatch");
        assertEq(puppet2BalanceAfterSettle - puppet2BalanceAfterMirror, puppet2ExpectedShare, "Puppet2 share mismatch");
        assertEq(puppet3BalanceAfterSettle - puppet3BalanceAfterMirror, puppet3ExpectedShare, "Puppet3 share mismatch");

        // Also check final absolute balance
        assertEq(puppet1BalanceAfterSettle, puppet1BalanceBeforeMirror - puppet1Allocation + puppet1ExpectedShare);
        assertEq(puppet2BalanceAfterSettle, puppet2BalanceBeforeMirror - puppet2Allocation + puppet2ExpectedShare);
        assertEq(puppet3BalanceAfterSettle, puppet3BalanceBeforeMirror - puppet3Allocation + puppet3ExpectedShare);
    }

    function testPositionSettlementWithLoss() public {
        address trader = defaultCallPosition.trader;
        uint feeFactor = _getPlatformSettleFeeFactor();

        address puppet1 = _createPuppet(usdc, trader, "lossPuppet1", 100e6);
        address puppet2 = _createPuppet(usdc, trader, "lossPuppet2", 100e6);
        address puppet3 = _createPuppet(usdc, trader, "lossPuppet3", 100e6);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // Record balances before contributions are deducted
        uint puppet1BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet1); // 100e6
        uint puppet2BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet2); // 100e6
        uint puppet3BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet3); // 100e6

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(allocationId, 0);

        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // 30e6
        uint netAllocated = totalAllocation - callOpen.mirrorExecutionFee;
        uint puppet1Allocation = _allocationPuppetMap(allocationKey, puppet1); // 10e6
        uint puppet2Allocation = _allocationPuppetMap(allocationKey, puppet2); // 10e6
        uint puppet3Allocation = _allocationPuppetMap(allocationKey, puppet3); // 10e6
        assertEq(totalAllocation, 30e6);
        assertEq(puppet1Allocation + puppet2Allocation + puppet3Allocation, totalAllocation);

        // Record balances after contributions deducted
        uint puppet1BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet1); // 90e6
        uint puppet2BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet2); // 90e6
        uint puppet3BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet3); // 90e6

        // Execute Open
        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);

        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.collateralDelta = currentPos.traderCollateral; // Decrease by current trader collateral
        callClose.sizeDeltaInUsd = currentPos.traderSize; // Decrease by current trader size
        callClose.isIncrease = false; // Decrease

        // allocationId: allocationId // NEEDED for adjust

        bytes32 closeKey = mirrorPosition.adjust{value: callClose.executionFee}(callClose, puppetList, allocationId);

        // Simulate 20% loss on NET allocated capital - return 80% of netAllocated
        uint settledAmount = Math.mulDiv(netAllocated, 80, 100);
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey);

        // Settle funds
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId // NEEDED for settle
        });
        mirrorPosition.settle(callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        // Fee is on the settled amount (even if it's a loss)
        uint platformFee = Precision.applyFactor(feeFactor, settledAmount);
        uint amountAfterFee = settledAmount > platformFee ? settledAmount - platformFee : 0;

        // Calculate expected return additions based on ORIGINAL contributions ratio applied to amountAfterFee
        // Expected return = amountAfterFee * contribution / totalAllocation
        uint puppet1ExpectedReturn = Math.mulDiv(amountAfterFee, puppet1Allocation, totalAllocation); // Use TOTAL
            // allocation ratio
        uint puppet2ExpectedReturn = Math.mulDiv(amountAfterFee, puppet2Allocation, totalAllocation);
        uint puppet3ExpectedReturn = Math.mulDiv(amountAfterFee, puppet3Allocation, totalAllocation);

        // Assert the balance INCREASE (from afterMirror state) matches the expected return
        assertEq(
            puppet1BalanceAfterSettle - puppet1BalanceAfterMirror, puppet1ExpectedReturn, "Puppet1 loss return mismatch"
        );
        assertEq(
            puppet2BalanceAfterSettle - puppet2BalanceAfterMirror, puppet2ExpectedReturn, "Puppet2 loss return mismatch"
        );
        assertEq(
            puppet3BalanceAfterSettle - puppet3BalanceAfterMirror, puppet3ExpectedReturn, "Puppet3 loss return mismatch"
        );

        // Also check final absolute balance
        assertEq(puppet1BalanceAfterSettle, puppet1BalanceBeforeMirror - puppet1Allocation + puppet1ExpectedReturn);
        assertEq(puppet2BalanceAfterSettle, puppet2BalanceBeforeMirror - puppet2Allocation + puppet2ExpectedReturn);
        assertEq(puppet3BalanceAfterSettle, puppet3BalanceBeforeMirror - puppet3Allocation + puppet3ExpectedReturn);
    }

    // Test adjust() with zero collateral change
    function testZeroCollateralAdjustments() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2); // Use default trader
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        // allocationId: 0 // Ignored

        (uint allocationId, bytes32 openRequestKey) =
            mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        mirrorPosition.execute(openRequestKey);
        MirrorPosition.Position memory pos1 =
            mirrorPosition.getPosition(_getAllocationKey(puppetList, matchKey, allocationId));
        uint totalAllocated = mirrorPosition.getAllocation(_getAllocationKey(puppetList, matchKey, allocationId));
        uint netAllocated = totalAllocated - callOpen.mirrorExecutionFee;
        // Expected mirror size = calculateExpectedInitialMirrorSize(...) = 1000e30 * (20e6-fee)/100e6
        assertGt(pos1.size, 0, "Pos1 initial size should be > 0");

        // Adjust: Increase trader size without changing trader collateral -> Trader Leverage increases (10x -> 15x)
        MirrorPosition.CallPosition memory zeroCollateralIncreaseParams = defaultCallPosition;
        zeroCollateralIncreaseParams.collateralDelta = 0; // No change in trader collateral
        zeroCollateralIncreaseParams.sizeDeltaInUsd = 500e30; // Increase trader size by 50% (500e30)

        // allocationId: allocationId // NEEDED for adjust

        uint expectedTraderSize2 = pos1.traderSize + zeroCollateralIncreaseParams.sizeDeltaInUsd; // 1500e30
        uint expectedTraderCollat2 = pos1.traderCollateral; // 100e6 (remains same)
        // Calculate expected mirror delta using ADJUSTMENT helper
        (uint expectedMirrorDelta2, bool deltaIsIncrease2) =
            _calculateExpectedMirrorAdjustmentDelta(pos1, expectedTraderSize2, expectedTraderCollat2);
        assertEq(deltaIsIncrease2, true, "ZeroCollat: Delta direction should be true");
        // Expected: Trader Lev 10x -> 15x. Mirror Delta = currentMirrorSize * (15x - 10x) / 10x = pos1.size * 0.5
        assertEq(expectedMirrorDelta2, pos1.size / 2, "ZeroCollat: Expected Delta mismatch");

        // Use adjust()
        bytes32 zeroCollateralRequestKey = mirrorPosition.adjust{value: zeroCollateralIncreaseParams.executionFee}(
            zeroCollateralIncreaseParams, puppetList, allocationId
        );
        mirrorPosition.execute(zeroCollateralRequestKey);
        MirrorPosition.Position memory pos2 =
            mirrorPosition.getPosition(_getAllocationKey(puppetList, matchKey, allocationId));

        assertEq(pos2.traderSize, expectedTraderSize2, "ZeroCollat: TSize mismatch");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "ZeroCollat: TCollat mismatch");
        assertEq(pos2.size, pos1.size + expectedMirrorDelta2, "ZeroCollat: MSize mismatch"); // pos1.size * 1.5

        assertApproxEqAbs(
            Precision.toBasisPoints(pos2.size, netAllocated), // Mirror leverage (use netAllocated)
            Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral), // Trader leverage
            LEVERAGE_TOLERANCE_BP,
            "ZeroCollat: Leverage mismatch"
        );
    }

    function testAccessControlForCriticalFunctions() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 1);

        MirrorPosition.CallPosition memory callMirror = defaultCallPosition;

        vm.expectRevert(); // Expect revert due to lack of permission
        vm.prank(users.bob); // Non-owner user
        mirrorPosition.mirror{value: callMirror.executionFee}(callMirror, puppetList);
        vm.stopPrank(); // Reset prank state

        // --- Owner performs initial mirror to get keys for subsequent tests ---
        vm.prank(users.owner);
        (uint allocationId, bytes32 requestKey) =
            mirrorPosition.mirror{value: callMirror.executionFee}(callMirror, puppetList);
        bytes32 allocationKey = _getAllocationKey(puppetList, PositionUtils.getMatchKey(usdc, trader), allocationId);
        vm.stopPrank(); // Reset prank state

        MirrorPosition.CallPosition memory callAdjust = defaultCallPosition;
        callAdjust.collateralDelta = 10e6;
        callAdjust.sizeDeltaInUsd = 100e30;
        callAdjust.isIncrease = false; // Decrease

        // allocationId: allocationId // Needs ID

        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.adjust{value: callAdjust.executionFee}(callAdjust, puppetList, allocationId);
        vm.stopPrank(); // Reset prank state

        // --- Test execute ---
        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.execute(requestKey); // Try execute the owner's request
        vm.stopPrank(); // Reset prank state

        // --- Test settle ---
        // Owner executes open, adjusts to close, executes close, deals funds
        vm.prank(users.owner);
        mirrorPosition.execute(requestKey); // Execute the open request
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);

        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.collateralDelta = currentPos.traderCollateral; // Decrease by current trader collateral
        callClose.sizeDeltaInUsd = currentPos.traderSize; // Decrease by current trader size
        callClose.isIncrease = false; // Decrease

        bytes32 closeKey = mirrorPosition.adjust{value: callClose.executionFee}(callClose, puppetList, allocationId);
        mirrorPosition.execute(closeKey); // Execute close
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        deal(address(usdc), allocationAddress, 10e6); // Deal some funds to settle
        vm.stopPrank(); // Reset prank state

        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc,
            distributeToken: usdc,
            trader: trader,
            allocationId: allocationId
        });
        // Non-owner tries to settle
        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.settle(callSettle, puppetList);
        vm.stopPrank(); // Reset prank state

        // --- Test initializeTraderActivityThrottle (only MatchRule should call) ---
        vm.expectRevert();
        vm.prank(users.owner); // Owner shouldn't call directly
        mirrorPosition.initializeTraderActivityThrottle(trader, puppetList[0]);
        vm.stopPrank(); // Reset prank state

        vm.expectRevert();
        vm.prank(users.bob); // Other users shouldn't call
        mirrorPosition.initializeTraderActivityThrottle(trader, puppetList[0]);
        vm.stopPrank(); // Reset prank state
    }

    // --- Helper functions ---

    // calculateExpectedMirrorSizeDelta: Adjusted for clarity on initial vs adjust
    // For initial call (current size == 0), calculation is now inside mirror().
    // For adjustments (current size > 0), calculation is inside adjust().
    // This helper now primarily reflects the *adjustment* logic.
    function _calculateExpectedMirrorAdjustmentDelta(
        MirrorPosition.Position memory _currentPosition, // Current state from getPosition
        uint _newTraderSize, // Target trader size after adjustment
        uint _newTraderCollateral // Target trader collateral after adjustment
            // _initialMirroredCollateral is no longer needed here as it's fixed post-initial mirror
    ) internal pure returns (uint sizeDelta, bool isIncrease) {
        require(_currentPosition.size > 0, "Adjustment requires existing position");

        uint _currentLeverage = _currentPosition.traderCollateral > 0
            ? Precision.toBasisPoints(_currentPosition.traderSize, _currentPosition.traderCollateral)
            : 0;
        uint _targetLeverage =
            _newTraderCollateral > 0 ? Precision.toBasisPoints(_newTraderSize, _newTraderCollateral) : 0;

        if (_targetLeverage == _currentLeverage) {
            return (0, true); // No change in leverage, no size adjustment needed
        } else if (_targetLeverage > _currentLeverage) {
            // Leverage Increase
            require(_currentLeverage > 0, "Cannot increase leverage from zero"); // Avoid division by zero
            // Delta = currentMirrorSize * (targetLev - currentLev) / currentLev
            sizeDelta = Math.mulDiv(_currentPosition.size, (_targetLeverage - _currentLeverage), _currentLeverage);
            isIncrease = true;
            return (sizeDelta, isIncrease);
        } else {
            // Leverage Decrease or Full Close (_targetLeverage < _currentLeverage)
            if (_currentLeverage == 0) {
                // Should not happen if position size > 0 but trader collat = 0? Handle defensively.
                return (_currentPosition.size, false); // Close full size if current leverage is somehow zero
            }
            // Delta = currentMirrorSize * (currentLev - targetLev) / currentLev
            sizeDelta = Math.mulDiv(_currentPosition.size, (_currentLeverage - _targetLeverage), _currentLeverage);
            if (sizeDelta > _currentPosition.size) {
                sizeDelta = _currentPosition.size; // Cap decrease at current mirrored size
            }
            isIncrease = false;
            return (sizeDelta, isIncrease);
        }
    }

    // Helper specifically for the initial mirror size calculation now done in mirror()
    function _calculateExpectedInitialMirrorSize(
        uint _traderSizeDeltaUsd,
        uint _traderCollateralDelta,
        uint _totalAllocated,
        uint _executionFee
    ) internal pure returns (uint initialSize) {
        require(_traderCollateralDelta > 0, "Initial trader collat > 0");
        require(_traderSizeDeltaUsd > 0, "Initial trader size > 0");
        uint _netAllocated = _totalAllocated - _executionFee;
        require(_netAllocated > 0, "Net allocation must be positive");

        // sizeDelta = traderSizeDeltaUsd * netAllocated / traderCollateralDelta;
        return Math.mulDiv(_traderSizeDeltaUsd, _netAllocated, _traderCollateralDelta);
    }

    function _createPuppet(
        MockERC20 collateralToken,
        address trader,
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        // _dealERC20(collateralToken, user, fundValue);
        collateralToken.mint(user, fundValue);

        vm.startPrank(user);
        collateralToken.approve(address(tokenRouter), type(uint).max);

        vm.startPrank(users.owner);
        matchRule.deposit(collateralToken, user, fundValue);

        // Owner sets rule for puppet-trader relationship
        matchRule.setRule(
            collateralToken,
            user, // puppet address
            trader,
            MatchRule.Rule({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 2 days})
        );

        return user;
    }

    function _setPerformanceFee(
        uint newFeeFactor_e30
    ) internal {
        // Make sure pranked as owner or dictator
        MirrorPosition.Config memory currentConfig = mirrorPosition.getConfig();
        currentConfig.platformSettleFeeFactor = newFeeFactor_e30;
        dictator.setConfig(mirrorPosition, abi.encode(currentConfig)); // Use address(mirrorPosition)
        assertEq(mirrorPosition.getConfig().platformSettleFeeFactor, newFeeFactor_e30, "Fee factor not set");
    }

    function _getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint _allocationId
    ) internal pure returns (bytes32) {
        // Matches PositionUtils.getAllocationKey
        return keccak256(abi.encodePacked(_puppetList, _matchKey, _allocationId));
    }

    function _getPlatformSettleFeeFactor() internal view returns (uint) {
        return mirrorPosition.getConfig().platformSettleFeeFactor;
    }

    function _generatePuppetList(
        MockERC20 collateralToken,
        address trader,
        uint _length
    ) internal returns (address[] memory) {
        require(_length > 0, "Length must be > 0");
        address[] memory puppetList = new address[](_length);
        for (uint i = 0; i < _length; i++) {
            string memory puppetNameLabel = string(abi.encodePacked("puppetOwner:", Strings.toString(i + 1)));
            puppetList[i] = _createPuppet(collateralToken, trader, puppetNameLabel, 100e6); // Default 100e6
        }

        return puppetList;
    }

    function _allocationPuppetMap(bytes32 allocationKey, address puppetOwner) internal view returns (uint) {
        return mirrorPosition.allocationPuppetMap(allocationKey, puppetOwner);
    }
}
