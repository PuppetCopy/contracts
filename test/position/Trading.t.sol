// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console} from "forge-std/src/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";
import {AllocationAccountUtils} from "src/position/utils/AllocationAccountUtils.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AllocationAccount} from "src/shared/AllocationAccount.sol";
import {Error} from "src/shared/Error.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/tokenomics/FeeMarketplaceStore.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";
import {Address} from "script/Const.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

// TODO: Add tests for the Trading contract
// MirrorPosition__NoAllocation - Increase request without allocation
// MirrorPosition__PendingAllocationExecution - Cannot allow additional requests during pending initial allocation
// MirrorPosition__PendingAllocation - Trying to allocate when there's already a pending allocation
// MirrorPosition__PuppetListLimit - Exceed the maximum allowed puppet list length
// MirrorPosition__NoPuppetAllocation - nothing has been allocated while processing puppet list
// MirrorPosition__ExecutionRequestMissing - Trying to process a request that doesn't exist
// MirrorPosition__PositionDoesNotExist - Trying to decrease a non-existent position
// MirrorPosition__NoSettledFunds - Trying to settle an allocation that has no funds
// MirrorPosition__InvalidPuppetListIntegrity - Settlement puppet list doesn't match allocation's list
// TODO: Test edge cases for allocation distribution calculation
// TODO: Test gas fee tracking and accounting
// TODO: Test partial decrease vs full decrease position differences
// TODO: Test performance contribution fees to the fee marketplace
// TODO: Test throttling mechanism between puppets and traders
// TODO: Test allocation expiry handling

contract TradingTest is BasicSetup {
    AllocationStore allocationStore;
    MatchRule matchRule;
    FeeMarketplace feeMarketplace;
    MirrorPosition mirrorPosition;
    MockGmxExchangeRouter mockGmxExchangeRouter;
    FeeMarketplaceStore feeMarketplaceStore;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        super.setUp();

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
                    callbackHandler: address(mirrorPosition),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    limitAllocationListLength: 100,
                    platformFee: 0.001e30
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
            mirrorPosition, mirrorPosition.initializeTraderAcitityThrottle.selector, address(matchRule)
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        feeMarketplace.setAskPrice(usdc, 100e18);

        // Ensure owner has permissions to act on behalf of users
        dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);

        // Pre-approve token allowances for users
        vm.startPrank(users.alice);
        usdc.approve(address(allocationStore), type(uint).max);
        wnt.approve(address(allocationStore), type(uint).max);

        vm.startPrank(users.bob);
        usdc.approve(address(allocationStore), type(uint).max);
        wnt.approve(address(allocationStore), type(uint).max);

        vm.startPrank(users.owner);
    }

    function testSimpleE2eExecution() public {
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = generatePuppetList(usdc, trader, 10);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        uint allocationId = mirrorPosition.allocate(usdc, trader, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                collateralToken: usdc,
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 120e6,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        assertGt(mirrorPosition.getAllocation(allocationKey), 0, "Allocation should be greater than 0");

        // Simulate position increase callback
        mirrorPosition.execute(increaseRequestKey);

        // Now simulate decrease position 122677
        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                collateralToken: usdc,
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                isIncrease: false,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 120e6,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        // Need to simulate some tokens coming back to the contract
        // In real environment, GMX would send funds back
        deal(address(usdc), allocationAddress, 11e6 * 10);
        // Return more than collateral to simulate profit

        // Simulate position decrease callback
        mirrorPosition.execute(decreaseRequestKey);

        // Settle the allocation
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);
    }

    // Tests for error conditions
    function testNoAllocationError() public {
        address trader = users.bob;
        address[] memory puppetList = new address[](0);

        vm.expectRevert(Error.MirrorPosition__NoPuppetAllocation.selector);
        mirrorPosition.allocate(usdc, trader, puppetList);
    }

    function testExecutionRequestMissingError() public {
        // Try to process a non-existent request
        bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));

        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);

        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);
    }

    function testPositionDoesNotExistError() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        // Create valid allocation first

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);

        // Create a decrease order without having a position first
        vm.expectRevert(Error.MirrorPosition__AllocationAccountNotFound.selector);
        bytes32 nonExistingKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: false, // Decrease
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDeltaInUsd: 10e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            123
        );

        // This should fail when trying to decrease a non-existent position
        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistingKey);
    }

    function testNoSettledFundsError() public {
        address trader = users.bob;

        address[] memory puppetList = generatePuppetList(usdc, trader, 10);
        uint allocationId = mirrorPosition.allocate(usdc, trader, puppetList);

        // Try to settle without any funds being settled
        vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);
    }

    // Functional tests
    function testSizeAdjustmentsMatchMirrorPostion() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        uint allocationId = mirrorPosition.allocate(usdc, trader, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open position
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDeltaInUsd: 1000e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        // make sure request includes the propotional size and collateral to the puppet

        // test case has 2 puppets. trader initial target ratio is 1000e30 / 100e6 = 10x
        // each collateral delta should be 10 USDC due to 10% allocation rule
        // the combined collateral delta should be 20 USDC
        // size should be 200e30 to match trader 10x target ratio
        assertEq(
            mirrorPosition.getRequestAdjustment(increaseRequestKey).puppetSizeDelta,
            200e30,
            "Initial size delta should be 200e30 as each puppet"
        );

        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.Position memory _position1 = mirrorPosition.getPosition(allocationKey);

        assertEq(_position1.traderSize, 1000e30, "Trader size should be 1000e30");
        assertEq(_position1.traderCollateral, 100e6, "Trader collateral should be 100e6");
        assertEq(_position1.mpSize, 200e30, "MirrorPosition size should be 200e30");
        assertEq(_position1.mpCollateral, 20e6, "MirrorPosition collateral should be 20e6");

        assertEq(
            Precision.toBasisPoints(_position1.traderSize, _position1.traderCollateral),
            Precision.toBasisPoints(_position1.mpSize, _position1.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );

        // Partial decrease (50%)
        bytes32 partialDecreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                collateralToken: usdc,
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                isIncrease: false, // Decrease
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 0, // No collateral change
                sizeDeltaInUsd: 500e30, // 50% of size
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        assertEq(
            mirrorPosition.getRequestAdjustment(partialDecreaseRequestKey).puppetSizeDelta,
            100e30,
            "For a 50% position decrease, puppet size delta should be 100e30 (50% of total)"
        );

        mirrorPosition.execute(partialDecreaseRequestKey);

        MirrorPosition.Position memory _position2 = mirrorPosition.getPosition(allocationKey);

        assertEq(_position2.traderSize, 500e30, "Trader size should be 500e30");
        assertEq(_position2.traderCollateral, 100e6, "Trader collateral should remain 100e6");

        assertEq(
            Precision.toBasisPoints(_position2.traderSize, _position2.traderCollateral),
            Precision.toBasisPoints(_position2.mpSize, _position2.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );

        // Partial increase (50%)
        bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 0, // No collateral change
                sizeDeltaInUsd: 500e30, // 50% of size
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        PositionUtils.AjustmentType adjustmentType =
            mirrorPosition.getRequestAdjustment(partialIncreaseRequestKey).targetLeverageType;

        assert(adjustmentType == PositionUtils.AjustmentType.INCREASE);

        mirrorPosition.execute(partialIncreaseRequestKey);

        MirrorPosition.Position memory _position3 = mirrorPosition.getPosition(allocationKey);

        assertEq(_position3.traderSize, 1000e30, "Trader size should be 1000e30 after partial increase");
        assertEq(_position3.traderCollateral, 100e6, "Trader collateral should remain 100e6 after partial increase");
        assertEq(_position3.mpSize, 200e30, "MirrorPosition size should get back to 200e30 after partial increase");

        assertEq(
            Precision.toBasisPoints(_position3.traderSize, _position3.traderCollateral),
            Precision.toBasisPoints(_position3.mpSize, _position3.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );

        // add more tests with collateral adjustments in testAdjustmentsMatchMirrorPostion()

        // Full decrease
        bytes32 fullDecreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: false,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 0, // No collateral change
                sizeDeltaInUsd: 1000e30, // Full size
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );
        mirrorPosition.execute(fullDecreaseRequestKey);
        MirrorPosition.Position memory _position4 = mirrorPosition.getPosition(allocationKey);
        assertEq(_position4.traderSize, 0, "Trader size should be 0 after full decrease");
        assertEq(_position4.traderCollateral, 0, "Trader collateral should be 0 after full decrease");
        assertEq(_position4.mpSize, 0, "MirrorPosition size should be 0 after full decrease");
        assertEq(_position4.mpCollateral, 0, "MirrorPosition collateral should be 0 after full decrease");
    }

    function testCollateralAdjustmentsMatchMirrorPostion() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        uint allocationId = mirrorPosition.allocate(usdc, trader, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open position
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDeltaInUsd: 1000e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        // make sure request includes the propotional size and collateral to the puppet

        // test case has 2 puppets. trader initial target ratio is 1000e30 / 100e6 = 10x
        // each collateral delta should be 10 USDC due to 10% allocation rule
        // the combined collateral delta should be 20 USDC
        // size should be 200e30 to match trader 10x target ratio
        assertEq(
            mirrorPosition.getRequestAdjustment(increaseRequestKey).puppetCollateralDelta,
            20e6,
            "Initial size delta should be 20e6 as each puppet"
        );

        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.Position memory _position1 = mirrorPosition.getPosition(allocationKey);

        assertEq(_position1.traderSize, 1000e30, "Trader size should be 1000e30");
        assertEq(_position1.traderCollateral, 100e6, "Trader collateral should be 100e6");
        assertEq(_position1.mpSize, 200e30, "MirrorPosition size should be 200e30");
        assertEq(_position1.mpCollateral, 20e6, "MirrorPosition collateral should be 20e6");
        assertEq(
            Precision.toBasisPoints(_position1.traderSize, _position1.traderCollateral),
            Precision.toBasisPoints(_position1.mpSize, _position1.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );
        // // Partial Increase (50%)
        bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6, // +100% collateral
                sizeDeltaInUsd: 0, // No size change
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        assertEq(
            mirrorPosition.getRequestAdjustment(partialIncreaseRequestKey).puppetSizeDelta,
            100e30,
            "For a 50% collateral decrease, puppet size delta should adjust by 100e30 (50% of total)"
        );
        mirrorPosition.execute(partialIncreaseRequestKey);
        MirrorPosition.Position memory _position2 = mirrorPosition.getPosition(allocationKey);
        assertEq(_position2.traderSize, 1000e30, "Trader size should be 1000e30");
        assertEq(_position2.traderCollateral, 200e6, "Trader collateral should be 200e6");
        assertEq(_position2.mpSize, 100e30, "MirrorPosition size should be 100e30");
        assertEq(_position2.mpCollateral, 20e6, "MirrorPosition collateral should remain 20e6");
        assertEq(
            Precision.toBasisPoints(_position2.traderSize, _position2.traderCollateral),
            Precision.toBasisPoints(_position2.mpSize, _position2.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );
    }

    function testComplexAdjustmentsAndEdgeCases() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        // Create 3 puppets for this test to examine more complex distributions
        address[] memory puppetList = generatePuppetList(usdc, trader, 3);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);

        uint allocationId = mirrorPosition.allocate(usdc, trader, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );
        // Test Case 1: Initial position with small size but high leverage
        // Open a small position with very high leverage (50x)
        bytes32 initialRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 10e6,
                sizeDeltaInUsd: 100e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        mirrorPosition.execute(initialRequestKey);

        MirrorPosition.Position memory position1 = mirrorPosition.getPosition(allocationKey);

        // Check initial position
        assertEq(position1.traderSize, 100e30, "Trader size should be 100e30");
        assertEq(position1.traderCollateral, 10e6, "Trader collateral should be 10e6");
        assertEq(position1.mpCollateral, 30e6, "Mirror position collateral should be 30e6 (30% allocation)");
        assertEq(position1.mpSize, 300e30, "Mirror position size should be 300e30 (3x collateral)");

        // Verify the leverage ratios match
        assertEq(
            Precision.toBasisPoints(position1.traderSize, position1.traderCollateral),
            Precision.toBasisPoints(position1.mpSize, position1.mpCollateral),
            "Initial leverage ratios should match"
        );

        // Test Case 2: Drastically reduce leverage by adding collateral without changing size
        bytes32 reduceRiskRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 40e6,
                sizeDeltaInUsd: 0,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        mirrorPosition.execute(reduceRiskRequestKey);

        MirrorPosition.Position memory position2 = mirrorPosition.getPosition(allocationKey);

        // // Check after reducing leverage
        assertEq(position2.traderSize, 100e30, "Trader size should remain 500e30");
        assertEq(position2.traderCollateral, 50e6, "Trader collateral should be 50e6");

        // When adding collateral, the mirror position's size should adjust only the size
        assertEq(position2.mpSize, 60e30, "Mirror position size should be (3x collateral)");
        assertEq(position2.mpCollateral, 30e6, "Mirror position collateral should remain 30e6");

        // Verify the leverage ratios match (now 10x instead of 50x)
        assertEq(
            Precision.toBasisPoints(position2.traderSize, position2.traderCollateral),
            Precision.toBasisPoints(position2.mpSize, position2.mpCollateral),
            "Reduced leverage ratios should match"
        );

        // Test Case 3: Edge case - increase both size and collateral without changing leverage
        // This should not change the leverage ratio
        bytes32 smallAdjustmentKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 50e6,
                sizeDeltaInUsd: 100e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        assertEq(
            mirrorPosition.getRequestAdjustment(smallAdjustmentKey).puppetSizeDelta,
            0,
            "Leverage ratio remains unchanged"
        );
        assertEq(
            mirrorPosition.getRequestAdjustment(smallAdjustmentKey).puppetCollateralDelta,
            0,
            "Leverage ratio remains unchanged"
        );

        mirrorPosition.execute(smallAdjustmentKey);

        MirrorPosition.Position memory position3 = mirrorPosition.getPosition(allocationKey);

        // Check after tiny adjustment
        assertEq(position3.traderSize, 200e30, "Trader size should be 501e30");
        assertEq(position3.traderCollateral, 100e6, "Trader collateral should remain 50e6");

        // When adding collateral, the mirror position's size should adjust only the size
        assertEq(position2.mpSize, 60e30, "Mirror position size should be (3x collateral)");
        assertEq(position2.mpCollateral, 30e6, "Mirror position collateral should remain 30e6");

        // Verify the leverage ratios still match after tiny adjustment
        assertEq(
            Precision.toBasisPoints(position3.traderSize, position3.traderCollateral),
            Precision.toBasisPoints(position3.mpSize, position3.mpCollateral),
            "Leverage ratios should match after tiny adjustment"
        );

        // // Test Case 4: Complex adjustment - increase size and decrease collateral simultaneously
        bytes32 complexAdjustmentKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.PositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 50e6,
                sizeDeltaInUsd: 50e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            }),
            puppetList,
            allocationId
        );

        mirrorPosition.execute(complexAdjustmentKey);

        assertEq(
            Precision.toBasisPoints(position3.traderSize, position3.traderCollateral),
            Precision.toBasisPoints(position3.mpSize, position3.mpCollateral),
            "Leverage ratios should match after tiny adjustment"
        );
    }

    // Helper functions for tests
    function getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint allocationId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_puppetList, _matchKey, allocationId));
    }

    function getPlatformFee() internal view returns (uint) {
        (,,,,,,, uint platformFee) = mirrorPosition.config();
        return platformFee;
    }

    function generatePuppetList(
        MockERC20 collateralToken,
        address trader,
        uint _length
    ) internal returns (address[] memory) {
        address[] memory puppetList = new address[](_length);
        for (uint i; i < _length; i++) {
            puppetList[i] =
                createPuppet(collateralToken, trader, string(abi.encodePacked("puppet:", Strings.toString(i))), 100e6);
        }
        return puppetList;
    }

    function createPuppet(
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

    function setPerformanceFee(
        uint newFee
    ) internal {
        (
            IGmxExchangeRouter gmxExchangeRouter,
            address callbackHandler,
            address gmxOrderVault,
            bytes32 referralCode,
            uint increaseCallbackGasLimit,
            uint decreaseCallbackGasLimit,
            uint limitAllocationListLength,
            // uint platformFee
        ) = mirrorPosition.config();

        dictator.setConfig(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: gmxExchangeRouter,
                    callbackHandler: callbackHandler,
                    gmxOrderVault: gmxOrderVault,
                    referralCode: referralCode,
                    increaseCallbackGasLimit: increaseCallbackGasLimit,
                    decreaseCallbackGasLimit: decreaseCallbackGasLimit,
                    limitAllocationListLength: limitAllocationListLength,
                    platformFee: newFee
                })
            )
        );
    }
}
