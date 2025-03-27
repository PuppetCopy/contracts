// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol"; // Import Vm for cheatcodes like expectRevert

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
// import {IGmxOracle} from "src/position/interface/IGmxOracle.sol"; // Not used directly
import {AllocationAccountUtils} from "src/position/utils/AllocationAccountUtils.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AllocationAccount} from "src/shared/AllocationAccount.sol";

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
    AllocationStore allocationStore;
    MatchRule matchRule;
    FeeMarketplace feeMarketplace;
    MirrorPosition mirrorPosition;
    MockGmxExchangeRouter mockGmxExchangeRouter;
    FeeMarketplaceStore feeMarketplaceStore;

    // IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle); // Not used directly

    uint defaultEstimatedGasLimit = 5_000_000;
    uint defaultExecutionFee; // Set in setUp

    MirrorPosition.PositionParams defaultTraderPositionParams;

    // Tolerance for basis point comparisons (1 bp = 0.01%)
    uint constant LEVERAGE_TOLERANCE_BP = 1;

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        allocationStore = new AllocationStore(dictator, tokenRouter);
        // Use getNextContractAddress if necessary for deployment prediction
        address predictedMirrorPosAddr = _getNextContractAddress(3);
        matchRule = new MatchRule(dictator, allocationStore, MirrorPosition(predictedMirrorPosAddr));

        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);

        mirrorPosition = new MirrorPosition(dictator, allocationStore, matchRule, feeMarketplace);
        require(address(mirrorPosition) == predictedMirrorPosAddr, "Prediction mismatch"); // Verify address

        defaultExecutionFee = 1e15; // Set a fixed fee for predictability, adjust if needed

        defaultTraderPositionParams = MirrorPosition.PositionParams({
            collateralToken: usdc,
            trader: users.bob,
            market: Address.gmxEthUsdcMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: 120e6, // 120 USDC
            sizeDeltaInUsd: 30e30, // 30k USD size (for initial)
            acceptablePrice: 1000e12, // Example value
            triggerPrice: 0 // Market order
        });

        // Configure contracts
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = wnt;
        tokenAllowanceCapList[1] = usdc;
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        dictator.initContract(
            matchRule,
            abi.encode(
                MatchRule.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100, // 10 basis points
                    maxAllowanceRate: 10000,
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
                    callbackHandler: address(this), // Use test contract as callback for simplicity? Or dedicated mock
                        // callback. Using address(mirrorPosition) implies mirror calls itself? Let's use address(this)
                        // for test control. Revert if mirrorPosition calls itself.
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 100, // Reduce this to e.g., 20 for faster boundary tests?
                    maxExecutionCostFactor: 0.1e30
                })
            )
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        dictator.setPermission(mirrorPosition, mirrorPosition.allocate.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        // IMPORTANT: Who calls execute? The callbackHandler. Set permission for address(this) if testing via direct
        // call.
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, users.owner); // Keep owner for now,
            // assuming direct test call
        dictator.setPermission(mirrorPosition, mirrorPosition.configMaxCollateralTokenAllocation.selector, users.owner);
        dictator.setPermission(
            mirrorPosition, mirrorPosition.initializeTraderActivityThrottle.selector, address(matchRule)
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));

        feeMarketplace.setAskPrice(usdc, 100e18); // Example ask price
        mirrorPosition.configMaxCollateralTokenAllocation(usdc, 1000e6); // Example limit
        mirrorPosition.configMaxCollateralTokenAllocation(wnt, 100e18); // Example limit

        dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);

        // Pre-approve tokens (shortened for brevity, assume correct as before)
        // Iterate through users if more are needed
        address[] memory testUsers = new address[](2);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        // Could add owner, puppet addresses if they interact directly with stores requiring approval

        for (uint i = 0; i < testUsers.length; ++i) {
            vm.startPrank(testUsers[i]);
            usdc.approve(address(allocationStore), type(uint).max);
            wnt.approve(address(allocationStore), type(uint).max);
            usdc.approve(address(tokenRouter), type(uint).max); // May need approval for tokenRouter too
            wnt.approve(address(tokenRouter), type(uint).max);
            vm.stopPrank();
        }

        vm.startPrank(users.owner); // Most tests run as owner
    }

    // --- Tests ---

    function testSimpleExecutionResultWithPartialAdjustment() public {
        uint initialPuppetBalance = 100e6;
        uint puppetCount = 10;
        address[] memory puppetList = generatePuppetList(puppetCount);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);
        uint allocationStoreBalanceBefore = usdc.balanceOf(address(allocationStore));

        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.isIncrease = true;
        initialParams.collateralDelta = 120e6;
        initialParams.sizeDeltaInUsd = 30e30;

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        uint netAllocated = mirrorPosition.getAllocation(allocationKey);
        assertEq(netAllocated, 100e6, "Net allocation"); // 10 * 100e6 * 10%

        uint expectedInitialMirroredSize = (initialParams.sizeDeltaInUsd * netAllocated) / initialParams.collateralDelta; // 30e30*100/120=25e30

        bytes32 increaseRequestKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        uint allocationStoreBalanceAfterAllocate = allocationStoreBalanceBefore - netAllocated;
        assertEq(
            usdc.balanceOf(address(allocationStore)), allocationStoreBalanceAfterAllocate, "Store balance post-alloc"
        );

        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.Position memory positionAfterIncrease = mirrorPosition.getPosition(allocationKey);
        assertEq(positionAfterIncrease.traderSize, initialParams.sizeDeltaInUsd, "TSize post-inc");
        assertEq(positionAfterIncrease.traderCollateral, initialParams.collateralDelta, "TCollat post-inc");
        assertEq(positionAfterIncrease.size, expectedInitialMirroredSize, "MSize post-inc");
        assertEq(positionAfterIncrease.collateral, netAllocated, "MCollat post-inc");

        console.log("--- Submitting Partial Decrease ---");
        MirrorPosition.PositionParams memory partialDecreaseParams = initialParams; // Copy base, modify deltas
        partialDecreaseParams.isIncrease = false;
        partialDecreaseParams.collateralDelta = 0;
        partialDecreaseParams.sizeDeltaInUsd = positionAfterIncrease.traderSize / 2;
        //  Decrease 50% of current trader size

        bytes32 partialDecreaseKey = mirrorPosition.mirror{value: partialDecreaseParams.executionFee}(
            partialDecreaseParams, puppetList, allocationId
        );
        mirrorPosition.execute(partialDecreaseKey);

        MirrorPosition.Position memory positionAfterPartialDecrease = mirrorPosition.getPosition(allocationKey);
        uint expectedTraderSizeAfterPartial = positionAfterIncrease.traderSize - partialDecreaseParams.sizeDeltaInUsd;
        uint expectedTraderCollateralAfterPartial =
            positionAfterIncrease.traderCollateral - partialDecreaseParams.collateralDelta;
        uint expectedMirroredSizeAfterPartial;
        if (expectedTraderCollateralAfterPartial == 0) {
            expectedMirroredSizeAfterPartial = 0;
        } else {
            expectedMirroredSizeAfterPartial = (expectedTraderSizeAfterPartial * positionAfterIncrease.collateral)
                / expectedTraderCollateralAfterPartial;
        } // (15e30*100e6)/120e6 = 12.5e30

        assertEq(positionAfterPartialDecrease.traderSize, expectedTraderSizeAfterPartial, "TSize post-partial");
        assertEq(
            positionAfterPartialDecrease.traderCollateral, expectedTraderCollateralAfterPartial, "TCollat post-partial"
        );
        assertEq(positionAfterPartialDecrease.size, expectedMirroredSizeAfterPartial, "MSize post-partial");
        assertEq(positionAfterPartialDecrease.collateral, netAllocated, "MCollat post-partial");

        console.log("--- Submitting Final Decrease ---");
        MirrorPosition.PositionParams memory finalCloseParams = partialDecreaseParams; // Copy base, modify deltas
        finalCloseParams.isIncrease = false;
        finalCloseParams.collateralDelta = positionAfterPartialDecrease.traderCollateral;
        // Remaining trader collateral

        finalCloseParams.sizeDeltaInUsd = positionAfterPartialDecrease.traderSize; // Remaining trader size

        bytes32 finalDecreaseKey =
            mirrorPosition.mirror{value: finalCloseParams.executionFee}(finalCloseParams, puppetList, allocationId);

        uint profit = 100e6;
        uint settledAmount = netAllocated + profit;
        uint platformFee = Precision.applyFactor(mirrorPosition.getConfig().platformSettleFeeFactor, settledAmount);
        assertEq(platformFee, 20e6, "Fee mismatch"); // 10% of 200e6

        deal(address(usdc), allocationAddress, settledAmount);
        mirrorPosition.execute(finalDecreaseKey);

        MirrorPosition.Position memory positionAfterClose = mirrorPosition.getPosition(allocationKey);
        assertEq(positionAfterClose.size, 0, "Size post-close");
        assertEq(positionAfterClose.collateral, 0, "Collat post-close");
        assertEq(positionAfterClose.traderSize, 0, "TSize post-close");
        assertEq(positionAfterClose.traderCollateral, 0, "TCollat post-close");

        uint totalGrossAllocated = 0;
        uint[] memory puppetContributions = new uint[](puppetList.length);
        for (uint i = 0; i < puppetList.length; i++) {
            uint contribution = allocationPuppetMap(allocationKey, puppetList[i]);
            puppetContributions[i] = contribution;
            totalGrossAllocated += contribution;
        }
        assertEq(totalGrossAllocated, 100e6, "Gross Alloc mismatch");

        mirrorPosition.settle(usdc, defaultTraderPositionParams.trader, puppetList, allocationId);

        uint expectedFinalStoreBalance = allocationStoreBalanceAfterAllocate + settledAmount - platformFee;
        assertEq(usdc.balanceOf(address(allocationStore)), expectedFinalStoreBalance, "Store final balance");

        uint amountDistributed = settledAmount - platformFee;
        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            uint initialGrossContribution = puppetContributions[i];
            uint expectedShare = 0;
            if (totalGrossAllocated > 0) {
                expectedShare = (amountDistributed * initialGrossContribution) / totalGrossAllocated;
            }
            uint expectedFinalPuppetBalance = initialPuppetBalance - initialGrossContribution + expectedShare;
            // 100-10 + (180*10/100)=108

            assertEq(
                allocationStore.userBalanceMap(usdc, puppet),
                expectedFinalPuppetBalance,
                string(abi.encodePacked("Puppet ", Strings.toString(i)))
            );
        }
    }

    // --- Error Condition Tests ---

    function testExecutionRequestMissingError() public {
        bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));
        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);
    }

    function testNoSettledFundsError() public {
        address[] memory puppetList = generatePuppetList(1);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);

        // Try to settle without dealing funds to allocationAddress
        vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
        mirrorPosition.settle(usdc, defaultTraderPositionParams.trader, puppetList, allocationId);
    }

    function testAllocationExceedingMaximumPuppets() public {
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList;
        address[] memory tooManyPuppets = new address[](limitAllocationListLength + 1);
        for (uint i = 0; i < tooManyPuppets.length; i++) {
            tooManyPuppets[i] = address(uint160(uint(keccak256(abi.encodePacked("puppet", i))))); // Dummy addresses
        }

        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.allocate(defaultTraderPositionParams, tooManyPuppets);
    }

    // --- Boundary Condition Tests ---

    function testAllocationWithExactMaximumPuppets() public {
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList;
        // Ensure limit is reasonable for testing, e.g. 10-20, not 100
        // If config.maxPuppetList is large, this test will be very slow/expensive.
        // Consider adjusting config in setUp for this specific test or skip if too large.
        if (limitAllocationListLength > 20) {
            // Skip if limit is too high for test env
            console.log("Skipping testAllocationWithExactMaximumPuppets due to large maxPuppetList");
            return;
        }

        address[] memory maxPuppetList = new address[](limitAllocationListLength);
        for (uint i = 0; i < limitAllocationListLength; i++) {
            maxPuppetList[i] = createPuppet(
                usdc,
                defaultTraderPositionParams.trader,
                string(abi.encodePacked("maxPuppet:", Strings.toString(i))),
                10e6
            );
        }

        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, maxPuppetList);
        assertGt(allocationId, 0, "Allocation with maximum puppets should succeed");
    }

    // --- Functional Tests ---

    function testCollateralAdjustmentsMatchMirrorPostion() public {
        // Tests trader adding collateral only, checks mirrored size adjusts correctly (fixed mirrored collateral model)
        address[] memory puppetList = generatePuppetList(2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);

        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.isIncrease = true;
        initialParams.collateralDelta = 100e6;
        initialParams.sizeDeltaInUsd = 1000e30; // 10x leverage

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 2 * 100e6 * 10% = 20e6

        bytes32 increaseRequestKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        uint expectedInitialMirroredSize = (initialParams.sizeDeltaInUsd * netAllocated) / initialParams.collateralDelta; // 1000e30
            // * 20 / 100 = 200e30
        assertEq(pos1.size, expectedInitialMirroredSize, "Initial MSize");
        assertEq(pos1.collateral, netAllocated, "Initial MCollat");
        assertEq(pos1.traderSize, initialParams.sizeDeltaInUsd, "Initial TSize");
        assertEq(pos1.traderCollateral, initialParams.collateralDelta, "Initial TCollat");
        assertApproxEqAbs(
            Precision.toBasisPoints(pos1.size, pos1.collateral),
            Precision.toBasisPoints(pos1.traderSize, pos1.traderCollateral),
            LEVERAGE_TOLERANCE_BP,
            "Initial Leverage mismatch"
        );

        // Trader adds 100% more collateral, no size change (Leverage halves to 5x)
        MirrorPosition.PositionParams memory collateralAddParams = initialParams;
        collateralAddParams.isIncrease = true;
        collateralAddParams.collateralDelta = 100e6; // Add 100 USDC
        collateralAddParams.sizeDeltaInUsd = 0; // No size change

        bytes32 collateralAddKey = mirrorPosition.mirror{value: collateralAddParams.executionFee}(
            collateralAddParams, puppetList, allocationId
        );
        mirrorPosition.execute(collateralAddKey);

        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        uint expectedTraderSize2 = pos1.traderSize + collateralAddParams.sizeDeltaInUsd; // 1000e30
        uint expectedTraderCollat2 = pos1.traderCollateral + collateralAddParams.collateralDelta; // 200e6
        uint expectedMirroredSize2 = (expectedTraderSize2 * pos1.collateral) / expectedTraderCollat2; // (1000e30 *
            // 20e6) / 200e6 = 100e30

        assertEq(pos2.traderSize, expectedTraderSize2, "Adjust TSize");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "Adjust TCollat");
        assertEq(pos2.size, expectedMirroredSize2, "Adjust MSize"); // Should decrease
        assertEq(pos2.collateral, netAllocated, "Adjust MCollat"); // Should be fixed
        assertApproxEqAbs(
            Precision.toBasisPoints(pos2.size, pos2.collateral),
            Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral), // Should be ~5x
            LEVERAGE_TOLERANCE_BP,
            "Adjust Leverage mismatch"
        );
    }

    function testTinyPositionAdjustments() public {
        address trader = defaultTraderPositionParams.trader;
        address[] memory puppetList = generatePuppetList(2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.collateralDelta = 100e6;
        initialParams.sizeDeltaInUsd = 1000e30; // 10x leverage

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);

        bytes32 increaseRequestKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseRequestKey);

        // Make a tiny size adjustment (increase size by 1, collateral 0) -> increases leverage slightly
        MirrorPosition.PositionParams memory tinyParams = initialParams;
        tinyParams.isIncrease = true;
        tinyParams.collateralDelta = 0;
        tinyParams.sizeDeltaInUsd = 1; // Smallest possible size unit change

        bytes32 tinyRequestKey =
            mirrorPosition.mirror{value: tinyParams.executionFee}(tinyParams, puppetList, allocationId);
        assertEq(tinyRequestKey, bytes32(0), "Tiny adjustment (same leverage) should result in zero key");
    }

    function testVeryLargePositionAdjustments() public {
        address trader = defaultTraderPositionParams.trader;
        address[] memory puppetList = generatePuppetList(2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // Open initial small position (e.g., 10x leverage)
        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.collateralDelta = 10e6; // 10 USDC
        initialParams.sizeDeltaInUsd = 100e30; // 100 USD size

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 2 * 100e6 * 10% = 20e6

        bytes32 increaseRequestKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);

        // Make a very large adjustment (10x increase in size & collateral, maintaining leverage)
        MirrorPosition.PositionParams memory largeParams = initialParams;
        largeParams.isIncrease = true;
        largeParams.collateralDelta = 90e6; // Add 9x initial collateral
        largeParams.sizeDeltaInUsd = 900e30; // Add 9x initial size

        bytes32 largeRequestKey =
            mirrorPosition.mirror{value: largeParams.executionFee}(largeParams, puppetList, allocationId);
        // Since leverage doesn't change, mirror contract should detect no change needed for mirrored size
        assertEq(largeRequestKey, bytes32(0), "Large adjustment (same leverage) should result in zero key");

        // Verify state hasn't changed (execute shouldn't be called)
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos1.size, pos2.size, "Large MSize unchanged");
        assertEq(pos1.collateral, pos2.collateral, "Large MCollat unchanged");
        // Note: The trader's target state *is* stored in the request map even if no GMX order submitted,
        // but execute() isn't called, so positionMap doesn't update trader totals. This is expected.

        // Now test large adjustment that *changes* leverage (e.g., double size, keep collateral)
        MirrorPosition.PositionParams memory largeLeverageParams = initialParams;
        largeLeverageParams.isIncrease = true;
        largeLeverageParams.collateralDelta = 0; // No collateral change
        largeLeverageParams.sizeDeltaInUsd = 100e30; // Double size -> 20x leverage

        bytes32 largeLevRequestKey = mirrorPosition.mirror{value: largeLeverageParams.executionFee}(
            largeLeverageParams, puppetList, allocationId
        );
        assertNotEq(largeLevRequestKey, bytes32(0), "Large leverage change should yield order key");
        mirrorPosition.execute(largeLevRequestKey);

        MirrorPosition.Position memory pos3 = mirrorPosition.getPosition(allocationKey);
        uint expectedTraderSize3 = pos1.traderSize + largeLeverageParams.sizeDeltaInUsd; // 200e30
        uint expectedTraderCollat3 = pos1.traderCollateral + largeLeverageParams.collateralDelta; // 10e6
        uint expectedMirroredSize3 = (expectedTraderSize3 * pos1.collateral) / expectedTraderCollat3; // (200e30 * 20e6)
            // / 10e6 = 400e30

        assertEq(pos3.traderSize, expectedTraderSize3, "LargeLev TSize");
        assertEq(pos3.traderCollateral, expectedTraderCollat3, "LargeLev TCollat");
        assertEq(pos3.size, expectedMirroredSize3, "LargeLev MSize"); // Should double
        assertEq(pos3.collateral, netAllocated, "LargeLev MCollat");
        assertApproxEqAbs(
            Precision.toBasisPoints(pos3.size, pos3.collateral),
            Precision.toBasisPoints(pos3.traderSize, pos3.traderCollateral), // Should be ~20x
            LEVERAGE_TOLERANCE_BP,
            "LargeLev Leverage mismatch"
        );
    }

    function testComplexAdjustmentsAndEdgeCases() public {
        // Reuse setup from testCollateralAdjustments... but with 3 puppets? Let's use 2 for simplicity.
        address trader = defaultTraderPositionParams.trader;
        address[] memory puppetList = generatePuppetList(2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // 1. Open initial high leverage position (20x)
        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.collateralDelta = 50e6; // 50 USDC
        initialParams.sizeDeltaInUsd = 1000e30; // 1000 USD Size

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        bytes32 key1 = mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(key1);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        // Mirrored size = 1000e30 * 20 / 50 = 400e30
        uint traderLev1 = Precision.toBasisPoints(pos1.traderSize, pos1.traderCollateral); // ~20x
        uint mirrorLev1 = Precision.toBasisPoints(pos1.size, pos1.collateral);
        assertApproxEqAbs(mirrorLev1, traderLev1, LEVERAGE_TOLERANCE_BP, "Complex 1: Initial Lev");

        // 2. Complex Adjustment: Increase Size (500), Decrease Collateral (25) -> Higher Leverage
        MirrorPosition.PositionParams memory params2 = initialParams;
        params2.isIncrease = true; // This flag seems confusing for mixed actions, but contract uses it. Let's assume it
            // means *overall* direction if mixed? Re-check contract.
        // Contract uses isIncrease flag to determine +/- for TARGET calculation.
        // If trader intends +500 size AND -25 collat, isIncrease maybe should be ambiguous or based on size?
        // Let's test the contract as written: Assume isIncrease=true means apply deltas positively. No, contract logic
        // uses it to ADD or SUBTRACT deltas.
        // So, need two steps or a more complex param struct?
        // Let's simulate two steps: First decrease collat, then increase size.

        // Step 2a: Decrease Collateral 25e6
        MirrorPosition.PositionParams memory params2a = initialParams; // Base doesn't matter much here
        params2a.isIncrease = false; // Decrease collateral
        params2a.collateralDelta = 25e6;
        params2a.sizeDeltaInUsd = 0;
        bytes32 key2a = mirrorPosition.mirror{value: params2a.executionFee}(params2a, puppetList, allocationId);
        mirrorPosition.execute(key2a);
        MirrorPosition.Position memory pos2a = mirrorPosition.getPosition(allocationKey);
        // Trader State: 50-25=25e6 Collat, 1000e30 Size (40x Lev)
        // Mirrored State: 20e6 Collat, Size = 1000e30 * 20 / 25 = 800e30
        uint traderLev2a = Precision.toBasisPoints(pos2a.traderSize, pos2a.traderCollateral); // ~40x
        uint mirrorLev2a = Precision.toBasisPoints(pos2a.size, pos2a.collateral);
        assertApproxEqAbs(mirrorLev2a, traderLev2a, LEVERAGE_TOLERANCE_BP, "Complex 2a: Lev after Collat Dec");
        assertEq(pos2a.traderCollateral, 25e6, "Complex 2a: TCollat");
        assertEq(pos2a.size, 800e30, "Complex 2a: MSize");

        // Step 2b: Increase Size 500e30
        MirrorPosition.PositionParams memory params2b = initialParams;
        params2b.isIncrease = true; // Increase size
        params2b.collateralDelta = 0;
        params2b.sizeDeltaInUsd = 500e30;
        bytes32 key2b = mirrorPosition.mirror{value: params2b.executionFee}(params2b, puppetList, allocationId);
        mirrorPosition.execute(key2b);
        MirrorPosition.Position memory pos2b = mirrorPosition.getPosition(allocationKey);
        // Trader State: 25e6 Collat, 1000+500=1500e30 Size (60x Lev)
        // Mirrored State: 20e6 Collat, Size = 1500e30 * 20 / 25 = 1200e30
        uint traderLev2b = Precision.toBasisPoints(pos2b.traderSize, pos2b.traderCollateral); // ~60x
        uint mirrorLev2b = Precision.toBasisPoints(pos2b.size, pos2b.collateral);
        assertApproxEqAbs(mirrorLev2b, traderLev2b, LEVERAGE_TOLERANCE_BP, "Complex 2b: Lev after Size Inc");
        assertEq(pos2b.traderSize, 1500e30, "Complex 2b: TSize");
        assertEq(pos2b.size, 1200e30, "Complex 2b: MSize");

        // 3. Edge Case: Close from high leverage
        MirrorPosition.PositionParams memory params3 = initialParams;
        params3.isIncrease = false;
        params3.collateralDelta = pos2b.traderCollateral; // 25e6
        params3.sizeDeltaInUsd = pos2b.traderSize; // 1500e30
        bytes32 key3 = mirrorPosition.mirror{value: params3.executionFee}(params3, puppetList, allocationId);
        mirrorPosition.execute(key3);
        MirrorPosition.Position memory pos3 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos3.size, 0, "Complex 3: MSize after close");
        assertEq(pos3.traderSize, 0, "Complex 3: TSize after close");
    }

    // --- Fee Tests ---

    function testPlatformFeeCalculation() public {
        address trader = defaultTraderPositionParams.trader;
        setPerformanceFee(0.1e30); // 10% fee

        address[] memory puppetList = generatePuppetList(3);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.collateralDelta = 100e6;
        initialParams.sizeDeltaInUsd = 1000e30; // 10x

        uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 3 * 100e6 * 10% = 30e6

        bytes32 increaseKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseKey);

        // Close position
        MirrorPosition.PositionParams memory closeParams = initialParams;
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        closeParams.isIncrease = false;
        closeParams.collateralDelta = currentPos.traderCollateral;
        closeParams.sizeDeltaInUsd = currentPos.traderSize;
        bytes32 closeKey = mirrorPosition.mirror{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

        // Simulate profit: Return initial + 20% profit
        uint profit = netAllocated * 20 / 100; // 30e6 * 0.2 = 6e6
        uint settledAmountTotal = netAllocated + profit; // 36e6
        deal(address(usdc), allocationAddress, settledAmountTotal);

        uint feeMarketplaceBalanceBefore = usdc.balanceOf(address(feeMarketplaceStore));
        mirrorPosition.execute(closeKey);

        // Store contributions before settle deletes map
        uint totalGrossAllocated = 0;
        uint[] memory contributions = new uint[](puppetList.length);
        for (uint i = 0; i < puppetList.length; ++i) {
            uint contribution = allocationPuppetMap(allocationKey, puppetList[i]);
            contributions[i] = contribution;
            totalGrossAllocated += contribution;
        }

        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        uint feeMarketplaceBalanceAfter = usdc.balanceOf(address(feeMarketplaceStore));
        uint feeCollected = feeMarketplaceBalanceAfter - feeMarketplaceBalanceBefore;

        // Expected fee: 36e6 * 10% = 3.6e6
        uint expectedFee = (settledAmountTotal * 1000) / 10000; // 10% = 1000 / 10000 bp
        // Or using Precision library if it handles e30 factors
        // uint expectedFee = Precision.applyFactor(settledAmountTotal, 0.1e30);
        assertEq(feeCollected, expectedFee, "Fee collected mismatch");
    }

    function testFeeCalculationWithDifferentPercentages() public {
        address trader = users.bob;
        uint[] memory feeFactors = new uint[](3);
        feeFactors[0] = 0.05e30; // 5%
        feeFactors[1] = 0.2e30; // 20%
        feeFactors[2] = 0; // 0%

        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        initialParams.collateralDelta = 50e6;
        initialParams.sizeDeltaInUsd = 500e30; // 10x

        for (uint i = 0; i < feeFactors.length; i++) {
            setPerformanceFee(feeFactors[i]); // Assumes setPerformanceFee updates mirrorPosition config correctly

            address[] memory puppetList = generatePuppetList(2);
            bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
            uint allocationId = mirrorPosition.allocate(initialParams, puppetList);
            bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
            address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
                mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
            );
            uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 2 * 100e6 * 10% = 20e6

            bytes32 increaseKey =
                mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
            mirrorPosition.execute(increaseKey);

            MirrorPosition.PositionParams memory closeParams = initialParams;
            MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
            closeParams.isIncrease = false;
            closeParams.collateralDelta = currentPos.traderCollateral;
            closeParams.sizeDeltaInUsd = currentPos.traderSize;
            bytes32 closeKey =
                mirrorPosition.mirror{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

            // Simulate 50% profit
            uint profit = netAllocated * 50 / 100; // 10e6
            uint settledAmountTotal = netAllocated + profit; // 30e6
            deal(address(usdc), allocationAddress, settledAmountTotal);

            uint feeMarketplaceBalanceBefore = usdc.balanceOf(address(feeMarketplaceStore));
            mirrorPosition.execute(closeKey);

            // Store contributions before settle
            uint totalGrossAllocated = 0;
            uint[] memory contributions = new uint[](puppetList.length);
            for (uint j = 0; j < puppetList.length; ++j) {
                uint contribution = allocationPuppetMap(allocationKey, puppetList[j]);
                contributions[j] = contribution;
                totalGrossAllocated += contribution;
            }

            mirrorPosition.settle(usdc, trader, puppetList, allocationId);

            uint feeMarketplaceBalanceAfter = usdc.balanceOf(address(feeMarketplaceStore));
            uint feeCollected = feeMarketplaceBalanceAfter - feeMarketplaceBalanceBefore;

            uint expectedFee = Precision.applyFactor(settledAmountTotal, feeFactors[i]);
            assertEq(
                feeCollected,
                expectedFee,
                string(abi.encodePacked("Fee mismatch for factor: ", Strings.toString(feeFactors[i])))
            );
        }
    }

    // --- Settlement Tests ---

    function testPositionSettlementWithProfit() public {
        address trader = defaultTraderPositionParams.trader;
        setPerformanceFee(0.1e30); // 10% fee

        // Use puppets with different initial balances to test proportionality
        address puppet1 = createPuppet(usdc, trader, "profitPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, trader, "profitPuppet2", 200e6); // Double balance
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 10e6 + 20e6 = 30e6

        uint puppet1InitialBalance = 100e6;
        uint puppet2InitialBalance = 200e6;

        // Store contributions before settle deletes map
        uint totalGrossAllocated = 0;
        uint[] memory contributions = new uint[](puppetList.length);
        for (uint i = 0; i < puppetList.length; ++i) {
            uint contribution = allocationPuppetMap(allocationKey, puppetList[i]);
            contributions[i] = contribution;
            totalGrossAllocated += contribution;
        }
        assertEq(totalGrossAllocated, 30e6, "Profit Gross Alloc"); // 10e6 + 20e6

        // Open & Close Position (details less important than settlement part)
        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams; // Assume some valid open
        bytes32 increaseKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseKey);
        MirrorPosition.PositionParams memory closeParams = initialParams;
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        closeParams.isIncrease = false;
        closeParams.collateralDelta = currentPos.traderCollateral;
        closeParams.sizeDeltaInUsd = currentPos.traderSize;
        bytes32 closeKey = mirrorPosition.mirror{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

        // Simulate Profit: netAllocated + 50% profit = 30e6 + 15e6 = 45e6
        uint profit = netAllocated * 50 / 100;
        uint settledAmountTotal = netAllocated + profit;
        deal(address(usdc), allocationAddress, settledAmountTotal);

        mirrorPosition.execute(closeKey);
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        // Check final balances
        uint platformFee = Precision.applyFactor(settledAmountTotal, 0.1e30); // 4.5e6
        uint amountDistributed = settledAmountTotal - platformFee; // 40.5e6

        uint puppet1Contrib = contributions[0]; // 10e6
        uint puppet2Contrib = contributions[1]; // 20e6

        uint puppet1ExpectedShare = (amountDistributed * puppet1Contrib) / totalGrossAllocated; // 40.5 * 10 / 30 =
            // 13.5e6
        uint puppet2ExpectedShare = (amountDistributed * puppet2Contrib) / totalGrossAllocated; // 40.5 * 20 / 30 =
            // 27.0e6

        uint puppet1ExpectedFinalBalance = puppet1InitialBalance - puppet1Contrib + puppet1ExpectedShare; // 100 - 10 +
            // 13.5 = 103.5e6
        uint puppet2ExpectedFinalBalance = puppet2InitialBalance - puppet2Contrib + puppet2ExpectedShare; // 200 - 20 +
            // 27.0 = 207.0e6

        assertEq(allocationStore.userBalanceMap(usdc, puppet1), puppet1ExpectedFinalBalance, "Puppet1 Profit Share");
        assertEq(allocationStore.userBalanceMap(usdc, puppet2), puppet2ExpectedFinalBalance, "Puppet2 Profit Share");
    }

    function testPositionSettlementWithLoss() public {
        address trader = defaultTraderPositionParams.trader;
        setPerformanceFee(0.1e30); // 10% fee

        address puppet1 = createPuppet(usdc, trader, "lossPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, trader, "lossPuppet2", 100e6);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 10e6 + 10e6 = 20e6

        uint puppet1InitialBalance = 100e6;
        uint puppet2InitialBalance = 100e6;

        // Store contributions before settle deletes map
        uint totalGrossAllocated = 0;
        uint[] memory contributions = new uint[](puppetList.length);
        for (uint i = 0; i < puppetList.length; ++i) {
            uint contribution = allocationPuppetMap(allocationKey, puppetList[i]);
            contributions[i] = contribution;
            totalGrossAllocated += contribution;
        }
        assertEq(totalGrossAllocated, 20e6, "Loss Gross Alloc"); // 10e6 + 10e6

        // Open & Close Position
        MirrorPosition.PositionParams memory initialParams = defaultTraderPositionParams;
        bytes32 increaseKey =
            mirrorPosition.mirror{value: initialParams.executionFee}(initialParams, puppetList, allocationId);
        mirrorPosition.execute(increaseKey);
        MirrorPosition.PositionParams memory closeParams = initialParams;
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        closeParams.isIncrease = false;
        closeParams.collateralDelta = currentPos.traderCollateral;
        closeParams.sizeDeltaInUsd = currentPos.traderSize;
        bytes32 closeKey = mirrorPosition.mirror{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

        // Simulate Loss: Return only 50% of netAllocated = 10e6
        uint lossAmount = netAllocated / 2;
        uint settledAmountTotal = lossAmount;
        deal(address(usdc), allocationAddress, settledAmountTotal);

        mirrorPosition.execute(closeKey);
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        // Check final balances
        uint platformFee = Precision.applyFactor(settledAmountTotal, 0.1e30); // 10% of 10e6 = 1e6
        uint amountDistributed = settledAmountTotal - platformFee; // 9e6

        uint puppet1Contrib = contributions[0]; // 10e6
        uint puppet2Contrib = contributions[1]; // 10e6

        uint puppet1ExpectedShare = (amountDistributed * puppet1Contrib) / totalGrossAllocated; // 9 * 10 / 20 = 4.5e6
        uint puppet2ExpectedShare = (amountDistributed * puppet2Contrib) / totalGrossAllocated; // 9 * 10 / 20 = 4.5e6

        uint puppet1ExpectedFinalBalance = puppet1InitialBalance - puppet1Contrib + puppet1ExpectedShare; // 100 - 10 +
            // 4.5 = 94.5e6
        uint puppet2ExpectedFinalBalance = puppet2InitialBalance - puppet2Contrib + puppet2ExpectedShare; // 100 - 10 +
            // 4.5 = 94.5e6

        assertEq(allocationStore.userBalanceMap(usdc, puppet1), puppet1ExpectedFinalBalance, "Puppet1 Loss Share");
        assertEq(allocationStore.userBalanceMap(usdc, puppet2), puppet2ExpectedFinalBalance, "Puppet2 Loss Share");
    }

    // --- Multi-Asset Test ---

    function testMultiplePositionsWithDifferentTokens() public {
        address trader = defaultTraderPositionParams.trader;

        // USDC Position Setup
        address[] memory usdcPuppetList = generatePuppetList(2);
        bytes32 usdcMatchKey = PositionUtils.getMatchKey(usdc, trader);
        MirrorPosition.PositionParams memory usdcParams = defaultTraderPositionParams; // Uses USDC by default
        uint usdcAllocationId = mirrorPosition.allocate(usdcParams, usdcPuppetList);
        bytes32 usdcAllocationKey = getAllocationKey(usdcPuppetList, usdcMatchKey, usdcAllocationId);

        // WETH Position Setup
        // Ensure WETH is funded and approved for puppets (modify createPuppet or add setup)
        address[] memory wethPuppetList = new address[](2);
        uint wethFundValue = 0.1e18; // 0.1 WETH
        for (uint i = 0; i < 2; i++) {
            // Need a distinct name or address derivation for WETH puppets
            wethPuppetList[i] =
                createPuppet(wnt, trader, string(abi.encodePacked("weth-puppet:", Strings.toString(i))), wethFundValue);
        }
        bytes32 wethMatchKey = PositionUtils.getMatchKey(wnt, trader);
        MirrorPosition.PositionParams memory wethParams = defaultTraderPositionParams; // Copy default
        wethParams.collateralToken = wnt; // Change token
        wethParams.collateralDelta = 0.1e18; // Use WETH amounts
        wethParams.sizeDeltaInUsd = 3000e30; // Example size relative to 0.1 WETH (~3k USD at 30k/ETH) -> 10x

        uint wethAllocationId = mirrorPosition.allocate(wethParams, wethPuppetList);
        bytes32 wethAllocationKey = getAllocationKey(wethPuppetList, wethMatchKey, wethAllocationId);

        // Open USDC position
        bytes32 usdcIncreaseRequestKey =
            mirrorPosition.mirror{value: usdcParams.executionFee}(usdcParams, usdcPuppetList, usdcAllocationId);
        mirrorPosition.execute(usdcIncreaseRequestKey);

        // Open WETH position
        bytes32 wethIncreaseRequestKey =
            mirrorPosition.mirror{value: wethParams.executionFee}(wethParams, wethPuppetList, wethAllocationId);
        mirrorPosition.execute(wethIncreaseRequestKey);

        // Verify both positions exist independently
        MirrorPosition.Position memory usdcPosition1 = mirrorPosition.getPosition(usdcAllocationKey);
        MirrorPosition.Position memory wethPosition1 = mirrorPosition.getPosition(wethAllocationKey);

        assertGt(usdcPosition1.size, 0, "USDC position size should be > 0");
        assertGt(wethPosition1.size, 0, "WETH position size should be > 0");
        assertEq(usdcPosition1.traderSize, usdcParams.sizeDeltaInUsd, "USDC TSize");
        assertEq(wethPosition1.traderSize, wethParams.sizeDeltaInUsd, "WETH TSize");

        // Modify USDC position (e.g., add collateral) without affecting WETH position
        MirrorPosition.PositionParams memory usdcModifyParams = usdcParams;
        usdcModifyParams.isIncrease = true;
        usdcModifyParams.collateralDelta = 50e6; // Add 50 USDC collateral
        usdcModifyParams.sizeDeltaInUsd = 0;

        bytes32 usdcModifyRequestKey = mirrorPosition.mirror{value: usdcModifyParams.executionFee}(
            usdcModifyParams, usdcPuppetList, usdcAllocationId
        );
        mirrorPosition.execute(usdcModifyRequestKey);

        // Verify USDC position changed but WETH position remained the same
        MirrorPosition.Position memory usdcPositionAfter = mirrorPosition.getPosition(usdcAllocationKey);
        MirrorPosition.Position memory wethPositionAfter = mirrorPosition.getPosition(wethAllocationKey);

        uint expectedUsdcTraderCollat = usdcPosition1.traderCollateral + usdcModifyParams.collateralDelta;
        assertEq(usdcPositionAfter.traderCollateral, expectedUsdcTraderCollat, "USDC TCollat modified");
        // WETH trader collateral should be unchanged from its initial state
        assertEq(wethPositionAfter.traderCollateral, wethPosition1.traderCollateral, "WETH TCollat unchanged");
        // WETH mirrored size should be unchanged from its initial state
        assertEq(wethPositionAfter.size, wethPosition1.size, "WETH MSize unchanged");
    }

    // --- Security Test ---

    function testAccessControlForCriticalFunctions() public {
        address trader = users.bob;
        address unauthorized = users.alice; // Assumes alice is not owner

        address[] memory puppetList = generatePuppetList(1);

        // Test unauthorized access to allocate
        vm.startPrank(unauthorized);
        vm.expectRevert(); // Default revert without specific error message check
        mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        vm.stopPrank();

        // Set up a valid allocation as owner
        vm.startPrank(users.owner);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        vm.stopPrank();

        // Test unauthorized access to mirror
        vm.startPrank(unauthorized);
        vm.expectRevert();
        mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            defaultTraderPositionParams, puppetList, allocationId
        );
        vm.stopPrank();

        // Create a valid request as owner
        vm.startPrank(users.owner);
        bytes32 requestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            defaultTraderPositionParams, puppetList, allocationId
        );
        vm.stopPrank();

        // Test unauthorized access to execute
        vm.startPrank(unauthorized);
        vm.expectRevert();
        mirrorPosition.execute(requestKey);
        vm.stopPrank();

        // Execute as owner
        vm.startPrank(users.owner);
        mirrorPosition.execute(requestKey);
        // Close position before settling
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(
            getAllocationKey(puppetList, PositionUtils.getMatchKey(usdc, trader), allocationId)
        );
        MirrorPosition.PositionParams memory closeParams = defaultTraderPositionParams;
        closeParams.isIncrease = false;
        closeParams.collateralDelta = currentPos.traderCollateral;
        closeParams.sizeDeltaInUsd = currentPos.traderSize;
        bytes32 closeKey = mirrorPosition.mirror{value: closeParams.executionFee}(closeParams, puppetList, allocationId);
        mirrorPosition.execute(closeKey);
        // Deal funds for settlement
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(),
            getAllocationKey(puppetList, PositionUtils.getMatchKey(usdc, trader), allocationId),
            address(mirrorPosition)
        );
        deal(address(usdc), allocationAddress, 10e6); // Deal some amount back
        vm.stopPrank();

        // Test unauthorized settlement
        vm.startPrank(unauthorized);
        vm.expectRevert();
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);
        vm.stopPrank();

        // Test unauthorized config change
        vm.startPrank(unauthorized);
        vm.expectRevert();
        mirrorPosition.configMaxCollateralTokenAllocation(usdc, 1e6);
        vm.stopPrank();
    }

    // --- Helper Functions ---

    function setPerformanceFee(
        uint newFeeFactor
    ) internal {
        MirrorPosition.Config memory currentConfig = mirrorPosition.getConfig();
        currentConfig.platformSettleFeeFactor = newFeeFactor;
        dictator.setConfig(mirrorPosition, abi.encode(currentConfig));
    }

    function getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint allocationId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_puppetList, _matchKey, allocationId));
    }

    function generatePuppetList(
        address trader,
        uint _length,
        MockERC20 collateralToken,
        uint fundValue // Add fund value parameter
    ) internal returns (address[] memory) {
        address[] memory puppetList = new address[](_length);
        for (uint i = 0; i < _length; i++) {
            puppetList[i] = createPuppet(
                collateralToken, trader, string(abi.encodePacked("puppet:", Strings.toString(i))), fundValue
            );
        }
        return puppetList;
    }

    // Overload without trader, uses default
    function generatePuppetList(
        uint _length
    ) internal returns (address[] memory) {
        return generatePuppetList(defaultTraderPositionParams.trader, _length, usdc, 100e6);
    }

    // Note: createPuppet might be redundant if generatePuppetList covers setup sufficiently
    function createPuppet(
        MockERC20 collateralToken,
        address trader,
        string memory name, // Using name for address generation
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        deal(address(collateralToken), user, fundValue);

        vm.startPrank(user);
        collateralToken.approve(address(tokenRouter), type(uint).max);

        vm.startPrank(users.owner);
        matchRule.deposit(collateralToken, user, fundValue);
        matchRule.setRule(
            collateralToken,
            user, // puppet address
            trader,
            MatchRule.Rule({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 2 days}) // 10%
        );
        return user;
    }

    function allocationPuppetMap(bytes32 allocationKey, address puppet) internal view returns (uint) {
        return mirrorPosition.allocationPuppetMap(allocationKey, puppet);
    }
}
