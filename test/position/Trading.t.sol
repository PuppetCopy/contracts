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

    uint internal constant defaultExecutionFee = 5_000_000 * 1 gwei; // Example fixed fee
    address internal constant defaultTrader = address(0xBAD); // Example trader address
    address internal constant defaultMarket = Address.gmxEthUsdcMarket;
    uint internal constant defaultCollateralDelta = 100e6; // 100 USDC
    uint internal constant defaultSizeDeltaInUsd = 1000e30; // 1000 USD (10x leverage implied)
    uint internal constant LEVERAGE_TOLERANCE_BP = 5; // Use slightly larger tolerance for e30 math

    function setUp() public override {
        super.setUp();

        // Use a constant address for the default trader
        vm.label(defaultTrader, "DefaultTrader");

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        // Deploy core contracts
        allocationStore = new AllocationStore(dictator, tokenRouter);
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
                    burnBasisPoints: 10000, // Example: 100% burn, adjust as needed
                    feeDistributor: BankStore(address(0)) // Example: No distributor
                })
            )
        );

        dictator.initContract(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: mockGmxExchangeRouter,
                    callbackHandler: address(mirrorPosition), // Assuming self-callback for tests
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 20,
                    minExecutionCostFactor: 0.1e30 // 10% (Unused in these tests but part of config)
                })
            )
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        // Set permissions
        dictator.setPermission(mirrorPosition, mirrorPosition.allocate.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
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
        dictator.setAccess(allocationStore, address(feeMarketplaceStore)); // FeeMarketplaceStore needs access to pull
            // funds
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore)); // For
            // deposit/pull
        feeMarketplace.setAskPrice(usdc, 100e18); // Example price

        // Ensure owner has permissions to act on behalf of users
        dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);

        // Pre-approve token allowances for puppet creation helper
        vm.startPrank(users.alice); // Example user for createPuppet
        usdc.approve(address(tokenRouter), type(uint).max);
        wnt.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();

        // Also approve for defaultTrader if it's used directly
        vm.startPrank(defaultTrader);
        usdc.approve(address(tokenRouter), type(uint).max);
        wnt.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();

        vm.startPrank(users.owner);
    }

    function testSettlementMultipleTokens() public {
        // 1. Setup
        address trader = defaultTrader;
        MockERC20 allocationCollateral = usdc;
        MockERC20 secondaryToken = wnt;
        uint feeFactor = getPlatformSettleFeeFactor(); // Get from config

        // Create puppets funded with primary collateral
        uint puppet1InitialBalance = 100e6;
        uint puppet2InitialBalance = 200e6;
        // Use users.alice as the puppet owner for deposit permissions
        address puppet1 =
            createPuppet(allocationCollateral, users.alice, trader, "multiTokenPuppet1", puppet1InitialBalance);
        address puppet2 =
            createPuppet(allocationCollateral, users.alice, trader, "multiTokenPuppet2", puppet2InitialBalance);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // 2. Allocate (using primary collateral)
        MirrorPosition.CallAllocation memory callAlloc = MirrorPosition.CallAllocation({
            collateralToken: allocationCollateral,
            trader: trader,
            platformExecutionFee: 0 // Not relevant for allocate itself
        });
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 matchKey = PositionUtils.getMatchKey(allocationCollateral, trader);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint puppet1Allocation = allocationPuppetMap(allocationKey, puppet1); // Expected 10e6 (10% of 100e6)
        uint puppet2Allocation = allocationPuppetMap(allocationKey, puppet2); // Expected 20e6 (10% of 200e6)
        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // Expected 30e6
        assertEq(totalAllocation, 30e6, "Total allocation mismatch");
        assertEq(totalAllocation, puppet1Allocation + puppet2Allocation, "Sum check mismatch");

        // 3. Simulate Position Lifecycle (Open & Close) - Simplified
        MirrorPosition.CallPosition memory callOpen = MirrorPosition.CallPosition({
            collateralToken: allocationCollateral,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta, // Trader's initial collateral
            sizeDeltaInUsd: defaultSizeDeltaInUsd, // Trader's initial size
            acceptablePrice: 0, // Market order
            triggerPrice: 0, // Market order
            allocationId: allocationId
        });
        bytes32 openKey = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        mirrorPosition.execute(openKey);

        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);

        MirrorPosition.CallPosition memory callClose = MirrorPosition.CallPosition({
            collateralToken: allocationCollateral,
            trader: trader,
            market: defaultMarket,
            isIncrease: false, // Decrease
            isLong: true, // Must match original position direction
            executionFee: defaultExecutionFee,
            collateralDelta: currentPos.traderCollateral, // Close full trader collateral
            sizeDeltaInUsd: currentPos.traderSize, // Close full trader size
            acceptablePrice: 0, // Market order
            triggerPrice: 0, // Market order
            allocationId: allocationId
        });
        bytes32 closeKey = mirrorPosition.mirror{value: callClose.executionFee}(callClose, puppetList);
        mirrorPosition.execute(closeKey); // Position closed in MirrorPosition state

        // 4. Simulate Receiving Multiple Tokens in AllocationAccount
        uint usdcProfit = totalAllocation / 2; // 15e6 USDC profit (50%)
        uint usdcSettledAmount = totalAllocation + usdcProfit; // 30e6 + 15e6 = 45e6 USDC
        uint wethSettledAmount = 0.1e18; // Simulate 0.1 WETH received

        deal(address(allocationCollateral), allocationAddress, usdcSettledAmount);
        deal(address(secondaryToken), allocationAddress, wethSettledAmount);
        assertEq(allocationCollateral.balanceOf(allocationAddress), usdcSettledAmount, "Deal USDC failed");
        assertEq(secondaryToken.balanceOf(allocationAddress), wethSettledAmount, "Deal WETH failed");

        // 5. Record Balances Before Settlement
        uint p1USDC_Before = allocationStore.userBalanceMap(allocationCollateral, puppet1);
        uint p2USDC_Before = allocationStore.userBalanceMap(allocationCollateral, puppet2);
        uint p1WETH_Before = allocationStore.userBalanceMap(secondaryToken, puppet1);
        uint p2WETH_Before = allocationStore.userBalanceMap(secondaryToken, puppet2);
        uint feeStoreUSDC_Before = allocationCollateral.balanceOf(address(feeMarketplaceStore));
        uint feeStoreWETH_Before = secondaryToken.balanceOf(address(feeMarketplaceStore));

        // 6. Settle USDC
        MirrorPosition.CallSettle memory settleUSDC = MirrorPosition.CallSettle({
            allocationToken: allocationCollateral, // Token used for original allocation ratios
            distributeToken: allocationCollateral, // Token being distributed now
            trader: trader,
            allocationId: allocationId
        });
        mirrorPosition.settle(settleUSDC, puppetList);

        // 7. Verify USDC Settlement
        assertEq(allocationCollateral.balanceOf(allocationAddress), 0, "USDC not cleared from AllocAccount");
        uint usdcPlatformFee = Precision.applyFactor(feeFactor, usdcSettledAmount); // 10% of 45e6 = 4.5e6
        uint usdcAmountDistributed = usdcSettledAmount - usdcPlatformFee; // 40.5e6
        uint p1ExpectedUSDCShare = Math.mulDiv(usdcAmountDistributed, puppet1Allocation, totalAllocation); // 40.5 * 10
            // / 30 = 13.5e6
        uint p2ExpectedUSDCShare = Math.mulDiv(usdcAmountDistributed, puppet2Allocation, totalAllocation); // 40.5 * 20
            // / 30 = 27.0e6

        uint p1USDC_After = allocationStore.userBalanceMap(allocationCollateral, puppet1);
        uint p2USDC_After = allocationStore.userBalanceMap(allocationCollateral, puppet2);
        uint feeStoreUSDC_After = allocationCollateral.balanceOf(address(feeMarketplaceStore));

        assertEq(p1USDC_After - p1USDC_Before, p1ExpectedUSDCShare, "Puppet1 USDC share mismatch");
        assertEq(p2USDC_After - p2USDC_Before, p2ExpectedUSDCShare, "Puppet2 USDC share mismatch");
        assertEq(feeStoreUSDC_After - feeStoreUSDC_Before, usdcPlatformFee, "FeeStore USDC mismatch");

        // 8. Settle WETH
        MirrorPosition.CallSettle memory settleWETH = MirrorPosition.CallSettle({
            allocationToken: allocationCollateral, // STILL use the original allocation token basis
            distributeToken: secondaryToken, // Distributing WETH now
            trader: trader,
            allocationId: allocationId
        });
        mirrorPosition.settle(settleWETH, puppetList);

        // 9. Verify WETH Settlement
        assertEq(secondaryToken.balanceOf(allocationAddress), 0, "WETH not cleared from AllocAccount");
        uint wethPlatformFee = Precision.applyFactor(feeFactor, wethSettledAmount); // 10% of 0.1 = 0.01
        uint wethAmountDistributed = wethSettledAmount - wethPlatformFee; // 0.09 WETH

        // CRITICAL: Use the *original allocation ratio* (based on USDC contribution) to distribute WETH
        uint p1ExpectedWETHShare = Math.mulDiv(wethAmountDistributed, puppet1Allocation, totalAllocation); // 0.09 * 10
            // / 30 = 0.03e18
        uint p2ExpectedWETHShare = Math.mulDiv(wethAmountDistributed, puppet2Allocation, totalAllocation); // 0.09 * 20
            // / 30 = 0.06e18

        uint p1WETH_After = allocationStore.userBalanceMap(secondaryToken, puppet1);
        uint p2WETH_After = allocationStore.userBalanceMap(secondaryToken, puppet2);
        uint feeStoreWETH_After = secondaryToken.balanceOf(address(feeMarketplaceStore));

        assertEq(p1WETH_After - p1WETH_Before, p1ExpectedWETHShare, "Puppet1 WETH share mismatch");
        assertEq(p2WETH_After - p2WETH_Before, p2ExpectedWETHShare, "Puppet2 WETH share mismatch");
        assertEq(feeStoreWETH_After - feeStoreWETH_Before, wethPlatformFee, "FeeStore WETH mismatch");
    }

    // Calculates expected mirrored size delta based on leverage change, mirroring contract logic
    function calculateExpectedMirrorSizeDelta(
        MirrorPosition.Position memory _currentPosition, // Current state from getPosition
        uint _newTraderSize, // Target trader size after adjustment
        uint _newTraderCollateral, // Target trader collateral after adjustment
        uint _initialMirroredCollateral // The fixed netAllocated amount for the mirrored position
    ) internal pure returns (uint sizeDelta, bool isIncrease) {
        // Handle Initial Increase (contract logic: size = traderSize * allocated / traderCollateral)
        if (_currentPosition.size == 0) {
            // Requires trader collateral > 0 for initial increase as per contract check
            require(_newTraderCollateral > 0, "Initial trader collateral cannot be zero");
            // Requires trader size > 0 for initial increase as per contract check
            require(_newTraderSize > 0, "Initial trader size cannot be zero");
            // Calculate the initial mirrored size based on trader's initial leverage and the allocated mirror
            // collateral
            sizeDelta = Math.mulDiv(_newTraderSize, _initialMirroredCollateral, _newTraderCollateral);
            isIncrease = true;
            return (sizeDelta, isIncrease);
        }

        // Handle Adjustments or Close
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

    function testSimpleExecutionResult() public {
        uint initialPuppetBalance = 100e6; // Fund value used in generatePuppetList
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 10); // Generate 10 puppets for defaultTrader
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationStoreBalanceBefore = usdc.balanceOf(address(allocationStore));

        // 1. Allocate
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        uint netAllocated = mirrorPosition.getAllocation(allocationKey);
        // Expect 10 puppets * 100e6 balance * 10% rule = 100e6
        assertEq(netAllocated, 100e6, "Allocation should be 100e6");

        // 2. Mirror Increase
        MirrorPosition.CallPosition memory callIncrease = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta, // 100e6
            sizeDeltaInUsd: defaultSizeDeltaInUsd, // 1000e30
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: callIncrease.executionFee}(callIncrease, puppetList);
        assertNotEq(increaseRequestKey, bytes32(0));
        uint allocationStoreBalanceAfterMirror = allocationStoreBalanceBefore - netAllocated;
        assertEq(usdc.balanceOf(address(allocationStore)), allocationStoreBalanceAfterMirror);

        // 3. Execute Increase
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        // Initial trade: 100e6 collat, 1000e30 size. Mirror collat: 100e6 allocated.
        // Expected initial mirrored size: sizeDeltaUsd * netAllocated / collatDelta
        uint expectedInitialMirroredSize = Math.mulDiv(defaultSizeDeltaInUsd, netAllocated, defaultCollateralDelta); // 1000e30
            // * 100e6 / 100e6 = 1000e30
        assertEq(pos1.traderSize, defaultSizeDeltaInUsd, "pos1.traderSize");
        assertEq(pos1.traderCollateral, defaultCollateralDelta, "pos1.traderCollateral");
        assertEq(pos1.size, expectedInitialMirroredSize, "pos1.size mismatch"); // Mirrored size based on new calc

        // 4. Mirror Decrease (Full Close)
        MirrorPosition.CallPosition memory callDecrease = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false, // Decrease
            isLong: true, // Match direction
            executionFee: defaultExecutionFee,
            collateralDelta: pos1.traderCollateral, // Decrease by current trader collateral
            sizeDeltaInUsd: pos1.traderSize, // Decrease by current trader size
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: callDecrease.executionFee}(callDecrease, puppetList);
        assertNotEq(decreaseRequestKey, bytes32(0));

        // 5. Simulate Profit & Execute Decrease
        uint profit = 100e6; // 100 USDC profit (100% return on allocated capital)
        uint settledAmount = netAllocated + profit; // 100e6 + 100e6 = 200e6
        uint platformFee = Precision.applyFactor(getPlatformSettleFeeFactor(), settledAmount); // 10% of 200e6 = 20e6
        assertEq(platformFee, 20e6, "Platform fee calculation mismatch");
        deal(address(usdc), allocationAddress, settledAmount); // Deal funds to allocation account
        mirrorPosition.execute(decreaseRequestKey); // Simulate GMX callback executing the close

        // Check position is closed
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos2.traderSize, 0, "pos2.traderSize should be 0");
        assertEq(pos2.traderCollateral, 0, "pos2.traderCollateral should be 0");
        assertEq(pos2.size, 0, "pos2.size should be 0");

        // 6. Settle
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original allocation basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId
        });
        mirrorPosition.settle(callSettle, puppetList);

        // Check store balance has increased by settled amount minus fee
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            allocationStoreBalanceAfterMirror + settledAmount - platformFee,
            "Allocation store final balance mismatch"
        );

        // 7. Check puppet balances
        uint amountDistributed = settledAmount - platformFee; // 180e6
        uint totalContributionsCheck = 0;
        for (uint i = 0; i < puppetList.length; i++) {
            totalContributionsCheck += allocationPuppetMap(allocationKey, puppetList[i]);
        }
        assertEq(totalContributionsCheck, netAllocated, "Sanity check total contributions");

        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            uint contribution = allocationPuppetMap(allocationKey, puppetList[i]); // Should be 10e6 each (10% of 100e6)
            assertEq(
                contribution, 10e6, string(abi.encodePacked("Puppet ", Strings.toString(i), " contribution mismatch"))
            );
            // Calculate expected share: 180e6 distributed * 10e6 contribution / 100e6 total contribution = 18e6 share
            uint expectedShare = Math.mulDiv(amountDistributed, contribution, netAllocated);
            // Initial balance was 100e6, contributed 10e6, received 18e6 share
            uint expectedFinalBalance = initialPuppetBalance - contribution + expectedShare; // 100 - 10 + 18 = 108e6
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

    function testPositionDoesNotExistError() public {
        // Test calling mirror for a non-existent allocationId/puppetList combination
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 2); // Use the default trader
        uint nonExistentAllocationId = 99999; // An ID for which allocate was not called

        // Construct CallPosition with the invalid ID
        MirrorPosition.CallPosition memory callMirror = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta,
            sizeDeltaInUsd: defaultSizeDeltaInUsd,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: nonExistentAllocationId // Use the non-existent ID
        });

        // This mirror call should fail because the allocation account contract
        // for this specific allocationKey (derived from puppetList, matchKey, nonExistentAllocationId)
        // was never deployed (since allocate was never called for it).
        vm.expectRevert(Error.MirrorPosition__AllocationAccountNotFound.selector);
        mirrorPosition.mirror{value: callMirror.executionFee}(callMirror, puppetList);
    }

    function testNoSettledFundsError() public {
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 10);

        // Allocate successfully
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Check account is empty (allocate doesn't fund it, mirror does by transferring to vault)
        assertEq(usdc.balanceOf(allocationAddress), 0, "Allocation account should be empty before settlement");

        // Try to settle without any funds being dealt/returned to allocationAddress
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc,
            distributeToken: usdc,
            trader: trader,
            allocationId: allocationId
        });
        vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
        mirrorPosition.settle(callSettle, puppetList);
    }

    function testSizeAdjustmentsMatchMirrorPostion() public {
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 2); // Use default trader
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // 1. Allocate
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // Should be 2 puppets * 100e6 balance * 10%
            // rule = 20e6
        assertEq(netAllocated, 20e6, "Initial allocation should be 20e6");

        // 2. Mirror Open
        MirrorPosition.CallPosition memory callOpen = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta, // 100e6
            sizeDeltaInUsd: defaultSizeDeltaInUsd, // 1000e30 (Trader 10x)
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        assertNotEq(increaseRequestKey, bytes32(0));

        // Check stored adjustment data
        MirrorPosition.RequestAdjustment memory req1 = mirrorPosition.getRequestAdjustment(increaseRequestKey);
        // Calculate expected initial mirror size based on contract logic
        (uint expectedInitialMirrorSizeDelta, bool isInc1) = calculateExpectedMirrorSizeDelta(
            MirrorPosition.Position(0, 0, 0), // Represents state *before* execution
            callOpen.sizeDeltaInUsd, // Target trader size
            callOpen.collateralDelta, // Target trader collateral
            netAllocated // Initial mirror collateral
        );
        // Expected: 1000e30 * 20e6 / 100e6 = 200e30
        assertEq(expectedInitialMirrorSizeDelta, 200e30, "Calculated initial mirror size delta mismatch");
        assertEq(isInc1, true, "Initial delta should be increase");
        assertEq(req1.allocationKey, allocationKey, "Stored allocationKey mismatch req1");
        assertEq(req1.sizeDelta, expectedInitialMirrorSizeDelta, "Stored sizeDelta for initial open mismatch");
        assertEq(req1.traderCollateralDelta, callOpen.collateralDelta);
        assertEq(req1.traderSizeDelta, callOpen.sizeDeltaInUsd);

        // 3. Execute Open
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos1.traderSize, defaultSizeDeltaInUsd, "Pos1 TSize");
        assertEq(pos1.traderCollateral, defaultCollateralDelta, "Pos1 TCollat");
        assertEq(pos1.size, expectedInitialMirrorSizeDelta, "Pos1 MSize"); // Check actual mirrored size after execution
        assertApproxEqAbs(
            Precision.toBasisPoints(pos1.size, netAllocated), // Mirror leverage: 200e30 / 20e6 -> ~10x (e30/e6 -> e24
                // -> need * 100 for BP)
            Precision.toBasisPoints(pos1.traderSize, pos1.traderCollateral), // Trader leverage: 1000e30 / 100e6 -> 10x
            LEVERAGE_TOLERANCE_BP,
            "Pos1 Leverage mismatch"
        );

        // 4. Mirror Partial Decrease (50% Trader Size, 0 Trader Collat) -> Trader Lev 10x -> 5x
        MirrorPosition.CallPosition memory partialDecreaseParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false, // Decrease
            isLong: true, // Match direction
            executionFee: defaultExecutionFee,
            collateralDelta: 0, // No change in trader collateral
            sizeDeltaInUsd: pos1.traderSize / 2, // Decrease trader size by 50% (500e30)
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        uint expectedTraderSize2 = pos1.traderSize - partialDecreaseParams.sizeDeltaInUsd; // 1000e30 - 500e30 = 500e30
        uint expectedTraderCollat2 = pos1.traderCollateral; // 100e6 (remains same)
        // Calculate expected mirror delta using helper (Input: current pos, new trader state, mirror collateral)
        (uint expectedMirrorDelta2, bool deltaIsIncrease2) =
            calculateExpectedMirrorSizeDelta(pos1, expectedTraderSize2, expectedTraderCollat2, netAllocated);
        assertEq(deltaIsIncrease2, false, "PartialDec: Delta direction should be false");
        // Expected: Trader Lev 10x -> 5x. Mirror Delta = currentMirrorSize * (10x - 5x) / 10x = 200e30 * 5x / 10x =
        // 100e30.
        assertEq(expectedMirrorDelta2, 100e30, "PartialDec: Expected Delta mismatch");

        bytes32 partialDecreaseKey =
            mirrorPosition.mirror{value: partialDecreaseParams.executionFee}(partialDecreaseParams, puppetList);
        assertNotEq(partialDecreaseKey, bytes32(0));
        // Check stored delta
        MirrorPosition.RequestAdjustment memory req2 = mirrorPosition.getRequestAdjustment(partialDecreaseKey);
        assertEq(req2.allocationKey, allocationKey, "Stored allocationKey mismatch req2");
        assertEq(req2.sizeDelta, expectedMirrorDelta2, "Stored sizeDelta for partial decrease mismatch");

        // 5. Execute Partial Decrease
        mirrorPosition.execute(partialDecreaseKey);
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos2.traderSize, expectedTraderSize2, "Pos2 TSize");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "Pos2 TCollat");
        assertEq(pos2.size, pos1.size - expectedMirrorDelta2, "Pos2 MSize"); // Apply the delta: 200e30 - 100e30 =
            // 100e30
        assertApproxEqAbs(
            Precision.toBasisPoints(pos2.size, netAllocated), // Mirror leverage: 100e30 / 20e6 -> ~5x
            Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral), // Trader leverage: 500e30 / 100e6 -> 5x
            LEVERAGE_TOLERANCE_BP,
            "Pos2 Leverage mismatch"
        );

        // 6. Mirror Partial Increase (Back to original trader size) -> Trader Lev 5x -> 10x
        MirrorPosition.CallPosition memory partialIncreaseParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true, // Increase
            isLong: true, // Match direction
            executionFee: defaultExecutionFee,
            collateralDelta: 0, // No change in trader collateral
            sizeDeltaInUsd: pos1.traderSize / 2, // Increase trader size by 500e30 to get back to 1000e30
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        uint expectedTraderSize3 = pos2.traderSize + partialIncreaseParams.sizeDeltaInUsd; // 500e30 + 500e30 = 1000e30
        uint expectedTraderCollat3 = pos2.traderCollateral; // 100e6 (remains same)
        // Calculate expected mirror delta using helper
        (uint expectedMirrorDelta3, bool deltaIsIncrease3) =
            calculateExpectedMirrorSizeDelta(pos2, expectedTraderSize3, expectedTraderCollat3, netAllocated);
        assertEq(deltaIsIncrease3, true, "PartialInc: Delta direction should be true");
        // Expected: Trader Lev 5x -> 10x. Mirror Delta = currentMirrorSize * (10x - 5x) / 5x = 100e30 * 5x / 5x =
        // 100e30.
        assertEq(expectedMirrorDelta3, 100e30, "PartialInc: Expected Delta mismatch");

        bytes32 partialIncreaseKey =
            mirrorPosition.mirror{value: partialIncreaseParams.executionFee}(partialIncreaseParams, puppetList);
        assertNotEq(partialIncreaseKey, bytes32(0));
        MirrorPosition.RequestAdjustment memory req3 = mirrorPosition.getRequestAdjustment(partialIncreaseKey);
        assertEq(req3.allocationKey, allocationKey, "Stored allocationKey mismatch req3");
        assertEq(req3.sizeDelta, expectedMirrorDelta3, "Stored sizeDelta for partial increase mismatch");

        // 7. Execute Partial Increase
        mirrorPosition.execute(partialIncreaseKey);
        MirrorPosition.Position memory pos3 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos3.traderSize, expectedTraderSize3, "Pos3 TSize");
        assertEq(pos3.traderCollateral, expectedTraderCollat3, "Pos3 TCollat");
        assertEq(pos3.size, pos2.size + expectedMirrorDelta3, "Pos3 MSize"); // Apply delta: 100e30 + 100e30 = 200e30
        assertApproxEqAbs(
            Precision.toBasisPoints(pos3.size, netAllocated), // Mirror leverage: 200e30 / 20e6 -> ~10x
            Precision.toBasisPoints(pos3.traderSize, pos3.traderCollateral), // Trader leverage: 1000e30 / 100e6 -> 10x
            LEVERAGE_TOLERANCE_BP,
            "Pos3 Leverage mismatch"
        );
        // Check we are back to original mirrored size
        assertEq(pos3.size, expectedInitialMirrorSizeDelta, "Pos3 MSize should equal original mirrored size");

        // 8. Mirror Full Close
        MirrorPosition.CallPosition memory fullDecreaseParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false, // Decrease
            isLong: true, // Match direction
            executionFee: defaultExecutionFee,
            collateralDelta: pos3.traderCollateral, // Close full trader collateral (100e6)
            sizeDeltaInUsd: pos3.traderSize, // Close full trader size (1000e30)
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        // Calculate expected mirror delta for full close (target trader size/collat = 0)
        (uint expectedMirrorDelta4, bool deltaIsIncrease4) = calculateExpectedMirrorSizeDelta(pos3, 0, 0, netAllocated);
        assertEq(deltaIsIncrease4, false, "FullClose: Delta direction should be false");
        // Expected: Close full current mirrored size
        assertEq(expectedMirrorDelta4, pos3.size, "FullClose: Expected Delta should be full current size");

        bytes32 fullDecreaseKey =
            mirrorPosition.mirror{value: fullDecreaseParams.executionFee}(fullDecreaseParams, puppetList);
        assertNotEq(fullDecreaseKey, bytes32(0));
        MirrorPosition.RequestAdjustment memory req4 = mirrorPosition.getRequestAdjustment(fullDecreaseKey);
        assertEq(req4.allocationKey, allocationKey, "Stored allocationKey mismatch req4");
        assertEq(req4.sizeDelta, expectedMirrorDelta4, "Stored sizeDelta for full close mismatch");

        // 9. Execute Full Close
        mirrorPosition.execute(fullDecreaseKey);
        MirrorPosition.Position memory pos4 = mirrorPosition.getPosition(allocationKey);
        assertEq(pos4.traderSize, 0, "Pos4 TSize");
        assertEq(pos4.traderCollateral, 0, "Pos4 TCollat");
        assertEq(pos4.size, 0, "Pos4 MSize"); // pos3.size - expectedMirrorDelta4 should be 0
    }

    function testAllocationExceedingMaximumPuppets() public {
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList; // Should be 20 from setup
        address trader = defaultTrader;
        // Create one more puppet address than allowed
        address[] memory tooManyPuppets = new address[](limitAllocationListLength + 1);
        for (uint i = 0; i < tooManyPuppets.length; i++) {
            // Just need distinct addresses, don't need to fund/setup rules
            tooManyPuppets[i] = address(uint160(uint(keccak256(abi.encodePacked("dummyPuppet", i)))));
        }

        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});

        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.allocate(callAlloc, tooManyPuppets);
    }

    function testPositionSettlementWithProfit() public {
        address trader = defaultTrader;
        uint feeFactor = getPlatformSettleFeeFactor(); // Use helper

        // Use users.alice as puppet owner for deposit permissions
        address puppet1 = createPuppet(usdc, users.alice, trader, "profitPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, users.alice, trader, "profitPuppet2", 200e6);
        address puppet3 = createPuppet(usdc, users.alice, trader, "profitPuppet3", 300e6);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        // Allocate
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint puppet1Allocation = allocationPuppetMap(allocationKey, puppet1); // 10% of 100e6 = 10e6
        uint puppet2Allocation = allocationPuppetMap(allocationKey, puppet2); // 10% of 200e6 = 20e6
        uint puppet3Allocation = allocationPuppetMap(allocationKey, puppet3); // 10% of 300e6 = 30e6
        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // Use contract's total
        assertEq(totalAllocation, 60e6, "Initial allocation total should be 60e6");
        assertEq(puppet1Allocation + puppet2Allocation + puppet3Allocation, totalAllocation, "Sum check mismatch");

        // Store balances *before* mirror call deducts contributions
        uint puppet1BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet1); // 100e6
        uint puppet2BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet2); // 200e6
        uint puppet3BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet3); // 300e6

        // Open and close a position (simplified steps for settlement focus)
        MirrorPosition.CallPosition memory callOpen = MirrorPosition.CallPosition({ /* ... default open params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta,
            sizeDeltaInUsd: defaultSizeDeltaInUsd,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 openKey = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);

        // Check balances *after* mirror call (contributions deducted) but *before* execute/settle
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

        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        MirrorPosition.CallPosition memory callClose = MirrorPosition.CallPosition({ /* ... default close params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: currentPos.traderCollateral,
            sizeDeltaInUsd: currentPos.traderSize,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 closeKey = mirrorPosition.mirror{value: callClose.executionFee}(callClose, puppetList);

        // Simulate Profit: initial allocation + 100% profit = 60e6 + 60e6 = 120e6
        uint profitAmount = totalAllocation;
        uint settledAmount = totalAllocation + profitAmount; // 120e6
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey); // Execute the close order simulation

        // Settle funds
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId
        });
        mirrorPosition.settle(callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        uint platformFee = Precision.applyFactor(feeFactor, settledAmount); // 10% of 120e6 = 12e6
        uint amountAfterFee = settledAmount - platformFee; // 108e6

        // Calculate expected share additions based on original contributions
        uint puppet1ExpectedShare = Math.mulDiv(amountAfterFee, puppet1Allocation, totalAllocation); // 108e6 * 10e6 /
            // 60e6 = 18e6
        uint puppet2ExpectedShare = Math.mulDiv(amountAfterFee, puppet2Allocation, totalAllocation); // 108e6 * 20e6 /
            // 60e6 = 36e6
        uint puppet3ExpectedShare = Math.mulDiv(amountAfterFee, puppet3Allocation, totalAllocation); // 108e6 * 30e6 /
            // 60e6 = 54e6

        // Assert the balance INCREASE (from afterMirror state) matches the expected share
        assertEq(puppet1BalanceAfterSettle - puppet1BalanceAfterMirror, puppet1ExpectedShare, "Puppet1 share mismatch");
        assertEq(puppet2BalanceAfterSettle - puppet2BalanceAfterMirror, puppet2ExpectedShare, "Puppet2 share mismatch");
        assertEq(puppet3BalanceAfterSettle - puppet3BalanceAfterMirror, puppet3ExpectedShare, "Puppet3 share mismatch");

        // Also check final absolute balance
        assertEq(puppet1BalanceAfterSettle, puppet1BalanceBeforeMirror - puppet1Allocation + puppet1ExpectedShare); // 100
            // - 10 + 18 = 108
        assertEq(puppet2BalanceAfterSettle, puppet2BalanceBeforeMirror - puppet2Allocation + puppet2ExpectedShare); // 200
            // - 20 + 36 = 216
        assertEq(puppet3BalanceAfterSettle, puppet3BalanceBeforeMirror - puppet3Allocation + puppet3ExpectedShare); // 300
            // - 30 + 54 = 324
    }

    function testPositionSettlementWithLoss() public {
        address trader = defaultTrader;
        uint feeFactor = getPlatformSettleFeeFactor();

        // Use users.alice as puppet owner
        address puppet1 = createPuppet(usdc, users.alice, trader, "lossPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, users.alice, trader, "lossPuppet2", 100e6);
        address puppet3 = createPuppet(usdc, users.alice, trader, "lossPuppet3", 100e6);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        // Allocate
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint puppet1Allocation = allocationPuppetMap(allocationKey, puppet1); // 10% of 100e6 = 10e6
        uint puppet2Allocation = allocationPuppetMap(allocationKey, puppet2); // 10% of 100e6 = 10e6
        uint puppet3Allocation = allocationPuppetMap(allocationKey, puppet3); // 10% of 100e6 = 10e6
        uint totalAllocation = mirrorPosition.getAllocation(allocationKey); // 30e6
        assertEq(totalAllocation, 30e6);
        assertEq(puppet1Allocation + puppet2Allocation + puppet3Allocation, totalAllocation);

        // Record balances before contributions are deducted
        uint puppet1BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet1); // 100e6
        uint puppet2BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet2); // 100e6
        uint puppet3BalanceBeforeMirror = allocationStore.userBalanceMap(usdc, puppet3); // 100e6

        // Open and close a position
        MirrorPosition.CallPosition memory callOpen = MirrorPosition.CallPosition({ /* ... default open params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta,
            sizeDeltaInUsd: defaultSizeDeltaInUsd,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 openKey = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);

        // Record balances after contributions deducted
        uint puppet1BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet1); // 90e6
        uint puppet2BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet2); // 90e6
        uint puppet3BalanceAfterMirror = allocationStore.userBalanceMap(usdc, puppet3); // 90e6

        mirrorPosition.execute(openKey);
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        MirrorPosition.CallPosition memory callClose = MirrorPosition.CallPosition({ /* ... default close params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: currentPos.traderCollateral,
            sizeDeltaInUsd: currentPos.traderSize,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 closeKey = mirrorPosition.mirror{value: callClose.executionFee}(callClose, puppetList);

        // Simulate 20% loss - return 80% of initial allocation = 30e6 * 0.8 = 24e6
        uint settledAmount = Math.mulDiv(totalAllocation, 80, 100); // 24e6
        deal(address(usdc), allocationAddress, settledAmount);

        mirrorPosition.execute(closeKey);

        // Settle funds
        MirrorPosition.CallSettle memory callSettle = MirrorPosition.CallSettle({
            allocationToken: usdc, // Original basis
            distributeToken: usdc, // Distributing USDC
            trader: trader,
            allocationId: allocationId
        });
        mirrorPosition.settle(callSettle, puppetList);

        uint puppet1BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfterSettle = allocationStore.userBalanceMap(usdc, puppet3);

        // Fee is on the settled amount (even if it's a loss)
        uint platformFee = Precision.applyFactor(feeFactor, settledAmount); // 10% of 24e6 = 2.4e6
        uint amountAfterFee = settledAmount - platformFee; // 21.6e6

        // Calculate expected return additions (will be less than contribution)
        // Expected return = 21.6e6 * 10e6 / 30e6 = 7.2e6
        uint puppet1ExpectedReturn = Math.mulDiv(amountAfterFee, puppet1Allocation, totalAllocation);
        uint puppet2ExpectedReturn = Math.mulDiv(amountAfterFee, puppet2Allocation, totalAllocation);
        uint puppet3ExpectedReturn = Math.mulDiv(amountAfterFee, puppet3Allocation, totalAllocation);
        assertEq(puppet1ExpectedReturn, 7.2e6, "P1 Expected return calc error"); // Sanity check calc

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
        assertEq(puppet1BalanceAfterSettle, puppet1BalanceBeforeMirror - puppet1Allocation + puppet1ExpectedReturn); // 100
            // - 10 + 7.2 = 97.2e6
        assertEq(puppet2BalanceAfterSettle, puppet2BalanceBeforeMirror - puppet2Allocation + puppet2ExpectedReturn); // 100
            // - 10 + 7.2 = 97.2e6
        assertEq(puppet3BalanceAfterSettle, puppet3BalanceBeforeMirror - puppet3Allocation + puppet3ExpectedReturn); // 100
            // - 10 + 7.2 = 97.2e6
    }

    function testZeroCollateralAdjustments() public {
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 2); // Use default trader
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        // Allocate
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        uint netAllocated = mirrorPosition.getAllocation(allocationKey); // 20e6

        // Open initial position (Trader 10x leverage)
        MirrorPosition.CallPosition memory callOpen = MirrorPosition.CallPosition({ /* ... default open params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta,
            sizeDeltaInUsd: defaultSizeDeltaInUsd,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: callOpen.executionFee}(callOpen, puppetList);
        mirrorPosition.execute(increaseRequestKey);
        MirrorPosition.Position memory pos1 = mirrorPosition.getPosition(allocationKey);
        // Expected mirror size = 1000e30 * 20e6 / 100e6 = 200e30
        assertEq(pos1.size, 200e30, "Pos1 initial size mismatch");

        // Increase trader size without changing trader collateral -> Trader Leverage increases (10x -> 15x)
        MirrorPosition.CallPosition memory zeroCollateralIncreaseParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true, // Increase
            isLong: true, // Match direction
            executionFee: defaultExecutionFee,
            collateralDelta: 0, // <<< ZERO trader collateral change
            sizeDeltaInUsd: 500e30, // Add 500e30 trader size
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });

        uint expectedTraderSize2 = pos1.traderSize + zeroCollateralIncreaseParams.sizeDeltaInUsd; // 1000e30 + 500e30 =
            // 1500e30
        uint expectedTraderCollat2 = pos1.traderCollateral; // 100e6 (remains same)
        // Calculate expected mirror delta using helper
        (uint expectedMirrorDelta2, bool deltaIsIncrease2) =
            calculateExpectedMirrorSizeDelta(pos1, expectedTraderSize2, expectedTraderCollat2, netAllocated);
        assertEq(deltaIsIncrease2, true, "ZeroCollat: Delta direction should be true");
        // Expected: Trader Lev 10x -> 15x. Mirror Delta = currentMirrorSize * (15x - 10x) / 10x = 200e30 * 5x / 10x =
        // 100e30.
        assertEq(expectedMirrorDelta2, 100e30, "ZeroCollat: Expected Delta mismatch");

        bytes32 zeroCollateralRequestKey = mirrorPosition.mirror{value: zeroCollateralIncreaseParams.executionFee}(
            zeroCollateralIncreaseParams, puppetList
        );
        mirrorPosition.execute(zeroCollateralRequestKey);
        MirrorPosition.Position memory pos2 = mirrorPosition.getPosition(allocationKey);

        assertEq(pos2.traderSize, expectedTraderSize2, "ZeroCollat: TSize mismatch");
        assertEq(pos2.traderCollateral, expectedTraderCollat2, "ZeroCollat: TCollat mismatch");
        assertEq(pos2.size, pos1.size + expectedMirrorDelta2, "ZeroCollat: MSize mismatch"); // 200e30 + 100e30 = 300e30

        assertApproxEqAbs(
            Precision.toBasisPoints(pos2.size, netAllocated), // Mirror leverage: 300e30 / 20e6 -> ~15x
            Precision.toBasisPoints(pos2.traderSize, pos2.traderCollateral), // Trader leverage: 1500e30 / 100e6 -> 15x
            LEVERAGE_TOLERANCE_BP,
            "ZeroCollat: Leverage mismatch"
        );
    }

    function testAccessControlForCriticalFunctions() public {
        // Setup: Create a puppet list and allocate
        address trader = defaultTrader;
        address[] memory puppetList = generatePuppetList(usdc, trader, 1);
        MirrorPosition.CallAllocation memory callAlloc =
            MirrorPosition.CallAllocation({collateralToken: usdc, trader: trader, platformExecutionFee: 0});
        uint allocationId = mirrorPosition.allocate(callAlloc, puppetList);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // --- Test allocate ---
        vm.expectRevert(); // Expect revert due to lack of permission
        vm.prank(users.bob); // Non-owner user
        mirrorPosition.allocate(callAlloc, puppetList);

        // --- Test mirror ---
        MirrorPosition.CallPosition memory callMirror = MirrorPosition.CallPosition({ /* ... default open params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: true,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: defaultCollateralDelta,
            sizeDeltaInUsd: defaultSizeDeltaInUsd,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.mirror{value: callMirror.executionFee}(callMirror, puppetList);

        // --- Test execute (Requires a valid request first) ---
        // Owner creates a request
        vm.prank(users.owner);
        bytes32 requestKey = mirrorPosition.mirror{value: callMirror.executionFee}(callMirror, puppetList);
        // Non-owner tries to execute
        vm.expectRevert();
        vm.prank(users.bob);
        mirrorPosition.execute(requestKey);

        // --- Test settle ---
        // Need to simulate position close and funds received first
        // Owner executes open, then closes, simulates funds, tries to settle
        vm.prank(users.owner);
        mirrorPosition.execute(requestKey); // Execute the open request
        MirrorPosition.Position memory currentPos = mirrorPosition.getPosition(allocationKey);
        MirrorPosition.CallPosition memory callClose = MirrorPosition.CallPosition({ /* ... default close params ... */
            collateralToken: usdc,
            trader: trader,
            market: defaultMarket,
            isIncrease: false,
            isLong: true,
            executionFee: defaultExecutionFee,
            collateralDelta: currentPos.traderCollateral,
            sizeDeltaInUsd: currentPos.traderSize,
            acceptablePrice: 0,
            triggerPrice: 0,
            allocationId: allocationId
        });
        bytes32 closeKey = mirrorPosition.mirror{value: callClose.executionFee}(callClose, puppetList);
        mirrorPosition.execute(closeKey); // Execute close
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        deal(address(usdc), allocationAddress, 10e6); // Deal some funds to settle

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

        // --- Test initializeTraderActivityThrottle (only MatchRule should call) ---
        vm.expectRevert();
        vm.prank(users.owner); // Owner shouldn't call directly
        mirrorPosition.initializeTraderActivityThrottle(trader, puppetList[0]);
        vm.expectRevert();
        vm.prank(users.bob); // Other users shouldn't call
        mirrorPosition.initializeTraderActivityThrottle(trader, puppetList[0]);

        // Reset prank
        vm.stopPrank();
    }

    // --- Helper functions ---

    // Updated: Takes puppetOwner address who has deposit permissions
    // Assuming owner has been pre-pranked in order to call permissioned functions
    function createPuppet(
        MockERC20 collateralToken,
        address puppetOwner, // Address funding the puppet (needs pre-approval)
        address trader, // Trader the puppet follows
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        // Create a unique address for the puppet logic/rule itself
        address payable puppetAddress = payable(makeAddr(name));
        vm.label(puppetAddress, name); // Label for easier debugging

        // Fund the puppetOwner (assuming they have approved tokenRouter)
        collateralToken.mint(puppetOwner, fundValue); // Mint funds to the owner
        matchRule.deposit(collateralToken, puppetOwner, fundValue);

        // Owner (or authorized party) sets the rule for the puppet owner/logic address to follow the trader
        vm.startPrank(users.owner); // Assuming owner has setRule permission
        matchRule.setRule(
            collateralToken,
            puppetOwner, // The owner whose balance is used
            trader, // The trader to follow
            MatchRule.Rule({
                allowanceRate: 1000, // Default 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 2 days
            })
        );

        // Return the address of the puppet owner, as this is the key used in AllocationStore balances
        return payable(puppetOwner); // CHANGED: Return owner, not logic address
    }

    function setPerformanceFee(
        uint newFeeFactor_e30
    ) internal {
        MirrorPosition.Config memory currentConfig = mirrorPosition.getConfig();
        currentConfig.platformSettleFeeFactor = newFeeFactor_e30;
        // Use dictator to set the config on the target contract
        dictator.setConfig(mirrorPosition, abi.encode(currentConfig));
        // Verify change
        assertEq(mirrorPosition.getConfig().platformSettleFeeFactor, newFeeFactor_e30, "Fee factor not set");
    }

    // Helper to calculate allocation key, should match PositionUtils.getAllocationKey internal logic
    function getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint _allocationId
    ) internal pure returns (bytes32) {
        // Ensure this matches the exact encoding used in PositionUtils.getAllocationKey
        return keccak256(abi.encodePacked(_puppetList, _matchKey, _allocationId));
    }

    function getPlatformSettleFeeFactor() internal view returns (uint) {
        return mirrorPosition.getConfig().platformSettleFeeFactor;
    }

    // Generates puppets owned by users.alice (who has pre-approval) following the specified trader
    function generatePuppetList(
        MockERC20 collateralToken,
        address trader,
        uint _length
    ) internal returns (address[] memory) {
        require(_length > 0, "Length must be > 0");
        address[] memory puppetList = new address[](_length);
        address puppetOwner = users.alice; // Use pre-approved user
        for (uint i = 0; i < _length; i++) {
            // Generate unique name for puppet logic address
            string memory puppetName = string(abi.encodePacked("puppet:", Strings.toString(i)));
            // Each puppet in the list is the address of the owner whose balance is used
            puppetList[i] = createPuppet(collateralToken, puppetOwner, trader, puppetName, 100e6); // Default 100e6
                // funding
                // Ensure uniqueness if owner is reused (makeAddr creates unique logic addr anyway)
        }
        return puppetList;
    }

    function allocationPuppetMap(bytes32 allocationKey, address puppetOwner) internal view returns (uint) {
        // The map stores allocation per puppet *owner* address based on MatchRule deposit
        return mirrorPosition.allocationPuppetMap(allocationKey, puppetOwner);
    }
}
