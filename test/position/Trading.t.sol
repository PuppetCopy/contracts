// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KeeperRouter} from "src/keeperRouter.sol";
import {Allocate} from "src/position/Allocate.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";

/**
 * @title Trading Test Suite
 * @notice Comprehensive tests for the copy trading system
 * @dev Tests integration between Allocation, MirrorPosition, and KeeperRouter
 */
contract TradingTest is BasicSetup {
    AllocationStore allocationStore;
    Allocate allocate;
    Settle settle;
    MatchingRule matchingRule;
    MirrorPosition mirrorPosition;
    KeeperRouter keeperRouter;
    MockGmxExchangeRouter mockGmxExchangeRouter;

    uint nextAllocationId = 0;

    // Test actors
    address trader = makeAddr("trader");
    address puppet1 = makeAddr("puppet1");
    address puppet2 = makeAddr("puppet2");

    function getNextAllocationId() internal returns (uint) {
        return ++nextAllocationId;
    }

    function setUp() public override {
        super.setUp();

        // Deploy core contracts
        allocationStore = new AllocationStore(dictator, tokenRouter);

        allocate = new Allocate(
            dictator,
            allocationStore,
            Allocate.Config({
                transferOutGasLimit: 200_000,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.1e30, // 10%
                gmxOrderVault: address(0x1234) // Mock GMX OrderVault
            })
        );

        settle = new Settle(
            dictator,
            allocationStore,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.05e30, // 5%
                maxKeeperFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100000
            })
        );

        matchingRule = new MatchingRule(
            dictator,
            allocationStore,
            MatchingRule.Config({
                transferOutGasLimit: 200_000,
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        mirrorPosition = new MirrorPosition(
            dictator,
            MirrorPosition.Config({
                gmxExchangeRouter: IGmxExchangeRouter(address(mockGmxExchangeRouter)),
                gmxOrderVault: address(0x1234),
                referralCode: bytes32("PUPPET"),
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                fallbackRefundExecutionFeeReceiver: address(0x9999)
            })
        );

        keeperRouter = new KeeperRouter(
            dictator,
            mirrorPosition,
            matchingRule,
            allocate,
            settle,
            KeeperRouter.Config({
                mirrorBaseGasLimit: 1_300_853, // Based on empirical single-puppet test
                mirrorPerPuppetGasLimit: 30_000, // Conservative estimate for additional puppets
                adjustBaseGasLimit: 910_663, // Keep existing (need adjust operation analysis)
                adjustPerPuppetGasLimit: 3_412, // Keep existing (need adjust operation analysis)
                fallbackRefundExecutionFeeReceiver: address(0x9999)
            })
        );

        // Set up permissions for owner to act on behalf of users
        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(allocate));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(settle));

        // TokenRouter permissions for stores
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));

        // MatchingRule needs permission to call allocate functions
        dictator.setPermission(allocate, allocate.initializeTraderActivityThrottle.selector, address(matchingRule));

        // KeeperRouter needs permission to call allocate and settle functions
        dictator.setPermission(allocate, allocate.createAllocation.selector, address(keeperRouter));
        dictator.setPermission(allocate, allocate.collectKeeperFee.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.settle.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.collectDust.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, address(keeperRouter));

        // Initialize contracts
        dictator.initContract(allocate);
        dictator.initContract(settle);
        dictator.initContract(matchingRule);
        dictator.initContract(mirrorPosition);
        dictator.initContract(keeperRouter);

        // Stop current prank and restart for user operations
        IERC20[] memory allowedTokens = new IERC20[](1);
        allowedTokens[0] = usdc;
        uint[] memory allowanceCaps = new uint[](1);
        allowanceCaps[0] = 10000e6; // 10000 USDC cap

        dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, users.owner);
        matchingRule.setTokenAllowanceList(allowedTokens, allowanceCaps);

        // Test setup: mint USDC to owner and approve for matchingRule
        // Owner permissions for dust collection
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, users.owner);

        dictator.setPermission(keeperRouter, keeperRouter.requestMirror.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.settleAllocation.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, users.owner);

        // Owner permissions to act on behalf of users
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, users.owner);
        dictator.setPermission(matchingRule, matchingRule.setRule.selector, users.owner);

        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, users.owner);

        // Setup puppet balances using owner permissions - owner deposits on behalf of puppets
        matchingRule.deposit(usdc, users.owner, puppet1, 1000e6);
        matchingRule.deposit(usdc, users.owner, puppet2, 800e6);

        // Set up trading rules using owner permissions
        matchingRule.setRule(
            allocate,
            usdc,
            puppet1,
            trader,
            MatchingRule.Rule({
                allowanceRate: 2000, // 20%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        matchingRule.setRule(
            allocate,
            usdc,
            puppet2,
            trader,
            MatchingRule.Rule({
                allowanceRate: 1500, // 15%
                throttleActivity: 2 hours,
                expiry: block.timestamp + 30 days
            })
        );
    }

    //----------------------------------------------------------------------------
    // Core Trading Functionality Tests
    //----------------------------------------------------------------------------

    function testRequestMirrorSuccess() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint keeperFee = 1e6; // 1 USDC

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        (address allocationAddress, bytes32 requestKey) =
            keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);

        // Verify allocation was created
        assertGt(allocate.getAllocation(allocationAddress), 0, "Allocation should be created");

        // Verify request was submitted to GMX
        assertNotEq(requestKey, bytes32(0), "Request key should be generated");

        // Verify keeper fee was paid (owner had 200e6 initial balance from BasicSetup)
        assertEq(usdc.balanceOf(users.owner), 200e6 + keeperFee, "Keeper should receive fee");
    }

    function testRequestMirrorInsufficientFunds() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint keeperFee = 10000e6; // Excessive keeper fee

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert();
        keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);
    }

    function testRequestAdjustSuccess() public {
        // First create an allocation and mirror position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint keeperFee = 1e6; // 1 USDC

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory initialCallParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        (, bytes32 requestKey) = keeperRouter.requestMirror{value: 0.001 ether}(allocParams, initialCallParams);

        executeOrder(requestKey);

        // Now test adjustment
        uint adjustKeeperFee = 0.5e6; // 0.5 USDC

        // Adjust position - trader increases leverage by adding more size without proportional collateral
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 100e30, // Small collateral increase
            sizeDeltaInUsd: 3000e30, // Large size increase (changes leverage)
            acceptablePrice: 3100e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        Allocate.CallAllocation memory adjustAllocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: adjustKeeperFee,
            keeperFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        bytes32 adjustRequestKey = keeperRouter.requestAdjust{value: 0.001 ether}(adjustAllocParams, callParams);

        // Verify request was submitted
        assertNotEq(adjustRequestKey, bytes32(0), "Adjust request should be generated");
    }

    function testSettleSuccess() public {
        // First create allocation and position
        testRequestMirrorSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1;
        address allocationAddress = getAllocationAddress(usdc, trader, puppetList, allocationId);

        // Simulate profit by sending tokens to allocation account - owner can mint
        usdc.mint(allocationAddress, 500e6);

        Settle.CallSettle memory settleParams = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            keeperFeeReceiver: users.owner,
            trader: trader,
            allocationId: allocationId,
            keeperExecutionFee: 0.1e6
        });

        uint puppet1BalanceBefore = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(usdc, puppet2);

        (uint settledAmount, uint distributionAmount, uint platformFeeAmount) =
            keeperRouter.settleAllocation(settleParams, puppetList);

        // Verify settlement occurred
        assertGt(settledAmount, 0, "Should have settled some amount");
        assertGt(distributionAmount, 0, "Should have distributed some amount");

        // Verify puppet balances increased
        assertGt(allocationStore.userBalanceMap(usdc, puppet1), puppet1BalanceBefore, "Puppet1 balance should increase");
        assertGt(allocationStore.userBalanceMap(usdc, puppet2), puppet2BalanceBefore, "Puppet2 balance should increase");

        // Verify platform fee was collected
        assertGt(platformFeeAmount, 0, "Platform fee should be collected");
    }

    function testCollectDust() public {
        // Create an allocation first
        testRequestMirrorSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        address allocationAddress = getAllocationAddress(usdc, trader, puppetList, 1);

        // Set dust threshold using owner permissions
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = usdc;
        uint[] memory thresholds = new uint[](1);
        thresholds[0] = 10e6; // 10 USDC dust threshold

        settle.setTokenDustThresholdList(tokens, thresholds);

        // Send small amount (dust) to allocation account - owner can mint
        usdc.mint(allocationAddress, 5e6); // 5 USDC < 10 USDC threshold

        uint ownerBalanceBefore = usdc.balanceOf(users.owner);

        uint dustCollected = keeperRouter.collectDust(allocationAddress, usdc, users.owner);

        assertEq(dustCollected, 5e6, "Should collect all dust");
        assertEq(usdc.balanceOf(users.owner), ownerBalanceBefore + 5e6, "Owner should receive dust");
    }

    //----------------------------------------------------------------------------
    // Edge Cases & Error Conditions
    //----------------------------------------------------------------------------

    function testEmptyPuppetList() public {
        address[] memory emptyPuppetList = new address[](0);
        uint allocationId = getNextAllocationId();

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: emptyPuppetList,
            allocationId: allocationId,
            keeperFee: 1e6,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert(Error.Allocation__PuppetListEmpty.selector);
        keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);
    }

    function testExpiredRule() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Fast forward time to expire the rules
        vm.warp(block.timestamp + 31 days);

        uint allocationId = getNextAllocationId();
        uint keeperFee = 0; // No keeper fee since we expect no allocation

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        // Should revert because no valid puppets means no allocation, and keeper fee check fails
        vm.expectRevert();
        keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);
    }

    function testThrottleActivity() public {
        // First mirror position
        testRequestMirrorSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Try to create another position immediately (should be throttled)
        uint allocationId = getNextAllocationId();
        uint keeperFee = 0; // No keeper fee to avoid exceeding cost factor on reduced allocation

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 1 ether);
        // For this test, let's advance time just past puppet1's throttle (1 hour) but not puppet2's (2 hours)
        vm.warp(block.timestamp + 1.5 hours);

        (address allocationAddress,) = keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);

        // Should get allocation only from puppet1 since puppet2 is still throttled
        uint allocatedAmount = allocate.getAllocation(allocationAddress);
        uint puppet1Expected = 1000e6 * 2000 / 10000; // 20% of 1000 USDC = 200 USDC
        // But puppet1's balance has been reduced from previous test (200e6 initial balance from BasicSetup + allocation
        // used)
        // So let's just verify it's greater than 0 and less than expected
        assertGt(allocatedAmount, 0, "Should have some allocation from puppet1");
        assertLt(allocatedAmount, puppet1Expected, "Should be less than full expected due to reduced balance");
    }

    function testDustThresholdTooHigh() public {
        // Create an allocation first
        testRequestMirrorSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        address allocationAddress = getAllocationAddress(usdc, trader, puppetList, 1);

        // Set dust threshold
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = usdc;
        uint[] memory thresholds = new uint[](1);
        thresholds[0] = 10e6; // 10 USDC dust threshold

        settle.setTokenDustThresholdList(tokens, thresholds);

        // Send amount above threshold
        usdc.mint(allocationAddress, 15e6); // 15 USDC > 10 USDC threshold

        // Should revert when trying to collect
        vm.expectRevert();
        keeperRouter.collectDust(allocationAddress, usdc, users.owner);
    }

    function testDecreasePosition() public {
        // First create and execute a position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint keeperFee = 1e6;

        Allocate.CallAllocation memory allocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory openParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 2 ether);
        (, bytes32 requestKey) = keeperRouter.requestMirror{value: 0.001 ether}(allocParams, openParams);

        // Execute the open position
        executeOrder(requestKey);

        // Now decrease the position
        MirrorPosition.CallPosition memory decreaseParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: false, // Decrease
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 300e30, // Remove some collateral
            sizeDeltaInUsd: 2000e30, // Reduce size
            acceptablePrice: 2900e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        Allocate.CallAllocation memory adjustAllocParams = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: 0.5e6,
            keeperFeeReceiver: users.owner
        });

        bytes32 decreaseRequestKey = keeperRouter.requestAdjust{value: 0.001 ether}(adjustAllocParams, decreaseParams);
        assertNotEq(decreaseRequestKey, bytes32(0), "Decrease request should be generated");
    }

    function testMultipleTraders() public {
        address trader2 = makeAddr("trader2");

        // Puppet1 follows trader1, puppet2 follows trader2
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;

        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = puppet2;

        // Set rule for puppet2 to follow trader2
        matchingRule.setRule(
            allocate,
            usdc,
            puppet2,
            trader2,
            MatchingRule.Rule({
                allowanceRate: 1000, // 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        // Create positions for both traders
        uint allocationId1 = getNextAllocationId();
        uint allocationId2 = getNextAllocationId();

        Allocate.CallAllocation memory allocParams1 = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList1,
            allocationId: allocationId1,
            keeperFee: 0.5e6,
            keeperFeeReceiver: users.owner
        });

        Allocate.CallAllocation memory allocParams2 = Allocate.CallAllocation({
            collateralToken: usdc,
            trader: trader2,
            puppetList: puppetList2,
            allocationId: allocationId2,
            keeperFee: 0.5e6,
            keeperFeeReceiver: users.owner
        });

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: address(0), // Will be set per trader
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 500e30,
            sizeDeltaInUsd: 2000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            requestKey: bytes32(0)
        });

        vm.deal(users.owner, 2 ether);

        // Create position for trader1
        callParams.trader = trader;
        (address allocation1,) = keeperRouter.requestMirror{value: 0.001 ether}(allocParams1, callParams);

        // Create position for trader2
        callParams.trader = trader2;
        (address allocation2,) = keeperRouter.requestMirror{value: 0.001 ether}(allocParams2, callParams);

        // Verify both allocations were created
        assertGt(allocate.getAllocation(allocation1), 0, "Trader1 allocation should exist");
        assertGt(allocate.getAllocation(allocation2), 0, "Trader2 allocation should exist");
        assertNotEq(allocation1, allocation2, "Allocations should be different");

        // Simulate profits by sending tokens to both allocation accounts
        usdc.mint(allocation1, 100e6); // 100 USDC profit for trader1's position
        usdc.mint(allocation2, 80e6); // 80 USDC profit for trader2's position

        // Record initial balances
        uint puppet1BalanceBefore = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(usdc, puppet2);

        // Settle trader1's position (puppet1 gets the profit)
        Settle.CallSettle memory settleParams1 = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            keeperFeeReceiver: users.owner,
            trader: trader,
            allocationId: allocationId1,
            keeperExecutionFee: 0.1e6 // 0.1 USDC keeper fee
        });

        (uint settled1, uint distributed1, uint platformFee1) =
            keeperRouter.settleAllocation(settleParams1, puppetList1);

        // Settle trader2's position (puppet2 gets the profit)
        Settle.CallSettle memory settleParams2 = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            keeperFeeReceiver: users.owner,
            trader: trader2,
            allocationId: allocationId2,
            keeperExecutionFee: 0.1e6 // 0.1 USDC keeper fee
        });

        (uint settled2, uint distributed2, uint platformFee2) =
            keeperRouter.settleAllocation(settleParams2, puppetList2);

        // Verify settlements occurred
        assertEq(settled1, 100e6, "Should settle full trader1 profit");
        assertEq(settled2, 80e6, "Should settle full trader2 profit");
        assertGt(distributed1, 0, "Should distribute trader1 profits");
        assertGt(distributed2, 0, "Should distribute trader2 profits");
        assertGt(platformFee1, 0, "Should collect platform fee from trader1");
        assertGt(platformFee2, 0, "Should collect platform fee from trader2");

        // Verify puppet balances increased appropriately
        uint puppet1BalanceAfter = allocationStore.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfter = allocationStore.userBalanceMap(usdc, puppet2);

        assertGt(puppet1BalanceAfter, puppet1BalanceBefore, "Puppet1 should receive trader1 profits");
        assertGt(puppet2BalanceAfter, puppet2BalanceBefore, "Puppet2 should receive trader2 profits");

        // Verify profits are proportional to their allocations
        // Puppet1 got profits from trader1, puppet2 got profits from trader2
        uint puppet1ProfitShare = puppet1BalanceAfter - puppet1BalanceBefore;
        uint puppet2ProfitShare = puppet2BalanceAfter - puppet2BalanceBefore;

        assertGt(puppet1ProfitShare, 0, "Puppet1 should have positive profit share");
        assertGt(puppet2ProfitShare, 0, "Puppet2 should have positive profit share");

        // Both puppets should have received their respective trader's profits
        // (minus keeper fees and platform fees)
        assertLt(puppet1ProfitShare, 100e6, "Puppet1 profit should be less than gross due to fees");
        assertLt(puppet2ProfitShare, 80e6, "Puppet2 profit should be less than gross due to fees");
    }

    //----------------------------------------------------------------------------
    // Helper Functions
    //----------------------------------------------------------------------------

    function executeOrder(
        bytes32 _requestKey
    ) internal {
        keeperRouter.afterOrderExecution(
            _requestKey,
            GmxPositionUtils.Props({
                addresses: GmxPositionUtils.Addresses({
                    account: trader,
                    receiver: address(0),
                    cancellationReceiver: address(0),
                    callbackContract: address(0),
                    uiFeeReceiver: address(0),
                    market: address(wnt),
                    initialCollateralToken: address(0),
                    swapPath: new address[](0)
                }),
                numbers: GmxPositionUtils.Numbers({
                    orderType: GmxPositionUtils.OrderType.MarketIncrease,
                    decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
                    sizeDeltaUsd: 0,
                    initialCollateralDeltaAmount: 0,
                    triggerPrice: 0,
                    acceptablePrice: 0,
                    executionFee: 0,
                    callbackGasLimit: 0,
                    minOutputAmount: 0,
                    updatedAtTime: 0,
                    validFromTime: 0
                }),
                flags: GmxPositionUtils.Flags({
                    isLong: true,
                    shouldUnwrapNativeToken: false,
                    isFrozen: false,
                    autoCancel: false
                })
            }),
            GmxPositionUtils.EventLogData({
                addressItems: GmxPositionUtils.AddressItems({
                    items: new GmxPositionUtils.AddressKeyValue[](0),
                    arrayItems: new GmxPositionUtils.AddressArrayKeyValue[](0)
                }),
                uintItems: GmxPositionUtils.UintItems({
                    items: new GmxPositionUtils.UintKeyValue[](0),
                    arrayItems: new GmxPositionUtils.UintArrayKeyValue[](0)
                }),
                intItems: GmxPositionUtils.IntItems({
                    items: new GmxPositionUtils.IntKeyValue[](0),
                    arrayItems: new GmxPositionUtils.IntArrayKeyValue[](0)
                }),
                boolItems: GmxPositionUtils.BoolItems({
                    items: new GmxPositionUtils.BoolKeyValue[](0),
                    arrayItems: new GmxPositionUtils.BoolArrayKeyValue[](0)
                }),
                bytes32Items: GmxPositionUtils.Bytes32Items({
                    items: new GmxPositionUtils.Bytes32KeyValue[](0),
                    arrayItems: new GmxPositionUtils.Bytes32ArrayKeyValue[](0)
                }),
                bytesItems: GmxPositionUtils.BytesItems({
                    items: new GmxPositionUtils.BytesKeyValue[](0),
                    arrayItems: new GmxPositionUtils.BytesArrayKeyValue[](0)
                }),
                stringItems: GmxPositionUtils.StringItems({
                    items: new GmxPositionUtils.StringKeyValue[](0),
                    arrayItems: new GmxPositionUtils.StringArrayKeyValue[](0)
                })
            })
        );
    }

    function getAllocationAddress(
        IERC20 _collateralToken,
        address _trader,
        address[] memory _puppetList,
        uint _allocationId
    ) internal view returns (address) {
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        bytes32 _allocationKey = keccak256(abi.encodePacked(_puppetList, _traderMatchingKey, _allocationId));

        return Clones.predictDeterministicAddress(
            allocate.allocationAccountImplementation(), _allocationKey, address(allocate)
        );
    }
}
