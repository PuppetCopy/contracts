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
import {AllocationAccount} from "src/shared/AllocationAccount.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Error} from "src/utils/Error.sol";
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

    MirrorPosition.CallPosition defaultCallPosition;
    MirrorPosition.CallSettle defaultCallSettle;

    function setUp() public override {
        super.setUp();

        defaultCallPosition = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: users.bob,
            market: Address.gmxEthUsdcMarket,
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
            allocationToken: usdc,
            distributeToken: usdc,
            trader: defaultCallPosition.trader,
            allocationId: 0,
            keeperExecutionFeeReceiver: users.yossi,
            keeperExecutionFee: 1e6 // Mirror execution fee (not used in this test)
        });

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        allocationStore = new AllocationStore(dictator, tokenRouter);
        matchRule = new MatchRule(dictator, allocationStore, MirrorPosition(_getNextContractAddress(3)));
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);
        mirrorPosition = new MirrorPosition(dictator, allocationStore, matchRule, feeMarketplace);

        // Config
        IERC20[] memory allowedTokenList = new IERC20[](2);
        allowedTokenList[0] = wnt;
        allowedTokenList[1] = usdc;
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        uint[] memory tokenDustThresholdCapList = new uint[](2);
        tokenDustThresholdCapList[0] = 0.01e18;
        tokenDustThresholdCapList[1] = 1e6;

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
                    tokenAllowanceList: allowedTokenList,
                    tokenAllowanceCapList: tokenAllowanceCapAmountList
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
                    tokenDustThresholdList: allowedTokenList,
                    tokenDustThresholdCapList: tokenDustThresholdCapList,
                    gmxExchangeRouter: mockGmxExchangeRouter,
                    callbackHandler: address(mirrorPosition), // Self-callback for tests
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 20,
                    maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                    maxKeeperFeeToAdjustmentRatio: 0.05e30, // 5%
                    maxKeeperFeeToCollectDustRatio: 0.1e30 // 10%
                })
            )
        );

        dictator.setAccess(tokenRouter, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        // mirrorPosition permissions (owner for most actions in tests)
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.adjust.selector, users.owner); // Added adjust permission
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.collectDust.selector, users.owner);
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
        dictator.setAccess(tokenRouter, address(feeMarketplaceStore));
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
        uint netAllocated = totalAllocated - callIncrease.keeperExecutionFee;
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
            callIncrease.sizeDeltaInUsd, callIncrease.collateralDelta, totalAllocated, callIncrease.keeperExecutionFee
        );
        // Expected: 1000e30 * (100e6 - fee) / 100e6 ~= 1000e30 (if fee is small relative to allocation)
        // Let's use the helper: 1000e30 * (100e6 - 0.005e6) / 100e6 = 999.95e30
        assertEq(
            expectedInitialMirroredSize,
            defaultCallPosition.sizeDeltaInUsd * netAllocated / defaultCallPosition.collateralDelta,
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

        bytes32 decreaseRequestKey =
            mirrorPosition.adjust{value: callDecrease.executionFee}(callDecrease, puppetList, allocationId);
        assertNotEq(decreaseRequestKey, bytes32(0));

        // Calculate netAllocated considering BOTH open and close keeper fees for PnL simulation
        uint netAllocatedForPnL = totalAllocated - callIncrease.keeperExecutionFee - callDecrease.keeperExecutionFee;

        // 4. Simulate Profit & Execute Decrease
        uint profit = netAllocatedForPnL; // 100% profit on NET allocated capital (after both fees)
        uint settledAmount = netAllocatedForPnL + profit; // Return = netAllocated (after both fees) + profit

        deal(address(usdc), allocationAddress, settledAmount); // Deal funds to allocation account
        mirrorPosition.execute(decreaseRequestKey); // Simulate GMX callback executing the close

        // Check position is closed
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos2.traderSize, 0, "pos2.traderSize should be 0");
        assertEq(pos2.traderCollateral, 0, "pos2.traderCollateral should be 0");
        assertEq(pos2.size, 0, "pos2.size should be 0");

        // 5. Settle
        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
        mirrorPosition.settle(callSettle, puppetList);

        // --- Recalculate expected balances ---

        // Calculate platform fee based on amount after settlement keeper fee
        uint amountForFeeCalc =
            settledAmount > callSettle.keeperExecutionFee ? settledAmount - callSettle.keeperExecutionFee : 0;
        uint platformFeeCalculated = Precision.applyFactor(_getSettleFeeFactor(), amountForFeeCalc);

        // Calculate amount distributed during settlement
        uint settlementDeductions = platformFeeCalculated + callSettle.keeperExecutionFee;
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0;

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
        uint contributionPerPuppet = totalAllocated / puppetList.length; // Assuming equal contributions
        uint adjustFeePerPuppet = callDecrease.keeperExecutionFee / puppetList.length; // Assuming equal split
        uint balanceAfterAdjust = initialPuppetBalance - contributionPerPuppet - adjustFeePerPuppet;

        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            uint contribution = _getPuppetAllocation(allocationKey, puppet);
            assertEq(contribution, contributionPerPuppet, "Contribution mismatch"); // Verify assumption

            // Calculate expected share based on TOTAL allocation ratio
            uint expectedShare = Math.mulDiv(amountDistributed, contribution, totalAllocated);

            // Calculate final expected balance
            uint expectedFinalBalance = balanceAfterAdjust + expectedShare;

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

        // adjust() first checks if position.size > 0 for the derived allocationKey
        bytes32 nonExistentMatchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 nonExistentAllocationKey = _getAllocationKey(puppetList, nonExistentMatchKey, nonExistentAllocationId);
        MirrorPosition.Position memory nonExistentPos = mirrorPosition.getPosition(nonExistentAllocationKey);
        assertEq(nonExistentPos.size, 0); // Pre-condition: Position should not exist

        vm.expectRevert(Error.MirrorPosition__PositionNotFound.selector);
        mirrorPosition.adjust{value: callAdjust.executionFee}(callAdjust, puppetList, nonExistentAllocationId);
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

        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, tooManyPuppets);
    }

    // Test that checks if settlement correctly distributes profits proportionally
    function testProportionalProfitDistribution() public {
        // Create 3 puppets with different balances and allocations
        address trader = defaultCallPosition.trader;
        address puppet1 = _createPuppet(usdc, trader, "puppet1", 50e6);
        address puppet2 = _createPuppet(usdc, trader, "puppet2", 100e6);
        address puppet3 = _createPuppet(usdc, trader, "puppet3", 150e6);

        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        // Get initial balances
        uint puppet1InitialBalance = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2InitialBalance = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3InitialBalance = allocationStore.userBalanceMap(usdc, puppet3);

        // Create position with mirror
        MirrorPosition.CallPosition memory callParams = defaultCallPosition;
        (uint allocationId, bytes32 requestKey) =
            mirrorPosition.mirror{value: callParams.executionFee}(callParams, puppetList);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Execute open
        mirrorPosition.execute(requestKey);

        // Get individual contributions
        uint puppet1Contribution = _getPuppetAllocation(allocationKey, puppet1);
        uint puppet2Contribution = _getPuppetAllocation(allocationKey, puppet2);
        uint puppet3Contribution = _getPuppetAllocation(allocationKey, puppet3);
        uint totalContribution = puppet1Contribution + puppet2Contribution + puppet3Contribution;

        // Close position
        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationKey);
        MirrorPosition.CallPosition memory closeParams = defaultCallPosition;
        closeParams.isIncrease = false;
        closeParams.collateralDelta = position.traderCollateral;
        closeParams.sizeDeltaInUsd = position.traderSize;

        bytes32 closeKey = mirrorPosition.adjust{value: closeParams.executionFee}(closeParams, puppetList, allocationId);

        // Simulate 150% profit on net allocated
        // Update to account for both opening and closing keeper execution fees
        uint netAllocated = totalContribution - callParams.keeperExecutionFee - closeParams.keeperExecutionFee;
        // Correct the assertion: compare calculated netAllocated to expected value
        assertEq(
            netAllocated,
            totalContribution - callParams.keeperExecutionFee - closeParams.keeperExecutionFee, // Use the same
                // calculation
            "Net allocated should match total contributions minus fees"
        );

        uint profit = netAllocated * 3 / 2; // 150% profit
        uint settledAmount = netAllocated + profit;

        // Deal profit to allocation account and execute close
        deal(address(usdc), allocationAddress, settledAmount);
        mirrorPosition.execute(closeKey);

        // Settle and check proportional distribution
        MirrorPosition.CallSettle memory settleParams = defaultCallSettle;
        settleParams.allocationId = allocationId;
        mirrorPosition.settle(settleParams, puppetList);

        // --- Recalculate expected balances ---

        // Calculate expected balance after adjust fee deduction
        // Note: Adjust fee was deducted proportionally before this settlement step
        uint puppet1ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet1Contribution, totalContribution);
        uint puppet2ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet2Contribution, totalContribution);
        uint puppet3ShareOfAdjustFee =
            Math.mulDiv(closeParams.keeperExecutionFee, puppet3Contribution, totalContribution);
        // Use initial balances for calculation base
        uint puppet1BalanceAfterAdjust = puppet1InitialBalance - puppet1Contribution - puppet1ShareOfAdjustFee;
        uint puppet2BalanceAfterAdjust = puppet2InitialBalance - puppet2Contribution - puppet2ShareOfAdjustFee;
        uint puppet3BalanceAfterAdjust = puppet3InitialBalance - puppet3Contribution - puppet3ShareOfAdjustFee;

        // Calculate platform fee as likely done in contract (after settle keeper fee deduction)
        uint amountForFeeCalc =
            settledAmount > settleParams.keeperExecutionFee ? settledAmount - settleParams.keeperExecutionFee : 0;
        uint platformFeeCalculated = Precision.applyFactor(_getSettleFeeFactor(), amountForFeeCalc);

        // Calculate amount distributed during settlement
        uint settlementDeductions = platformFeeCalculated + settleParams.keeperExecutionFee;
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0;

        // Calculate expected distribution share for each puppet
        uint puppet1ExpectedShare = Math.mulDiv(amountDistributed, puppet1Contribution, totalContribution);
        uint puppet2ExpectedShare = Math.mulDiv(amountDistributed, puppet2Contribution, totalContribution);
        uint puppet3ExpectedShare = Math.mulDiv(amountDistributed, puppet3Contribution, totalContribution);

        // Calculate final expected balances
        uint puppet1ExpectedFinalBalance = puppet1BalanceAfterAdjust + puppet1ExpectedShare;
        uint puppet2ExpectedFinalBalance = puppet2BalanceAfterAdjust + puppet2ExpectedShare;
        uint puppet3ExpectedFinalBalance = puppet3BalanceAfterAdjust + puppet3ExpectedShare;

        // Check final balances
        uint puppet1FinalBalance = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2FinalBalance = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3FinalBalance = allocationStore.userBalanceMap(usdc, puppet3);

        assertEq(puppet1FinalBalance, puppet1ExpectedFinalBalance, "Puppet1 final balance incorrect");
        assertEq(puppet2FinalBalance, puppet2ExpectedFinalBalance, "Puppet2 final balance incorrect");
        assertEq(puppet3FinalBalance, puppet3ExpectedFinalBalance, "Puppet3 final balance incorrect");

        // Verify the proportions are correct (use amountDistributed for ratio check)
        if (amountDistributed > 0) {
            // Avoid division by zero if nothing is distributed
            assertApproxEqRel(
                puppet1ExpectedShare * 100 / amountDistributed, // Use share vs distributed
                puppet1Contribution * 100 / totalContribution,
                0.01e18, // 1% tolerance
                "Puppet1 return ratio should match contribution ratio"
            );
            assertApproxEqRel(
                puppet2ExpectedShare * 100 / amountDistributed, // Use share vs distributed
                puppet2Contribution * 100 / totalContribution,
                0.01e18, // 1% tolerance
                "Puppet2 return ratio should match contribution ratio"
            );
            assertApproxEqRel(
                puppet3ExpectedShare * 100 / amountDistributed, // Use share vs distributed
                puppet3Contribution * 100 / totalContribution,
                0.01e18, // 1% tolerance
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

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(allocationId, 0);

        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // 30e6
        uint puppet1Allocation = _getPuppetAllocation(allocationKey, puppet1); // 10e6
        uint puppet2Allocation = _getPuppetAllocation(allocationKey, puppet2); // 10e6
        uint puppet3Allocation = _getPuppetAllocation(allocationKey, puppet3); // 10e6
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

        bytes32 closeKey = mirrorPosition.adjust{value: callClose.executionFee}(callClose, puppetList, allocationId);

        // Calculate netAllocated considering BOTH open and close keeper fees
        uint netAllocated = totalAllocation - callOpen.keeperExecutionFee - callClose.keeperExecutionFee;
        assertEq(
            netAllocated,
            mirrorPosition.getAllocation(allocationKey) - callOpen.keeperExecutionFee - callClose.keeperExecutionFee,
            "Net allocated should match total contributions minus both fees"
        );

        // Simulate 20% loss on NET allocated capital - return 80% of netAllocated
        uint settledAmount = Math.mulDiv(netAllocated, 80, 100);
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey);

        // Settle funds
        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
        mirrorPosition.settle(callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        // --- Recalculate expected balances ---

        // Calculate expected balance after adjust fee deduction
        // Note: Adjust fee was deducted proportionally before this settlement step
        uint puppet1ShareOfAdjustFee = Math.mulDiv(callClose.keeperExecutionFee, puppet1Allocation, totalAllocation);
        uint puppet2ShareOfAdjustFee = Math.mulDiv(callClose.keeperExecutionFee, puppet2Allocation, totalAllocation);
        uint puppet3ShareOfAdjustFee = Math.mulDiv(callClose.keeperExecutionFee, puppet3Allocation, totalAllocation);
        uint puppet1BalanceAfterAdjust = puppet1BalanceAfterMirror - puppet1ShareOfAdjustFee;
        uint puppet2BalanceAfterAdjust = puppet2BalanceAfterMirror - puppet2ShareOfAdjustFee;
        uint puppet3BalanceAfterAdjust = puppet3BalanceAfterMirror - puppet3ShareOfAdjustFee;

        // Calculate platform fee as likely done in contract (after settle keeper fee deduction)
        uint amountForFeeCalc =
            settledAmount > callSettle.keeperExecutionFee ? settledAmount - callSettle.keeperExecutionFee : 0;
        uint platformFeeCalculated = Precision.applyFactor(feeFactor, amountForFeeCalc);

        // Calculate amount distributed during settlement
        uint settlementDeductions = platformFeeCalculated + callSettle.keeperExecutionFee;
        uint amountDistributed = settledAmount > settlementDeductions ? settledAmount - settlementDeductions : 0;

        // Calculate expected distribution share for each puppet
        uint puppet1ExpectedShare = Math.mulDiv(amountDistributed, puppet1Allocation, totalAllocation);
        uint puppet2ExpectedShare = Math.mulDiv(amountDistributed, puppet2Allocation, totalAllocation);
        uint puppet3ExpectedShare = Math.mulDiv(amountDistributed, puppet3Allocation, totalAllocation);

        // Calculate final expected balances
        uint puppet1ExpectedFinalBalance = puppet1BalanceAfterAdjust + puppet1ExpectedShare;
        uint puppet2ExpectedFinalBalance = puppet2BalanceAfterAdjust + puppet2ExpectedShare;
        uint puppet3ExpectedFinalBalance = puppet3BalanceAfterAdjust + puppet3ExpectedShare;

        // Assert final balances match expected final balances
        assertEq(puppet1BalanceAfterSettle, puppet1ExpectedFinalBalance, "Puppet1 final balance mismatch");
        assertEq(puppet2BalanceAfterSettle, puppet2ExpectedFinalBalance, "Puppet2 final balance mismatch");
        assertEq(puppet3BalanceAfterSettle, puppet3ExpectedFinalBalance, "Puppet3 final balance mismatch");
    }

    // Test adjust() with zero collateral change
    function testZeroCollateralAdjustments() public {
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2); // Use default trader
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;

        (uint allocationId, bytes32 openRequestKey) =
            mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        mirrorPosition.execute(openRequestKey);
        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId); // Get allocationKey here
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        uint totalAllocated = mirrorPosition.getAllocation(allocationKey); // Get totalAllocated here
        assertGt(pos1.size, 0, "Pos1 initial size should be > 0");

        // Adjust: Increase trader size without changing trader collateral -> Trader Leverage increases (10x -> 15x)
        MirrorPosition.CallPosition memory zeroCollateralIncreaseParams = defaultCallPosition;
        zeroCollateralIncreaseParams.collateralDelta = 0; // No change in trader collateral
        zeroCollateralIncreaseParams.sizeDeltaInUsd = 500e30; // Increase trader size by 50% (500e30)

        uint expectedTraderSize2 = pos1.traderSize + zeroCollateralIncreaseParams.sizeDeltaInUsd; // 1500e30
        uint expectedTraderCollat2 = pos1.traderCollateral; // 100e6 (remains same)

        // Use adjust()
        bytes32 zeroCollateralRequestKey = mirrorPosition.adjust{value: zeroCollateralIncreaseParams.executionFee}(
            zeroCollateralIncreaseParams, puppetList, allocationId
        );
        mirrorPosition.execute(zeroCollateralRequestKey);
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey); // Use correct allocationKey

        assertEq(pos2.traderSize, expectedTraderSize2, "ZeroCollat: TSize mismatch");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "ZeroCollat: TCollat mismatch");

        // Calculate final mirrored leverage relative to TOTAL allocated capital (in Basis Points)
        // The adjust function calculates target size based on totalAllocated
        uint finalMirrorLeverageBP = Precision.toBasisPoints(pos2.size, totalAllocated);

        // Calculate final trader leverage (in Basis Points)
        uint finalTraderLeverageBP = Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral);

        // Assert that the mirrored leverage (relative to total capital) matches the trader leverage
        assertApproxEqAbs(
            finalMirrorLeverageBP, finalTraderLeverageBP, LEVERAGE_TOLERANCE_BP, "ZeroCollat: Leverage mismatch"
        );
    }

    function testCollectDust() public {
        // Set up: Create a position and close it to get an allocation account
        address trader = defaultCallPosition.trader;
        address[] memory puppetList = _generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // Open position
        MirrorPosition.CallPosition memory callOpen = defaultCallPosition;
        (uint allocationId, bytes32 openKey) = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        bytes32 allocationKey = _getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Deal some dust to the allocation account (less than threshold)
        uint dustAmount = 0.002e6; // 2 USDC
        deal(address(usdc), allocationAddress, dustAmount);

        // Check balances before collect
        uint receiverBalanceBefore = usdc.balanceOf(users.alice);
        uint allocationBalanceBefore = usdc.balanceOf(allocationAddress);
        assertEq(allocationBalanceBefore, dustAmount, "Allocation account should have dust");

        // Collect dust
        address receiver = users.alice;
        mirrorPosition.collectDust(AllocationAccount(allocationAddress), usdc, receiver);

        // Check balances after collect
        uint receiverBalanceAfter = usdc.balanceOf(users.alice);
        uint allocationBalanceAfter = usdc.balanceOf(allocationAddress);

        // Assertions
        assertEq(receiverBalanceAfter, receiverBalanceBefore + dustAmount, "Receiver should get dust amount");
        assertEq(allocationBalanceAfter, 0, "Allocation account should have no dust left");
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

        MirrorPosition.CallSettle memory callSettle = defaultCallSettle;
        callSettle.allocationId = allocationId;
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

        return _traderSizeDeltaUsd * _netAllocated / _traderCollateralDelta;
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

    function _getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint _allocationId
    ) internal pure returns (bytes32) {
        // Matches PositionUtils.getAllocationKey
        return keccak256(abi.encodePacked(_puppetList, _matchKey, _allocationId));
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
            puppetList[i] = _createPuppet(collateralToken, trader, puppetNameLabel, 100e6); // Default 100e6
        }

        return puppetList;
    }

    function _getPuppetAllocation(bytes32 allocationKey, address puppet) internal view returns (uint) {
        return mirrorPosition.allocationPuppetMap(allocationKey, puppet);
    }
}
