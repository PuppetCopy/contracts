// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console} from "forge-std/src/console.sol";

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";
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

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    uint defaultEstimatedGasLimit = 5_000_000;

    MirrorPosition.PositionParams defaultTraderPositionParams;

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

        defaultTraderPositionParams = MirrorPosition.PositionParams({
            collateralToken: usdc,
            trader: users.bob,
            market: Address.gmxEthUsdcMarket,
            isIncrease: true,
            isLong: true,
            executionFee: tx.gasprice * defaultEstimatedGasLimit,
            collateralDelta: 120e6,
            sizeDeltaInUsd: 30e30,
            acceptablePrice: 1000e12,
            triggerPrice: 1000e12
        });

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
                    platformFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 100
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
        feeMarketplace.setAskPrice(usdc, 100e18);
        mirrorPosition.configMaxCollateralTokenAllocation(usdc, 1000e6);
        mirrorPosition.configMaxCollateralTokenAllocation(wnt, 100e18);

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

    function testSimpleExecutionResult() public {
        address[] memory puppetList = generatePuppetList(usdc, defaultTraderPositionParams.trader, 10);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);

        uint allocationStoreBalanceBefore = usdc.balanceOf(address(allocationStore));

        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);

        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        uint allocated = mirrorPosition.getAllocation(allocationKey);

        // Assert correct allocation
        assertEq(allocated, 100e6, "Allocation should be 100e6 where each puppet allocates 10e6 on 10% allocation rule");

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            defaultTraderPositionParams, puppetList, allocationId
        );

        uint allocationStoreBalanceAfter = allocationStoreBalanceBefore - allocated;

        assertEq(usdc.balanceOf(address(allocationStore)), allocationStoreBalanceAfter);

        // Simulate position increase callback
        mirrorPosition.execute(increaseRequestKey);

        // Now simulate decrease position 122677
        defaultTraderPositionParams.isIncrease = false;
        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            defaultTraderPositionParams, puppetList, allocationId
        );

        uint profit = 100e6;
        uint settledAmount = allocated + profit;
        uint platformFee = Precision.applyFactor(getPlatformFeeFactor(), settledAmount);

        assertEq(platformFee, 20e6, "10% platform fee should be 20e6 assuming 200e6 has been settled");

        // Need to simulate some tokens coming back to the contract
        // In real environment, GMX would send funds back
        deal(address(usdc), allocationAddress, settledAmount);
        // Return more than collateral to simulate profit

        // Simulate position decrease callback
        mirrorPosition.execute(decreaseRequestKey);

        // Settle the allocation
        mirrorPosition.settle(usdc, defaultTraderPositionParams.trader, puppetList, allocationId);

        // Settle the funds to the allocation store
        assertEq(
            usdc.balanceOf(address(allocationStore)),
            allocationStoreBalanceAfter + settledAmount - platformFee,
            "Allocation store should receive the expected funds minus platform fee"
        );

        // check puppet's balance within allocation store
        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            assertEq(
                allocationStore.userBalanceMap(usdc, puppet),
                108e6,
                "Puppet should have 8e6 profit after settlement"
            );
        }

    }

    // Tests for error conditions
    function testExecutionRequestMissingError() public {
        // Try to process a non-existent request
        bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));

        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);

        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistentRequestKey);
    }

    function testPositionDoesNotExistError() public {
        // Create valid allocation first
        address[] memory puppetList = generatePuppetList(usdc, 2);

        // Create a decrease order without having a position first
        MirrorPosition.PositionParams memory decreaseParams = defaultTraderPositionParams;
        decreaseParams.isIncrease = false; // Decrease

        vm.expectRevert(Error.MirrorPosition__AllocationAccountNotFound.selector);
        bytes32 nonExistingKey =
            mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(decreaseParams, puppetList, 123);

        // This should fail when trying to decrease a non-existent position
        vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
        mirrorPosition.execute(nonExistingKey);
    }

    function testNoSettledFundsError() public {
        address[] memory puppetList = generatePuppetList(usdc, 10);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);

        // Try to settle without any funds being settled
        vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
        mirrorPosition.settle(usdc, defaultTraderPositionParams.trader, puppetList, allocationId);
    }

    // Functional tests
    function testSizeAdjustmentsMatchMirrorPostion() public {
        address[] memory puppetList = generatePuppetList(usdc, defaultTraderPositionParams.trader, 2);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);

        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory partialDecreaseParams = defaultTraderPositionParams;
        partialDecreaseParams.isIncrease = false; // Decrease
        partialDecreaseParams.collateralDelta = 0; // No collateral change
        partialDecreaseParams.sizeDeltaInUsd = 500e30; // 50% of size

        bytes32 partialDecreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            partialDecreaseParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory partialIncreaseParams = defaultTraderPositionParams;
        partialIncreaseParams.collateralDelta = 0; // No collateral change
        partialIncreaseParams.sizeDeltaInUsd = 500e30; // 50% of size

        bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            partialIncreaseParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory fullDecreaseParams = defaultTraderPositionParams;
        fullDecreaseParams.isIncrease = false;
        fullDecreaseParams.collateralDelta = 0; // No collateral change
        fullDecreaseParams.sizeDeltaInUsd = 1000e30; // Full size

        bytes32 fullDecreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            fullDecreaseParams, puppetList, allocationId
        );
        mirrorPosition.execute(fullDecreaseRequestKey);
        MirrorPosition.Position memory _position4 = mirrorPosition.getPosition(allocationKey);
        assertEq(_position4.traderSize, 0, "Trader size should be 0 after full decrease");
        assertEq(_position4.traderCollateral, 0, "Trader collateral should be 0 after full decrease");
        assertEq(_position4.mpSize, 0, "MirrorPosition size should be 0 after full decrease");
        assertEq(_position4.mpCollateral, 0, "MirrorPosition collateral should be 0 after full decrease");
    }

    function testCollateralAdjustmentsMatchMirrorPostion() public {
        address[] memory puppetList = generatePuppetList(usdc, defaultTraderPositionParams.trader, 2);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);

        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;
        increaseParams.executionFee = defaultTraderPositionParams.executionFee;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory partialIncreaseParams = defaultTraderPositionParams;
        partialIncreaseParams.collateralDelta = 100e6; // +100% collateral
        partialIncreaseParams.sizeDeltaInUsd = 0; // No size change

        bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            partialIncreaseParams, puppetList, allocationId
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
        // Create 3 puppets for this test to examine more complex distributions
        address[] memory puppetList = generatePuppetList(usdc, 3);

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, defaultTraderPositionParams.trader);

        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Test Case 1: Initial position with small size but high leverage
        // Open a small position with very high leverage (50x)
        MirrorPosition.PositionParams memory highLeverageParams = defaultTraderPositionParams;
        highLeverageParams.collateralDelta = 10e6;
        highLeverageParams.sizeDeltaInUsd = 100e30;

        bytes32 initialRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            highLeverageParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory reduceRiskParams = defaultTraderPositionParams;
        reduceRiskParams.collateralDelta = 40e6;
        reduceRiskParams.sizeDeltaInUsd = 0;

        bytes32 reduceRiskRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            reduceRiskParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory smallAdjustmentParams = defaultTraderPositionParams;
        smallAdjustmentParams.collateralDelta = 50e6;
        smallAdjustmentParams.sizeDeltaInUsd = 100e30;

        bytes32 smallAdjustmentKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            smallAdjustmentParams, puppetList, allocationId
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
        MirrorPosition.PositionParams memory complexAdjustmentParams = defaultTraderPositionParams;
        complexAdjustmentParams.collateralDelta = 50e6;
        complexAdjustmentParams.sizeDeltaInUsd = 50e30;

        bytes32 complexAdjustmentKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            complexAdjustmentParams, puppetList, allocationId
        );

        mirrorPosition.execute(complexAdjustmentKey);

        assertEq(
            Precision.toBasisPoints(position3.traderSize, position3.traderCollateral),
            Precision.toBasisPoints(position3.mpSize, position3.mpCollateral),
            "Leverage ratios should match after tiny adjustment"
        );
    }

    /**
     *
     * PLATFORM FEE VERIFICATION TESTS
     *
     */
    function testPlatformFeeCalculation() public {
        address trader = defaultTraderPositionParams.trader;

        // Set platform fee to 10% for clear calculation
        uint platformFeePercentage = 0.1e30; // 10%
        setPerformanceFee(platformFeePercentage);

        // Generate puppets and setup allocation
        address[] memory puppetList = generatePuppetList(usdc, trader, 3);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Open position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.trader = trader;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        // Close position with profit
        MirrorPosition.PositionParams memory decreaseParams = defaultTraderPositionParams;
        decreaseParams.trader = trader;
        decreaseParams.isIncrease = false;
        decreaseParams.collateralDelta = 100e6;
        decreaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            decreaseParams, puppetList, allocationId
        );

        // Initial allocation amount from puppets should be 30e6 (3 puppets × 10e6)
        uint initialAllocation = mirrorPosition.getAllocation(allocationKey);
        assertEq(initialAllocation, 30e6, "Initial allocation should be 30e6");

        // Simulate 20% profit: allocate 36e6 (30e6 initial + 6e6 profit)
        deal(address(usdc), allocationAddress, 36e6);

        // Track fee marketplace balance before settlement
        uint feeMarketplaceBalanceBefore = usdc.balanceOf(address(feeMarketplaceStore));

        mirrorPosition.execute(decreaseRequestKey);

        // Settle allocation and verify fee
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        uint feeMarketplaceBalanceAfter = usdc.balanceOf(address(feeMarketplaceStore));
        uint feeCollected = feeMarketplaceBalanceAfter - feeMarketplaceBalanceBefore;

        // Expected fee: 36e6 (total) * 0.1 (10% fee) = 3.6e6
        // Note: Fee is taken from the total amount, not just the profit
        uint expectedFee = 3.6e6;
        assertEq(feeCollected, expectedFee, "Fee collected should be 10% of total amount");
    }

    function testFeeCalculationWithDifferentPercentages() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        // Test with multiple fee percentages
        uint[] memory feePercentages = new uint[](3);
        feePercentages[0] = 0.05e30; // 5%
        feePercentages[1] = 0.2e30; // 20%
        feePercentages[2] = 0.01e30; // 1%

        for (uint i = 0; i < feePercentages.length; i++) {
            // Reset setup for each fee percentage
            setPerformanceFee(feePercentages[i]);

            address[] memory puppetList = generatePuppetList(usdc, trader, 2);
            bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
            uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
            bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
            address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
                mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
            );

            // Open & close position
            MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
            increaseParams.trader = trader;
            increaseParams.collateralDelta = 50e6;
            increaseParams.sizeDeltaInUsd = 500e30;
            increaseParams.executionFee = executionFee;

            bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
                increaseParams, puppetList, allocationId
            );

            mirrorPosition.execute(increaseRequestKey);

            MirrorPosition.PositionParams memory decreaseParams = defaultTraderPositionParams;
            decreaseParams.trader = trader;
            decreaseParams.isIncrease = false;
            decreaseParams.collateralDelta = 50e6;
            decreaseParams.sizeDeltaInUsd = 500e30;
            decreaseParams.executionFee = executionFee;

            bytes32 decreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
                decreaseParams, puppetList, allocationId
            );

            // Initial allocation is 20e6 (2 puppets × 10e6)
            uint initialAllocation = mirrorPosition.getAllocation(allocationKey);

            // Simulate 50% profit: 30e6 (20e6 + 10e6 profit)
            deal(address(usdc), allocationAddress, 30e6);

            uint feeMarketplaceBalanceBefore = usdc.balanceOf(address(feeMarketplaceStore));

            mirrorPosition.execute(decreaseRequestKey);
            mirrorPosition.settle(usdc, trader, puppetList, allocationId);

            uint feeMarketplaceBalanceAfter = usdc.balanceOf(address(feeMarketplaceStore));
            uint feeCollected = feeMarketplaceBalanceAfter - feeMarketplaceBalanceBefore;

            // Expected fee: 30e6 (total) * fee percentage
            uint expectedFee = (30e6 * feePercentages[i]) / 1e30;
            assertEq(
                feeCollected,
                expectedFee,
                string(
                    abi.encodePacked("Fee should be ", Strings.toString(feePercentages[i] / 1e28), "% of total amount")
                )
            );
        }
    }

    function testMultiplePositionsWithDifferentTokens() public {
        address trader = defaultTraderPositionParams.trader;

        // Create first position with USDC
        address[] memory usdcPuppetList = generatePuppetList(usdc, trader, 2);
        bytes32 usdcMatchKey = PositionUtils.getMatchKey(usdc, trader);

        // Set collateral token explicitly for USDC allocation
        MirrorPosition.PositionParams memory usdcParams = defaultTraderPositionParams;
        usdcParams.collateralToken = usdc;

        uint usdcAllocationId = mirrorPosition.allocate(usdcParams, usdcPuppetList);
        bytes32 usdcAllocationKey = getAllocationKey(usdcPuppetList, usdcMatchKey, usdcAllocationId);

        // Create second position with WETH - need to create WETH puppets correctly
        address[] memory wethPuppetList = new address[](2);
        for (uint i = 0; i < 2; i++) {
            wethPuppetList[i] =
                createPuppet(wnt, trader, string(abi.encodePacked("weth-puppet:", Strings.toString(i))), 0.1e18);
        }

        bytes32 wethMatchKey = PositionUtils.getMatchKey(wnt, trader);

        // Set collateral token explicitly for WETH allocation
        MirrorPosition.PositionParams memory wethParams = defaultTraderPositionParams;
        wethParams.collateralToken = wnt;

        uint wethAllocationId = mirrorPosition.allocate(wethParams, wethPuppetList);
        bytes32 wethAllocationKey = getAllocationKey(wethPuppetList, wethMatchKey, wethAllocationId);

        // Open USDC position
        MirrorPosition.PositionParams memory usdcIncreaseParams = defaultTraderPositionParams;
        usdcIncreaseParams.collateralToken = usdc;
        usdcIncreaseParams.collateralDelta = 100e6;
        usdcIncreaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 usdcIncreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            usdcIncreaseParams, usdcPuppetList, usdcAllocationId
        );

        mirrorPosition.execute(usdcIncreaseRequestKey);

        // Open WETH position
        MirrorPosition.PositionParams memory wethIncreaseParams = defaultTraderPositionParams;
        wethIncreaseParams.collateralToken = wnt;
        wethIncreaseParams.collateralDelta = 0.1e18; // 0.1 ETH
        wethIncreaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 wethIncreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            wethIncreaseParams, wethPuppetList, wethAllocationId
        );

        mirrorPosition.execute(wethIncreaseRequestKey);

        // Verify both positions exist independently
        MirrorPosition.Position memory usdcPosition = mirrorPosition.getPosition(usdcAllocationKey);
        MirrorPosition.Position memory wethPosition = mirrorPosition.getPosition(wethAllocationKey);

        assertEq(usdcPosition.traderSize, 1000e30, "USDC position size should be 1000e30");
        assertEq(wethPosition.traderSize, 1000e30, "WETH position size should be 1000e30");

        // Modify USDC position without affecting WETH position
        MirrorPosition.PositionParams memory usdcModifyParams = defaultTraderPositionParams;
        usdcModifyParams.collateralDelta = 50e6;
        usdcModifyParams.sizeDeltaInUsd = 0;

        bytes32 usdcModifyRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            usdcModifyParams, usdcPuppetList, usdcAllocationId
        );

        // Save initial values before execution
        uint position1SizeBefore = usdcPosition.traderSize;

        mirrorPosition.execute(usdcModifyRequestKey);

        // Verify USDC position changed but WETH position remained the same
        MirrorPosition.Position memory usdcPositionAfter = mirrorPosition.getPosition(usdcAllocationKey);
        MirrorPosition.Position memory wethPositionAfter = mirrorPosition.getPosition(wethAllocationKey);

        assertEq(usdcPositionAfter.traderCollateral, 150e6, "USDC position collateral should be updated");
        assertEq(wethPositionAfter.traderCollateral, 0.1e18, "WETH position should remain unchanged");
    }

    function testAllocationWithExactMaximumPuppets() public {
        address trader = users.bob;

        // Get the maximum puppet list length from config
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList;

        // Create a list with exactly the maximum allowed puppets
        address[] memory maxPuppetList = new address[](limitAllocationListLength);
        for (uint i = 0; i < limitAllocationListLength; i++) {
            maxPuppetList[i] =
                createPuppet(usdc, trader, string(abi.encodePacked("maxPuppet:", Strings.toString(i))), 10e6);
        }

        // This should succeed as we're at the limit
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, maxPuppetList);
        assertGt(allocationId, 0, "Allocation with maximum puppets should succeed");
    }

    function testAllocationExceedingMaximumPuppets() public {
        // Get the maximum puppet list length from config
        uint limitAllocationListLength = mirrorPosition.getConfig().maxPuppetList;

        // Create a list exceeding the maximum by 1
        address[] memory tooManyPuppets = new address[](limitAllocationListLength + 1);
        for (uint i = 0; i < limitAllocationListLength + 1; i++) {
            // Use address creation without actually creating puppets to avoid excessive gas usage
            tooManyPuppets[i] = address(uint160(i + 1));
        }

        // This should fail
        vm.expectRevert(Error.MirrorPosition__MaxPuppetList.selector);
        mirrorPosition.allocate(defaultTraderPositionParams, tooManyPuppets);
    }

    function testPositionSettlementWithProfit() public {
        address trader = defaultTraderPositionParams.trader;

        // Set a fixed platform fee for test predictability
        setPerformanceFee(0.1e30); // 10% fee

        // Create 3 puppets with different allowance rates (all with 10% allowance)
        address puppet1 = createPuppet(usdc, trader, "profitPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, trader, "profitPuppet2", 200e6);
        address puppet3 = createPuppet(usdc, trader, "profitPuppet3", 300e6);

        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Get the allocation amounts for each puppet
        uint puppet1Allocation = allocationPuppetMap(allocationKey, puppet1);
        uint puppet2Allocation = allocationPuppetMap(allocationKey, puppet2);
        uint puppet3Allocation = allocationPuppetMap(allocationKey, puppet3);

        uint totalAllocation = puppet1Allocation + puppet2Allocation + puppet3Allocation;

        // With 10% allocation rate:
        // puppet1 = 100e6 * 10% = 10e6
        // puppet2 = 200e6 * 10% = 20e6
        // puppet3 = 300e6 * 10% = 30e6
        // Total: 60e6
        assertEq(totalAllocation, 60e6, "Initial allocation should be 60e6");

        // Open and close a position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.PositionParams memory decreaseParams = defaultTraderPositionParams;
        decreaseParams.isIncrease = false;
        decreaseParams.collateralDelta = 100e6;
        decreaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            decreaseParams, puppetList, allocationId
        );

        // The actual allocated amount may differ from the sum of puppet allocations
        uint initialAllocation = mirrorPosition.getAllocation(allocationKey);

        // Simulate fixed profit amount for predictable testing
        uint settledAmount = 36e6; // 60e6 * 0.6 (to simulate profit of 20%)
        deal(address(usdc), allocationAddress, settledAmount);

        // Check balances before settlement
        uint puppet1BalanceBefore = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceBefore = allocationStore.userBalanceMap(usdc, puppet3);

        mirrorPosition.execute(decreaseRequestKey);
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        // Check balances after settlement
        uint puppet1BalanceAfter = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfter = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfter = allocationStore.userBalanceMap(usdc, puppet3);

        // Platform fee is 10% of the total settled amount
        uint platformFee = Precision.applyFactor(getPlatformFeeFactor(), settledAmount);
        uint amountAfterFee = settledAmount - platformFee;

        // Calculate expected amounts with precise math
        // Each puppet gets a proportion based on their contribution to the total allocation
        uint puppet1ExpectedShare = (amountAfterFee * puppet1Allocation) / totalAllocation;
        uint puppet2ExpectedShare = (amountAfterFee * puppet2Allocation) / totalAllocation;
        uint puppet3ExpectedShare = (amountAfterFee * puppet3Allocation) / totalAllocation;

        // Puppet1 should get 1/6 of the amount after fee
        // Puppet2 should get 1/3 of the amount after fee
        // Puppet3 should get 1/2 of the amount after fee
        assertEq(
            puppet1BalanceAfter - puppet1BalanceBefore,
            puppet1ExpectedShare,
            "Puppet1 should receive proportional share"
        );
        assertEq(
            puppet2BalanceAfter - puppet2BalanceBefore,
            puppet2ExpectedShare,
            "Puppet2 should receive proportional share"
        );
        assertEq(
            puppet3BalanceAfter - puppet3BalanceBefore,
            puppet3ExpectedShare,
            "Puppet3 should receive proportional share"
        );
    }

    function testPositionSettlementWithLoss() public {
        address trader = defaultTraderPositionParams.trader;

        // Create 3 puppets with equal allocations for simplicity
        address puppet1 = createPuppet(usdc, trader, "lossPuppet1", 100e6);
        address puppet2 = createPuppet(usdc, trader, "lossPuppet2", 100e6);
        address puppet3 = createPuppet(usdc, trader, "lossPuppet3", 100e6);

        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);
        address allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            mirrorPosition.allocationStoreImplementation(), allocationKey, address(mirrorPosition)
        );

        // Get the allocation amounts for each puppet (should be 10e6 each with 10% allowance)
        uint puppet1Allocation = allocationPuppetMap(allocationKey, puppet1);
        uint puppet2Allocation = allocationPuppetMap(allocationKey, puppet2);
        uint puppet3Allocation = allocationPuppetMap(allocationKey, puppet3);

        uint totalAllocation = puppet1Allocation + puppet2Allocation + puppet3Allocation;
        assertEq(totalAllocation, 30e6, "Total allocation should be 30e6");

        // Open and close a position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        MirrorPosition.PositionParams memory decreaseParams = defaultTraderPositionParams;
        decreaseParams.isIncrease = false;
        decreaseParams.collateralDelta = 100e6;
        decreaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            decreaseParams, puppetList, allocationId
        );

        // Simulate 20% loss - distribute 80% of original allocation
        uint lossAmount = totalAllocation * 80 / 100;
        deal(address(usdc), allocationAddress, lossAmount);

        // Check balances before settlement
        uint puppet1BalanceBefore = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceBefore = allocationStore.userBalanceMap(usdc, puppet3);

        mirrorPosition.execute(decreaseRequestKey);
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);

        // Check balances after settlement
        uint puppet1BalanceAfter = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfter = allocationStore.userBalanceMap(usdc, puppet2);
        uint puppet3BalanceAfter = allocationStore.userBalanceMap(usdc, puppet3);

        // With loss, platform fee is still taken on the full settled amount
        uint platformFee = getPlatformFeeFactor(); // 0.1%
        uint feeAmount = (lossAmount * platformFee) / 1e30;
        uint amountAfterFee = lossAmount - feeAmount;

        // Calculate exact expected returns
        uint puppet1ExpectedReturn = (amountAfterFee * puppet1Allocation) / totalAllocation;
        uint puppet2ExpectedReturn = (amountAfterFee * puppet2Allocation) / totalAllocation;
        uint puppet3ExpectedReturn = (amountAfterFee * puppet3Allocation) / totalAllocation;

        assertEq(
            puppet1BalanceAfter - puppet1BalanceBefore,
            puppet1ExpectedReturn,
            "Puppet1 should receive proportional return after loss"
        );
        assertEq(
            puppet2BalanceAfter - puppet2BalanceBefore,
            puppet2ExpectedReturn,
            "Puppet2 should receive proportional return after loss"
        );
        assertEq(
            puppet3BalanceAfter - puppet3BalanceBefore,
            puppet3ExpectedReturn,
            "Puppet3 should receive proportional return after loss"
        );
    }

    function testZeroCollateralAdjustments() public {
        address trader = defaultTraderPositionParams.trader;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open initial position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        // Increase size without changing collateral
        MirrorPosition.PositionParams memory zeroCollateralParams = defaultTraderPositionParams;
        zeroCollateralParams.collateralDelta = 0; // Zero collateral change
        zeroCollateralParams.sizeDeltaInUsd = 500e30;

        bytes32 zeroCollateralRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            zeroCollateralParams, puppetList, allocationId
        );

        mirrorPosition.execute(zeroCollateralRequestKey);

        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationKey);

        assertEq(position.traderSize, 1500e30, "Size should increase");
        assertEq(position.traderCollateral, 100e6, "Collateral should remain unchanged");

        // Leverage should increase
        uint initialLeverage = 1000e30 * 1e6 / 100e6; // 10e6
        uint newLeverage = 1500e30 * 1e6 / 100e6; // 15e6
        assertGt(newLeverage, initialLeverage, "Leverage should increase");

        // Verify mirror position has correct leverage
        assertEq(
            Precision.toBasisPoints(position.traderSize, position.traderCollateral),
            Precision.toBasisPoints(position.mpSize, position.mpCollateral),
            "Mirror position should maintain the same leverage ratio"
        );
    }

    function testTinyPositionAdjustments() public {
        address trader = defaultTraderPositionParams.trader;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open initial position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 100e6;
        increaseParams.sizeDeltaInUsd = 1000e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        // Make a tiny size adjustment (0.1% increase)
        uint tinyAdjustment = 1e30; // 0.1% of 1000e30

        MirrorPosition.PositionParams memory tinyParams = defaultTraderPositionParams;
        tinyParams.collateralDelta = 0;
        tinyParams.sizeDeltaInUsd = tinyAdjustment;

        bytes32 tinyRequestKey =
            mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(tinyParams, puppetList, allocationId);

        mirrorPosition.execute(tinyRequestKey);

        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationKey);

        assertEq(position.traderSize, 1000e30 + tinyAdjustment, "Size should increase by tiny amount");

        // Verify mirror position still has correct leverage ratio
        assertEq(
            Precision.toBasisPoints(position.traderSize, position.traderCollateral),
            Precision.toBasisPoints(position.mpSize, position.mpCollateral),
            "Mirror position should maintain the same leverage ratio even with tiny adjustment"
        );
    }

    function testVeryLargePositionAdjustments() public {
        address trader = defaultTraderPositionParams.trader;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open initial small position
        MirrorPosition.PositionParams memory increaseParams = defaultTraderPositionParams;
        increaseParams.collateralDelta = 10e6;
        increaseParams.sizeDeltaInUsd = 100e30;

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            increaseParams, puppetList, allocationId
        );

        mirrorPosition.execute(increaseRequestKey);

        // Make a very large adjustment (10x increase)
        MirrorPosition.PositionParams memory largeParams = defaultTraderPositionParams;
        largeParams.collateralDelta = 90e6; // 9x collateral increase
        largeParams.sizeDeltaInUsd = 900e30; // 9x size increase

        bytes32 largeRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            largeParams, puppetList, allocationId
        );

        mirrorPosition.execute(largeRequestKey);

        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationKey);

        assertEq(position.traderSize, 1000e30, "Size should increase by 10x");
        assertEq(position.traderCollateral, 100e6, "Collateral should increase by 10x");

        // Verify mirror position still has correct leverage ratio
        assertEq(
            Precision.toBasisPoints(position.traderSize, position.traderCollateral),
            Precision.toBasisPoints(position.mpSize, position.mpCollateral),
            "Mirror position should maintain the same leverage ratio even with large adjustment"
        );
    }

    function testMaximumLeveragePositions() public {
        address trader = defaultTraderPositionParams.trader;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        bytes32 allocationKey = getAllocationKey(puppetList, matchKey, allocationId);

        // Open high leverage position (100x)
        MirrorPosition.PositionParams memory highLeverageParams = defaultTraderPositionParams;
        highLeverageParams.collateralDelta = 10e6;
        highLeverageParams.sizeDeltaInUsd = 1000e30; // 100x leverage

        bytes32 highLeverageRequestKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            highLeverageParams, puppetList, allocationId
        );

        mirrorPosition.execute(highLeverageRequestKey);

        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationKey);

        // Verify the leverage is correct - using normalized units to get the correct ratio
        // Need to convert both to the same units (e30) for accurate comparison
        uint leverage = (position.traderSize * 1e6) / (position.traderCollateral * 1e30);
        assertEq(leverage, 100, "Leverage should be 100x (size/collateral in the same units)");

        // Now reduce leverage dramatically (to 2x)
        MirrorPosition.PositionParams memory reduceParams = defaultTraderPositionParams;
        reduceParams.collateralDelta = 490e6; // Add a lot of collateral
        reduceParams.sizeDeltaInUsd = 0; // Keep same size

        bytes32 reduceKey = mirrorPosition.mirror{value: defaultTraderPositionParams.executionFee}(
            reduceParams, puppetList, allocationId
        );

        // After executing the leverage reduction
        mirrorPosition.execute(reduceKey);

        MirrorPosition.Position memory positionAfter = mirrorPosition.getPosition(allocationKey);

        // Verify the leverage is reduced - should now be 1000e30 / 500e6 = 2x
        // Need to normalize units for this calculation
        uint leverageAfter = positionAfter.traderSize / (positionAfter.traderCollateral * 1e24);
        assertEq(leverageAfter, 2, "Leverage should be reduced to 2x");

        // Verify mirror position adjusted properly
        assertEq(
            Precision.toBasisPoints(positionAfter.traderSize, positionAfter.traderCollateral),
            Precision.toBasisPoints(positionAfter.mpSize, positionAfter.mpCollateral),
            "Mirror position should maintain the same reduced leverage ratio"
        );
    }

    function testAccessControlForCriticalFunctions() public {
        address trader = users.bob;
        address unauthorized = users.alice;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);

        // Test unauthorized access to allocate
        vm.startPrank(unauthorized);
        vm.expectRevert(); // Should revert due to auth modifier
        mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        vm.stopPrank();

        // Set up a valid allocation as owner
        vm.startPrank(users.owner);
        uint allocationId = mirrorPosition.allocate(defaultTraderPositionParams, puppetList);
        vm.stopPrank();

        // Test unauthorized access to mirror
        vm.startPrank(unauthorized);
        vm.expectRevert(); // Should revert due to auth modifier
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
        vm.expectRevert(); // Should revert due to auth modifier
        mirrorPosition.execute(requestKey);
        vm.stopPrank();

        // Execute as owner
        vm.startPrank(users.owner);
        mirrorPosition.execute(requestKey);
        vm.stopPrank();

        // Test unauthorized settlement
        vm.startPrank(unauthorized);
        vm.expectRevert(); // Should revert due to auth modifier
        mirrorPosition.settle(usdc, trader, puppetList, allocationId);
        vm.stopPrank();
    }

    // Helper functions for tests

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
        // Create new config with updated fee
        MirrorPosition.Config memory newConfig = mirrorPosition.getConfig();
        newConfig.platformFeeFactor = newFee;

        dictator.setConfig(mirrorPosition, abi.encode(newConfig));
    }

    function getAllocationKey(
        address[] memory _puppetList,
        bytes32 _matchKey,
        uint allocationId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_puppetList, _matchKey, allocationId));
    }

    function getPlatformFeeFactor() internal view returns (uint) {
        return mirrorPosition.getConfig().platformFeeFactor;
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

    function generatePuppetList(MockERC20 collateralToken, uint _length) internal returns (address[] memory) {
        return generatePuppetList(collateralToken, defaultTraderPositionParams.trader, _length);
    }

    function allocationPuppetMap(bytes32 allocationKey, address puppet) internal view returns (uint) {
        return mirrorPosition.allocationPuppetMap(allocationKey, puppet);
    }
}
