// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol"; // Import Vm for expectRevert etc.

import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol"; // Added for OrderType
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AllocationAccount} from "src/shared/AllocationAccount.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Error} from "src/utils/Error.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";
import {Const} from "script/Const.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract TradingTest is BasicSetup {
    AllocationStore internal allocationStore;
    MatchingRule internal matchingRule;
    FeeMarketplace internal feeMarketplace;
    MirrorPosition internal mirrorPosition;
    MockGmxExchangeRouter internal mockGmxExchangeRouter;
    FeeMarketplaceStore internal feeMarketplaceStore;

    uint internal constant LEVERAGE_TOLERANCE_BP = 5; // Use slightly larger tolerance for e30 math

    uint internal nextAllocationId = 0;

    function getNextAllocationId() internal returns (uint) {
        return ++nextAllocationId;
    }

    MirrorPosition.CallPosition defaultCallPosition;
    MirrorPosition.CallSettle defaultCallSettle;

    function setUp() public override {
        super.setUp();

        defaultCallPosition = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: users.bob,
            market: Const.gmxEthUsdcMarket,
            keeperExecutionFeeReceiver: users.yossi,
            isIncrease: true,
            isLong: true, // Match original direction
            executionFee: 5_000_000 * 1 gwei,
            collateralDelta: 100e6, // Close full trader collateral
            sizeDeltaInUsd: 1000e30, // 1000 USD (10x leverage implied)
            acceptablePrice: 0,
            triggerPrice: 0,
            keeperExecutionFee: 1e6 // Mirror execution fee (not used in this test)
        });

        defaultCallSettle = MirrorPosition.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            trader: defaultCallPosition.trader,
            allocationId: 0,
            keeperExecutionFeeReceiver: users.yossi,
            keeperExecutionFee: 1e6 // Mirror execution fee (not used in this test)
        });

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        allocationStore = new AllocationStore(dictator, tokenRouter);
        matchingRule = new MatchingRule(
            dictator,
            allocationStore,
            MatchingRule.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 100, // 1 basis points = 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                distributionTimeframe: 1 days,
                burnBasisPoints: 10000,
                feeDistributor: BankStore(address(0))
            })
        );
        mirrorPosition = new MirrorPosition(
            dictator,
            allocationStore,
            MirrorPosition.Config({
                gmxExchangeRouter: mockGmxExchangeRouter,
                callbackHandler: address(this),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                increaseCallbackGasLimit: 2_000_000,
                decreaseCallbackGasLimit: 2_000_000,
                platformSettleFeeFactor: 0.1e30, // 10%
                maxPuppetList: 20,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.05e30, // 5%
                maxKeeperFeeToCollectDustRatio: 0.1e30 // 10%
            })
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));

        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));

        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        dictator.setPermission(matchingRule, matchingRule.setRule.selector, users.owner);
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, users.owner);
        dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, users.owner);
        dictator.initContract(matchingRule);

        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.collectDust.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.setTokenDustThresholdList.selector, users.owner);
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.initializeTraderActivityThrottle.selector,
            address(matchingRule) // MatchingRule initializes throttle
        );
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, users.owner);
        dictator.initContract(mirrorPosition);

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.initContract(feeMarketplace);
        feeMarketplace.setAskPrice(usdc, 100e18);

        // Config
        IERC20[] memory allowedTokenList = new IERC20[](2);
        allowedTokenList[0] = wnt;
        allowedTokenList[1] = usdc;

        // Configure contracts

        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        matchingRule.setTokenAllowanceList(allowedTokenList, tokenAllowanceCapAmountList);

        // Set dust thresholds
        uint[] memory dustThresholds = new uint[](2);
        dustThresholds[0] = 0.001e18; // 0.001 WNT
        dustThresholds[1] = 1e6; // 1 USDC
        mirrorPosition.setTokenDustThresholdList(allowedTokenList, dustThresholds);

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

    function testSimpleExecutionResult() public {
        uint initialPuppetBalance = 100e6;
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 10);
        uint allocationStoreBalanceBefore = usdc.balanceOf(address(allocationStore));
        uint initialGrossTotalAllocation = 100e6; // 10 puppets * 10e6 contribution each

        // 1. Initial Mirror (combines allocation & opening)
        MirrorPosition.CallPosition memory callIncrease = defaultCallPosition;

        uint allocationId = getNextAllocationId();
        (address allocationAddress, bytes32 increaseRequestKey) =
            mirrorPosition.requestMirror{value: callIncrease.executionFee}(matchingRule, callIncrease, puppetList, allocationId);
        assertNotEq(increaseRequestKey, bytes32(0));
        assertNotEq(allocationId, 0);

        uint netAllocationFromMirror = mirrorPosition.getAllocation(allocationAddress);
        // Expect 10 puppets * 100e6 balance * 10% rule = 100e6 GROSS, minus 1e6 keeper fee = 99e6 NET
        assertEq(netAllocationFromMirror, 99e6, "Net allocation from mirror should be 99e6");

        // Check balance change in AllocationStore OR GMX Vault after mirror()
        // Mirror transfers NET allocated amount to vault
        // assertEq(usdc.balanceOf(Const.gmxOrderVault), netAllocationFromMirror, "Vault balance after mirror
        // mismatch");
        // Alternatively check AllocationStore balance decreased
        // Store balance reduces by GROSS allocated (100e6)
        uint allocationStoreBalanceAfterMirror = allocationStoreBalanceBefore - initialGrossTotalAllocation;
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            allocationStoreBalanceAfterMirror,
            "AllocStore balance after mirror"
        );

        // 2. Execute Increase
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationAddress);

        // Calculate expected initial size based on the new logic in mirror() using NET allocation
        uint expectedInitialMirroredSize =
            callIncrease.sizeDeltaInUsd * netAllocationFromMirror / callIncrease.collateralDelta;
        // Expected: 1000e30 * 99e6 / 100e6 = 990e30
        assertEq(
            expectedInitialMirroredSize,
            defaultCallPosition.sizeDeltaInUsd * netAllocationFromMirror / defaultCallPosition.collateralDelta,
            "Calculated initial mirrored size mismatch"
        );

        assertEq(pos1.traderSize, defaultCallPosition.sizeDeltaInUsd, "pos1.traderSize");
        assertEq(pos1.traderCollateral, defaultCallPosition.collateralDelta, "pos1.traderCollateral");
        assertEq(pos1.size, expectedInitialMirroredSize, "pos1.size mismatch"); // Mirrored size based on net allocation

        // 3. Adjust Decrease (Full Close) using adjust()
        MirrorPosition.CallPosition memory callDecrease = defaultCallPosition;
        callDecrease.collateralDelta = pos1.traderCollateral; // Decrease by current trader collateral
        callDecrease.sizeDeltaInUsd = pos1.traderSize; // Decrease by current trader size
        callDecrease.isIncrease = false; // Decrease position

        bytes32 decreaseRequestKey =
            mirrorPosition.requestAdjust{value: callDecrease.executionFee}(callDecrease, puppetList, allocationId);
        assertNotEq(decreaseRequestKey, bytes32(0));

        // Calculate netAllocated considering NET allocation from mirror minus the close keeper fee for PnL simulation
        uint netAllocatedForPnL = netAllocationFromMirror - callDecrease.keeperExecutionFee; // 99e6 - 1e6 = 98e6

        // 4. Simulate Profit & Execute Decrease
        uint profit = netAllocatedForPnL; // 100% profit on NET allocated capital (after close fee) = 98e6
        uint settledAmount = netAllocatedForPnL + profit; // Return = 98e6 + 98e6 = 196e6

        deal(address(usdc), allocationAddress, settledAmount); // Deal funds to allocation account
        mirrorPosition.execute(decreaseRequestKey); // Simulate GMX callback executing the close

        // Check position is closed
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationAddress);
        assertEq(pos2.traderSize, 0, "pos2.traderSize should be 0");
        assertEq(pos2.traderCollateral, 0, "pos2.traderCollateral should be 0");
        assertEq(pos2.size, 0, "pos2.size should be 0");

        // 5. Settle
        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
        mirrorPosition.settle(feeMarketplace, callSettle, puppetList);

        // --- Recalculate expected balances ---

        // Calculate platform fee based on amount after settlement keeper fee
        uint amountForFeeCalc =
            settledAmount > callSettle.keeperExecutionFee ? settledAmount - callSettle.keeperExecutionFee : 0; // 196e6 -
            // 1e6 = 195e6
        uint platformFeeCalculated = Precision.applyFactor(_getSettleFeeFactor(), amountForFeeCalc); // 0.1 * 195e6 =
            // 19.5e6

        // Calculate amount distributed during settlement
        uint settlementDeductions = platformFeeCalculated + callSettle.keeperExecutionFee; // 19.5e6 + 1e6 = 20.5e6
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0; // 196e6
            // - 20.5e6 = 175.5e6

        // Check store balance increased correctly
        // Expected final balance = (balance after mirror - adjust fee) + distributed amount
        // The adjust fee was paid from the store before settlement
        uint expectedAllocationStoreFinalBalance =
            allocationStoreBalanceAfterMirror - callDecrease.keeperExecutionFee + amountDistributed;
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            expectedAllocationStoreFinalBalance, // Compare against calculated expected balance
            "Allocation store final balance mismatch"
        );

        // 6. Check puppet balances
        // Calculate expected balance after adjust fee deduction
        uint initialContributionPerPuppet = initialGrossTotalAllocation / puppetList.length; // 100e6 / 10 = 10e6
        uint adjustFeePerPuppet =
            Math.mulDiv(callDecrease.keeperExecutionFee, initialContributionPerPuppet, initialGrossTotalAllocation); // 1e6
            // * 10e6 / 100e6 = 0.1e6
        uint balanceAfterAdjust = initialPuppetBalance - initialContributionPerPuppet - adjustFeePerPuppet; // 100e6 -
            // 10e6 - 0.1e6 = 89.9e6

        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            uint contribution = mirrorPosition.allocationPuppetMap(allocationAddress, puppet);
            assertEq(contribution, initialContributionPerPuppet, "Contribution mismatch"); // Verify assumption

            // Calculate expected share based on INITIAL GROSS allocation ratio
            uint expectedShare = Math.mulDiv(amountDistributed, contribution, initialGrossTotalAllocation); // 175.5e6 *
                // 10e6 / 100e6 = 17.55e6

            // Calculate final expected balance
            uint expectedFinalBalance = balanceAfterAdjust + expectedShare; // 89.9e6 + 17.55e6 = 107.45e6

            // Use approximate equality to account for precision differences in address generation
            uint actualFinalBalance = allocationStore.userBalanceMap(usdc, puppet);
            assertApproxEqAbs(
                actualFinalBalance,
                expectedFinalBalance,
                200000, // Allow 0.2e6 tolerance for precision differences
                string(abi.encodePacked("Puppet ", Strings.toString(i), " final balance mismatch"))
            );
        }
    }

    function testExecutionRequestMissingError() public {
        bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));
        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);
    }

    function testAdjustNonExistentPositionError() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);

        MirrorPosition.CallPosition memory callAdjust = defaultCallPosition;

        uint nonExistentAllocationId = 99999; // An ID for which mirror was not called
        vm.expectRevert(Error.MirrorPosition__AllocationAccountNotFound.selector);
        mirrorPosition.requestAdjust{value: callAdjust.executionFee}(callAdjust, puppetList, nonExistentAllocationId);
    }

    function testMirrorExceedingMaximumPuppets() public {
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList; // Should be 20
        address[] memory tooManyPuppets = new address[](limitAllocationListLength + 1);
        for (uint i = 0; i < tooManyPuppets.length; i++) {
            tooManyPuppets[i] = address(uint160(uint(keccak256(abi.encodePacked("dummyPuppet", i)))));
        }

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.requestMirror{value: callOpen.executionFee}(matchingRule, callOpen, tooManyPuppets, getNextAllocationId());
    }

    function testProportionalProfitDistribution() public {
        address trader = defaultCallPosition.trader;
        address puppet1 = _createPuppet(usdc, trader, "puppet1", 50e6);
        address puppet2 = _createPuppet(usdc, trader, "puppet2", 100e6);
        address puppet3 = _createPuppet(usdc, trader, "puppet3", 150e6);

        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        uint puppet1InitialBalance = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2InitialBalance = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3InitialBalance = allocationStore.userBalanceMap(usdc, puppet3);

        MirrorPosition.CallPosition memory callParams = defaultCallPosition;
        uint allocationId = getNextAllocationId();
        (address allocationAddress, bytes32 requestKey) =
            mirrorPosition.requestMirror{value: callParams.executionFee}(matchingRule, callParams, puppetList, allocationId);

        mirrorPosition.execute(requestKey);

        uint puppet1Contribution = mirrorPosition.allocationPuppetMap(allocationAddress, puppet1);
        uint puppet2Contribution = mirrorPosition.allocationPuppetMap(allocationAddress, puppet2);
        uint puppet3Contribution = mirrorPosition.allocationPuppetMap(allocationAddress, puppet3);
        uint initialGrossTotalContribution = puppet1Contribution + puppet2Contribution + puppet3Contribution;
        uint netAllocationFromMirror = mirrorPosition.getAllocation(allocationAddress);

        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationAddress);
        MirrorPosition.CallPosition memory closeParams = defaultCallPosition;
        closeParams.isIncrease = false;
        closeParams.collateralDelta = position.traderCollateral;
        closeParams.sizeDeltaInUsd = position.traderSize;

        bytes32 closeKey =
            mirrorPosition.requestAdjust{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

        uint netAllocatedForPnL = netAllocationFromMirror - closeParams.keeperExecutionFee;

        uint profit = netAllocatedForPnL * 3 / 2;
        uint settledAmount = netAllocatedForPnL + profit;

        deal(address(usdc), allocationAddress, settledAmount);
        mirrorPosition.execute(closeKey);

        MirrorPosition.CallSettle memory settleParams = defaultCallSettle;
        settleParams.allocationId = allocationId;
        mirrorPosition.settle(feeMarketplace, settleParams, puppetList);

        uint puppet1ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet1Contribution, initialGrossTotalContribution);
        uint puppet2ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet2Contribution, initialGrossTotalContribution);
        uint puppet3ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet3Contribution, initialGrossTotalContribution);
        uint puppet1BalanceAfterAdjust = puppet1InitialBalance - puppet1Contribution - puppet1ShareOfAdjustFee;
        uint puppet2BalanceAfterAdjust = puppet2InitialBalance - puppet2Contribution - puppet2ShareOfAdjustFee;
        uint puppet3BalanceAfterAdjust = puppet3InitialBalance - puppet3Contribution - puppet3ShareOfAdjustFee;

        uint amountForFeeCalc =
            settledAmount > settleParams.keeperExecutionFee ? settledAmount - settleParams.keeperExecutionFee : 0;
        uint platformFeeCalculated = Precision.applyFactor(_getSettleFeeFactor(), amountForFeeCalc);

        uint settlementDeductions = platformFeeCalculated + settleParams.keeperExecutionFee;
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0;

        uint puppet1ExpectedShare = Math.mulDiv(amountDistributed, puppet1Contribution, initialGrossTotalContribution);
        uint puppet2ExpectedShare = Math.mulDiv(amountDistributed, puppet2Contribution, initialGrossTotalContribution);
        uint puppet3ExpectedShare = Math.mulDiv(amountDistributed, puppet3Contribution, initialGrossTotalContribution);

        uint puppet1ExpectedFinalBalance = puppet1BalanceAfterAdjust + puppet1ExpectedShare;
        uint puppet2ExpectedFinalBalance = puppet2BalanceAfterAdjust + puppet2ExpectedShare;
        uint puppet3ExpectedFinalBalance = puppet3BalanceAfterAdjust + puppet3ExpectedShare;

        uint puppet1FinalBalance = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2FinalBalance = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3FinalBalance = allocationStore.userBalanceMap(usdc, puppet3);

        assertApproxEqAbs(puppet1FinalBalance, puppet1ExpectedFinalBalance, 1500000, "Puppet1 final balance incorrect");
        assertApproxEqAbs(puppet2FinalBalance, puppet2ExpectedFinalBalance, 1500000, "Puppet2 final balance incorrect");
        assertApproxEqAbs(puppet3FinalBalance, puppet3ExpectedFinalBalance, 1500000, "Puppet3 final balance incorrect");

        if (amountDistributed > 0) {
            assertApproxEqRel(
                puppet1ExpectedShare * 10000 / amountDistributed,
                puppet1Contribution * 10000 / initialGrossTotalContribution,
                10,
                "Puppet1 return ratio should match contribution ratio"
            );
            assertApproxEqRel(
                puppet2ExpectedShare * 10000 / amountDistributed,
                puppet2Contribution * 10000 / initialGrossTotalContribution,
                10,
                "Puppet2 return ratio should match contribution ratio"
            );
            assertApproxEqRel(
                puppet3ExpectedShare * 10000 / amountDistributed,
                puppet3Contribution * 10000 / initialGrossTotalContribution,
                10,
                "Puppet3 return ratio should match contribution ratio"
            );
        }
    }

    function testPositionSettlementWithLoss() public {
        address trader = defaultCallPosition.trader;
        uint feeFactor = _getSettleFeeFactor();

        address puppet1 = _createPuppet(usdc, trader, "lossPuppet1", 100e6);
        address puppet2 = _createPuppet(usdc, trader, "lossPuppet2", 100e6);
        address puppet3 = _createPuppet(usdc, trader, "lossPuppet3", 100e6);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        uint initialGrossTotalAllocation = 30e6;

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        uint allocationId = getNextAllocationId();
        (address allocationAddress, bytes32 openKey) =
            mirrorPosition.requestMirror{value: callOpen.executionFee}(matchingRule, callOpen, puppetList, allocationId);
        assertNotEq(allocationId, 0);

        uint puppet1Allocation = mirrorPosition.allocationPuppetMap(allocationAddress, puppet1);
        uint puppet2Allocation = mirrorPosition.allocationPuppetMap(allocationAddress, puppet2);
        uint puppet3Allocation = mirrorPosition.allocationPuppetMap(allocationAddress, puppet3);

        uint netAllocationFromMirror = mirrorPosition.getAllocation(allocationAddress);
        assertEq(netAllocationFromMirror, 29e6);
        assertEq(puppet1Allocation + puppet2Allocation + puppet3Allocation, initialGrossTotalAllocation);

        uint puppet1BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet3);

        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationAddress);

        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.collateralDelta = currentPos.traderCollateral;
        callClose.sizeDeltaInUsd = currentPos.traderSize;
        callClose.isIncrease = false;

        bytes32 closeKey =
            mirrorPosition.requestAdjust{value: callClose.executionFee}(callClose, puppetList, allocationId);

        uint netAllocatedForPnL = netAllocationFromMirror - callClose.keeperExecutionFee;

        uint settledAmount = Math.mulDiv(netAllocatedForPnL, 80, 100);
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey);

        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
        mirrorPosition.settle(feeMarketplace, callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        uint puppet1ShareOfAdjustFee =
            Math.mulDiv(callClose.keeperExecutionFee, puppet1Allocation, initialGrossTotalAllocation);
        uint puppet2ShareOfAdjustFee =
            Math.mulDiv(callClose.keeperExecutionFee, puppet2Allocation, initialGrossTotalAllocation);
        uint puppet3ShareOfAdjustFee =
            Math.mulDiv(callClose.keeperExecutionFee, puppet3Allocation, initialGrossTotalAllocation);
        uint puppet1BalanceAfterAdjust = puppet1BalanceAfterMirror - puppet1ShareOfAdjustFee;
        uint puppet2BalanceAfterAdjust = puppet2BalanceAfterMirror - puppet2ShareOfAdjustFee;
        uint puppet3BalanceAfterAdjust = puppet3BalanceAfterMirror - puppet3ShareOfAdjustFee;

        uint amountForFeeCalc =
            settledAmount > callSettle.keeperExecutionFee ? settledAmount - callSettle.keeperExecutionFee : 0;
        uint platformFeeCalculated = Precision.applyFactor(feeFactor, amountForFeeCalc);

        uint settlementDeductions = platformFeeCalculated + callSettle.keeperExecutionFee;
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0;

        uint puppet1ExpectedShare = Math.mulDiv(amountDistributed, puppet1Allocation, initialGrossTotalAllocation);
        uint puppet2ExpectedShare = Math.mulDiv(amountDistributed, puppet2Allocation, initialGrossTotalAllocation);
        uint puppet3ExpectedShare = Math.mulDiv(amountDistributed, puppet3Allocation, initialGrossTotalAllocation);

        uint puppet1ExpectedFinalBalance = puppet1BalanceAfterAdjust + puppet1ExpectedShare;
        uint puppet2ExpectedFinalBalance = puppet2BalanceAfterAdjust + puppet2ExpectedShare;
        uint puppet3ExpectedFinalBalance = puppet3BalanceAfterAdjust + puppet3ExpectedShare;

        assertApproxEqAbs(
            puppet1BalanceAfterSettle, puppet1ExpectedFinalBalance, 1000000, "Puppet1 final balance mismatch"
        );
        assertApproxEqAbs(
            puppet2BalanceAfterSettle, puppet2ExpectedFinalBalance, 1000000, "Puppet2 final balance mismatch"
        );
        assertApproxEqAbs(
            puppet3BalanceAfterSettle, puppet3ExpectedFinalBalance, 1000000, "Puppet3 final balance mismatch"
        );
    }

    function testZeroCollateralAdjustments() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        uint allocationId = getNextAllocationId();
        (address allocationAddress, bytes32 openRequestKey) =
            mirrorPosition.requestMirror{value: callOpen.executionFee}(matchingRule, callOpen, puppetList, allocationId);
        mirrorPosition.execute(openRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationAddress);

        assertGt(pos1.size, 0, "Pos1 initial size should be > 0");

        MirrorPosition.CallPosition memory zeroCollateralIncreaseParams = defaultCallPosition;
        zeroCollateralIncreaseParams.collateralDelta = 0;
        zeroCollateralIncreaseParams.sizeDeltaInUsd = 500e30;
        zeroCollateralIncreaseParams.keeperExecutionFee = 0.5e6;

        uint expectedTraderSize2 = pos1.traderSize + zeroCollateralIncreaseParams.sizeDeltaInUsd;
        uint expectedTraderCollat2 = pos1.traderCollateral;

        bytes32 zeroCollateralRequestKey = mirrorPosition.requestAdjust{
            value: zeroCollateralIncreaseParams.executionFee
        }(zeroCollateralIncreaseParams, puppetList, allocationId);
        mirrorPosition.execute(zeroCollateralRequestKey);
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationAddress);

        assertEq(pos2.traderSize, expectedTraderSize2, "ZeroCollat: TSize mismatch");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "ZeroCollat: TCollat mismatch");

        uint finalNetAllocation = mirrorPosition.getAllocation(allocationAddress);
        uint finalMirrorLeverageBP = Precision.toBasisPoints(pos2.size, finalNetAllocation);

        uint finalTraderLeverageBP = Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral);

        assertApproxEqAbs(
            finalMirrorLeverageBP, finalTraderLeverageBP, LEVERAGE_TOLERANCE_BP, "ZeroCollat: Leverage mismatch"
        );
    }

    function testCollectDust() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        (address allocationAddress,) =
            mirrorPosition.requestMirror{value: callOpen.executionFee}(matchingRule, callOpen, puppetList, getNextAllocationId());

        uint dustAmount = 0.002e6;
        deal(address(usdc), allocationAddress, dustAmount);

        uint receiverBalanceBefore = usdc.balanceOf(users.alice);
        uint allocationBalanceBefore = usdc.balanceOf(allocationAddress);
        assertEq(allocationBalanceBefore, dustAmount, "Allocation account should have dust");

        address receiver = users.alice;
        mirrorPosition.collectDust(AllocationAccount(allocationAddress), usdc, receiver);

        uint receiverBalanceAfter = usdc.balanceOf(users.alice);
        uint allocationBalanceAfter = usdc.balanceOf(allocationAddress);

        assertEq(receiverBalanceAfter, receiverBalanceBefore + dustAmount, "Receiver should get dust amount");
        assertEq(allocationBalanceAfter, 0, "Allocation account should have no dust left");
    }

    function testAccessControlForCriticalFunctions() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 1);

        MirrorPosition.CallPosition memory callMirror = defaultCallPosition;

        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.requestMirror{value: callMirror.executionFee}(matchingRule, callMirror, puppetList, getNextAllocationId());
        vm.stopPrank();

        bytes32 traderMatchingKey = PositionUtils.getTraderMatchingKey(usdc, trader);
        vm.prank(users.owner);
        uint allocationId = getNextAllocationId();
        (address allocationAddress, bytes32 requestKey) =
            mirrorPosition.requestMirror{value: callMirror.executionFee}(matchingRule, callMirror, puppetList, allocationId);

        vm.stopPrank();

        MirrorPosition.CallPosition memory callAdjust = defaultCallPosition;
        callAdjust.collateralDelta = 10e6;
        callAdjust.sizeDeltaInUsd = 100e30;
        callAdjust.isIncrease = false;

        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.requestAdjust{value: callAdjust.executionFee}(callAdjust, puppetList, allocationId);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.execute(requestKey);
        vm.stopPrank();

        vm.prank(users.owner);
        mirrorPosition.execute(requestKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationAddress);

        MirrorPosition.CallPosition memory callClose = defaultCallPosition;
        callClose.collateralDelta = currentPos.traderCollateral;
        callClose.sizeDeltaInUsd = currentPos.traderSize;
        callClose.isIncrease = false;

        bytes32 closeKey =
            mirrorPosition.requestAdjust{value: callClose.executionFee}(callClose, puppetList, allocationId);
        mirrorPosition.execute(closeKey);

        deal(address(usdc), allocationAddress, 10e6);
        vm.stopPrank();

        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.settle(feeMarketplace, callSettle, puppetList);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(users.owner);
        mirrorPosition.initializeTraderActivityThrottle(traderMatchingKey, puppetList[0]);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.initializeTraderActivityThrottle(traderMatchingKey, puppetList[0]);
        vm.stopPrank();
    }

    function _calculateExpectedInitialMirrorSize(
        uint _traderSizeDeltaUsd,
        uint _traderCollateralDelta,
        uint _initialGrossTotalAllocated,
        uint _executionFee
    ) internal pure returns (uint initialSize) {
        require(_traderCollateralDelta > 0, "Initial trader collat > 0");
        require(_traderSizeDeltaUsd > 0, "Initial trader size > 0");
        require(_initialGrossTotalAllocated > _executionFee, "Gross allocation must cover fee");
        uint _netAllocated = _initialGrossTotalAllocated - _executionFee;

        return _traderSizeDeltaUsd * _netAllocated / _traderCollateralDelta;
    }

    function _createPuppet(
        MockERC20 collateralToken,
        address trader,
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        collateralToken.mint(user, fundValue);

        vm.startPrank(user);
        collateralToken.approve(address(tokenRouter), type(uint).max);

        vm.startPrank(users.owner);
        matchingRule.deposit(collateralToken, user, user, fundValue);

        matchingRule.setRule(
            mirrorPosition,
            collateralToken,
            user,
            trader,
            MatchingRule.Rule({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 2 days})
        );

        return user;
    }

    function _getAllocationKey(
        address[] memory _puppetList,
        bytes32 _traderMatchingKey,
        uint _allocationId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_puppetList, _traderMatchingKey, _allocationId));
    }

    function _getSettleFeeFactor() internal view returns (uint) {
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
            puppetList[i] = _createPuppet(collateralToken, trader, puppetNameLabel, 100e6);
        }

        return puppetList;
    }
}
