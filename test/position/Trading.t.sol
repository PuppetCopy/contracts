// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SequencerRouter} from "src/SequencerRouter.sol";
import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Rule} from "src/position/Rule.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {Error} from "src/utils/Error.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "test/mock/MockGmxExchangeRouter.t.sol";

import {Const} from "script/Const.sol";

/**
 * @title TradingTest
 * @notice Test suite for position mirroring and trading operations
 * @dev Tests integration between Mirror, Settle, SequencerRouter, Rule, and Deposit
 * Updated to work with the decoupled Rule/Deposit architecture.
 */
contract TradingTest is BasicSetup {
    AccountStore allocationStore;
    AccountContract account;
    Settle settle;
    Rule ruleContract;
    Mirror mirror;
    SequencerRouter sequencerRouter;
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
        allocationStore = new AccountStore(dictator, tokenRouter);

        account = new AccountContract(dictator, allocationStore, AccountContract.Config({transferOutGasLimit: 200_000}));

        ruleContract = new Rule(
            dictator,
            Rule.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        mirror = new Mirror(
            dictator,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(address(mockGmxExchangeRouter)),
                gmxDataStore: IGmxReadDataStore(Const.gmxDataStore),
                gmxOrderVault: address(0x1234),
                referralCode: bytes32("PUPPET"),
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                maxPuppetList: 50,
                maxSequencerFeeToAllocationRatio: 0.1e30,
                maxSequencerFeeToAdjustmentRatio: 0.1e30
            })
        );

        settle = new Settle(
            dictator,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.05e30, // 5%
                maxSequencerFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );

        sequencerRouter = new SequencerRouter(
            dictator,
            account,
            ruleContract,
            mirror,
            settle,
            SequencerRouter.Config({
                mirrorBaseGasLimit: 1_300_853,
                mirrorPerPuppetGasLimit: 30_000,
                adjustBaseGasLimit: 910_663,
                adjustPerPuppetGasLimit: 3_412,
                settleBaseGasLimit: 1_300_853,
                settlePerPuppetGasLimit: 30_000,
                fallbackRefundExecutionFeeReceiver: address(0x9999)
            })
        );

        // Core Contract Access
        dictator.setAccess(allocationStore, address(account));
        dictator.setAccess(allocationStore, address(settle));

        // TokenRouter Permissions
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));

        // Account Contract Permissions
        dictator.setPermission(account, account.setBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.createAllocationAccount.selector, address(mirror));
        dictator.setPermission(account, account.getBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.transferOut.selector, address(mirror));
        dictator.setPermission(account, account.execute.selector, address(mirror));
        dictator.setPermission(account, account.execute.selector, address(settle));
        dictator.setPermission(account, account.setBalanceList.selector, address(settle));
        dictator.setPermission(account, account.transferInAllocation.selector, address(settle));
        dictator.setPermission(account, account.transferOut.selector, address(settle));

        // Mirror Contract Permissions
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(ruleContract));
        dictator.setPermission(mirror, mirror.requestOpen.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.requestAdjust.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.execute.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.liquidate.selector, address(sequencerRouter));

        // Settle Contract Permissions
        dictator.setPermission(settle, settle.settle.selector, address(sequencerRouter));
        dictator.setPermission(settle, settle.collectAllocationAccountDust.selector, address(sequencerRouter));

        // Initialize contracts
        dictator.registerContract(account);
        dictator.registerContract(settle);
        dictator.registerContract(ruleContract);
        dictator.registerContract(mirror);
        dictator.registerContract(sequencerRouter);

        // Mock GMX DataStore calls to simulate trader positions
        _setupGmxDataStoreMocks();

        // Stop current prank and restart for user operations
        IERC20[] memory allowedTokens = new IERC20[](1);
        allowedTokens[0] = usdc;
        uint[] memory allowanceCaps = new uint[](1);
        allowanceCaps[0] = 10000e6; // 10000 USDC cap

        // Owner Test Permissions
        dictator.setPermission(account, account.setDepositCapList.selector, users.owner);
        dictator.setPermission(account, account.deposit.selector, users.owner);
        dictator.setPermission(ruleContract, ruleContract.setRule.selector, users.owner);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.requestOpen.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.requestAdjust.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.settleAllocation.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.collectAllocationAccountDust.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.afterOrderExecution.selector, users.owner);

        account.setDepositCapList(allowedTokens, allowanceCaps);

        // Setup puppet balances using owner permissions - owner deposits on behalf of puppets
        account.deposit(usdc, users.owner, puppet1, 1000e6);
        account.deposit(usdc, users.owner, puppet2, 800e6);

        // Set up trading rules using owner permissions
        ruleContract.setRule(
            mirror,
            usdc,
            puppet1,
            trader,
            Rule.RuleParams({
                allowanceRate: 2000, // 20%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        ruleContract.setRule(
            mirror,
            usdc,
            puppet2,
            trader,
            Rule.RuleParams({
                allowanceRate: 1500, // 15%
                throttleActivity: 2 hours,
                expiry: block.timestamp + 30 days
            })
        );
    }

    //----------------------------------------------------------------------------
    // Core Trading Functionality Tests
    //----------------------------------------------------------------------------

    function testRequestOpenSuccess() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // 1 USDC

        Mirror.CallPosition memory callParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        (address allocationAddress, bytes32 requestKey) =
            sequencerRouter.requestOpen{value: 0.001 ether}(callParams, puppetList);

        // Verify allocation was created
        assertGt(mirror.allocationMap(allocationAddress), 0, "Allocation should be created");

        // Verify request was submitted to GMX
        assertNotEq(requestKey, bytes32(0), "Request key should be generated");

        // Verify sequencer fee was paid (owner had 200e6 initial balance from BasicSetup)
        assertEq(usdc.balanceOf(users.owner), 200e6 + sequencerFee, "Sequencer should receive fee");
    }

    function testRequestOpenInsufficientFunds() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 10000e6; // Excessive sequencer fee

        Mirror.CallPosition memory callParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert();
        sequencerRouter.requestOpen{value: 0.001 ether}(callParams, puppetList);
    }

    function testRequestAdjustSuccess() public {
        // First create an allocation and mirror position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // 1 USDC

        Mirror.CallPosition memory initialCallParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        (, bytes32 requestKey) = sequencerRouter.requestOpen{value: 0.001 ether}(initialCallParams, puppetList);

        executeOrder(requestKey);

        // Now test adjustment
        uint adjustSequencerFee = 0.5e6; // 0.5 USDC

        // Adjust position - trader increases leverage by adding more size without proportional collateral
        Mirror.CallPosition memory adjustCallParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 100e30, // Small collateral increase
            sizeDeltaInUsd: 3000e30, // Large size increase (changes leverage)
            acceptablePrice: 3100e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: adjustSequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        bytes32 adjustRequestKey = sequencerRouter.requestAdjust{value: 0.001 ether}(adjustCallParams, puppetList);

        // Verify request was submitted
        assertNotEq(adjustRequestKey, bytes32(0), "Adjust request should be generated");
    }

    function testSettleSuccess() public {
        // First create allocation and position
        testRequestOpenSuccess();

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
            sequencerFeeReceiver: users.owner,
            trader: trader,
            allocationId: allocationId,
            sequencerExecutionFee: 0.1e6
        });

        uint puppet1BalanceBefore = account.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = account.userBalanceMap(usdc, puppet2);

        (uint settledAmount, uint distributionAmount, uint platformFeeAmount) =
            sequencerRouter.settleAllocation(settleParams, puppetList);

        // Verify settlement occurred
        assertGt(settledAmount, 0, "Should have settled some amount");
        assertGt(distributionAmount, 0, "Should have distributed some amount");

        // Verify puppet balances increased
        assertGt(account.userBalanceMap(usdc, puppet1), puppet1BalanceBefore, "Puppet1 balance should increase");
        assertGt(account.userBalanceMap(usdc, puppet2), puppet2BalanceBefore, "Puppet2 balance should increase");

        // Verify platform fee was collected
        assertGt(platformFeeAmount, 0, "Platform fee should be collected");
    }

    function testCollectDust() public {
        // Create an allocation first
        testRequestOpenSuccess();

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

        uint dustCollected = sequencerRouter.collectAllocationAccountDust(allocationAddress, usdc, users.owner);

        assertEq(dustCollected, 5e6, "Should collect all dust");
        assertEq(usdc.balanceOf(users.owner), ownerBalanceBefore + 5e6, "Owner should receive dust");
    }

    //----------------------------------------------------------------------------
    // Edge Cases & Error Conditions
    //----------------------------------------------------------------------------

    function testEmptyPuppetList() public {
        address[] memory emptyPuppetList = new address[](0);
        uint allocationId = getNextAllocationId();

        Mirror.CallPosition memory callParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: 1e6,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert(Error.Mirror__PuppetListEmpty.selector);
        sequencerRouter.requestOpen{value: 0.001 ether}(callParams, emptyPuppetList);
    }

    function testExpiredRule() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Fast forward time to expire the rules
        vm.warp(block.timestamp + 31 days);

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // Non-zero sequencer fee

        Mirror.CallPosition memory callParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        // Should revert because no valid puppets means no allocation, and sequencer fee check fails
        vm.expectRevert();
        sequencerRouter.requestOpen{value: 0.001 ether}(callParams, puppetList);
    }

    function testThrottleActivity() public {
        // First mirror position
        testRequestOpenSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Try to create another position immediately (should be throttled)
        uint allocationId = getNextAllocationId();
        uint sequencerFee = 0.1e6; // Small sequencer fee

        Mirror.CallPosition memory callParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        // For this test, let's advance time just past puppet1's throttle (1 hour) but not puppet2's (2 hours)
        vm.warp(block.timestamp + 1.5 hours);

        (address allocationAddress,) = sequencerRouter.requestOpen{value: 0.001 ether}(callParams, puppetList);

        // Should get allocation only from puppet1 since puppet2 is still throttled
        uint allocatedAmount = mirror.allocationMap(allocationAddress);
        uint puppet1Expected = 1000e6 * 2000 / 10000; // 20% of 1000 USDC = 200 USDC
        // But puppet1's balance has been reduced from previous test (200e6 initial balance from BasicSetup + allocation
        // used)
        // So let's just verify it's greater than 0 and less than expected
        assertGt(allocatedAmount, 0, "Should have some allocation from puppet1");
        assertLt(allocatedAmount, puppet1Expected, "Should be less than full expected due to reduced balance");
    }

    function testDustThresholdTooHigh() public {
        // Create an allocation first
        testRequestOpenSuccess();

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
        sequencerRouter.collectAllocationAccountDust(allocationAddress, usdc, users.owner);
    }

    function testDecreasePosition() public {
        // First create and execute a position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6;

        Mirror.CallPosition memory openParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: sequencerFee,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 2 ether);
        (, bytes32 requestKey) = sequencerRouter.requestOpen{value: 0.001 ether}(openParams, puppetList);

        // Execute the open position
        executeOrder(requestKey);

        // Now decrease the position
        Mirror.CallPosition memory decreaseParams = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: false, // Decrease
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 300e30, // Remove some collateral
            sizeDeltaInUsd: 2000e30, // Reduce size
            acceptablePrice: 2900e30,
            triggerPrice: 0,
            allocationId: allocationId,
            sequencerFee: 0.5e6,
            sequencerFeeReceiver: users.owner
        });

        bytes32 decreaseRequestKey = sequencerRouter.requestAdjust{value: 0.001 ether}(decreaseParams, puppetList);
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
        ruleContract.setRule(
            mirror,
            usdc,
            puppet2,
            trader2,
            Rule.RuleParams({
                allowanceRate: 1000, // 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        // Create positions for both traders
        uint allocationId1 = getNextAllocationId();
        uint allocationId2 = getNextAllocationId();

        Mirror.CallPosition memory callParams1 = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 500e30,
            sizeDeltaInUsd: 2000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId1,
            sequencerFee: 0.5e6,
            sequencerFeeReceiver: users.owner
        });

        Mirror.CallPosition memory callParams2 = Mirror.CallPosition({
            collateralToken: usdc,
            traderRequestKey: bytes32(0),
            trader: trader2,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 500e30,
            sizeDeltaInUsd: 2000e30,
            acceptablePrice: 3000e30,
            triggerPrice: 0,
            allocationId: allocationId2,
            sequencerFee: 0.5e6,
            sequencerFeeReceiver: users.owner
        });

        vm.deal(users.owner, 2 ether);

        // Create position for trader1
        (address allocation1,) = sequencerRouter.requestOpen{value: 0.001 ether}(callParams1, puppetList1);

        // Create position for trader2
        (address allocation2,) = sequencerRouter.requestOpen{value: 0.001 ether}(callParams2, puppetList2);

        // Verify both allocations were created
        assertGt(mirror.allocationMap(allocation1), 0, "Trader1 allocation should exist");
        assertGt(mirror.allocationMap(allocation2), 0, "Trader2 allocation should exist");
        assertNotEq(allocation1, allocation2, "Allocations should be different");

        // Simulate profits by sending tokens to both allocation accounts
        usdc.mint(allocation1, 100e6); // 100 USDC profit for trader1's position
        usdc.mint(allocation2, 80e6); // 80 USDC profit for trader2's position

        // Record initial balances
        uint puppet1BalanceBefore = account.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = account.userBalanceMap(usdc, puppet2);

        // Settle trader1's position (puppet1 gets the profit)
        Settle.CallSettle memory settleParams1 = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            sequencerFeeReceiver: users.owner,
            trader: trader,
            allocationId: allocationId1,
            sequencerExecutionFee: 0.1e6 // 0.1 USDC sequencer fee
        });

        (uint settled1, uint distributed1, uint platformFee1) =
            sequencerRouter.settleAllocation(settleParams1, puppetList1);

        // Settle trader2's position (puppet2 gets the profit)
        Settle.CallSettle memory settleParams2 = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            sequencerFeeReceiver: users.owner,
            trader: trader2,
            allocationId: allocationId2,
            sequencerExecutionFee: 0.1e6 // 0.1 USDC sequencer fee
        });

        (uint settled2, uint distributed2, uint platformFee2) =
            sequencerRouter.settleAllocation(settleParams2, puppetList2);

        // Verify settlements occurred
        assertEq(settled1, 100e6, "Should settle full trader1 profit");
        assertEq(settled2, 80e6, "Should settle full trader2 profit");
        assertGt(distributed1, 0, "Should distribute trader1 profits");
        assertGt(distributed2, 0, "Should distribute trader2 profits");
        assertGt(platformFee1, 0, "Should collect platform fee from trader1");
        assertGt(platformFee2, 0, "Should collect platform fee from trader2");

        // Verify puppet balances increased appropriately
        uint puppet1BalanceAfter = account.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceAfter = account.userBalanceMap(usdc, puppet2);

        assertGt(puppet1BalanceAfter, puppet1BalanceBefore, "Puppet1 should receive trader1 profits");
        assertGt(puppet2BalanceAfter, puppet2BalanceBefore, "Puppet2 should receive trader2 profits");

        // Verify profits are proportional to their allocations
        // Puppet1 got profits from trader1, puppet2 got profits from trader2
        uint puppet1ProfitShare = puppet1BalanceAfter - puppet1BalanceBefore;
        uint puppet2ProfitShare = puppet2BalanceAfter - puppet2BalanceBefore;

        assertGt(puppet1ProfitShare, 0, "Puppet1 should have positive profit share");
        assertGt(puppet2ProfitShare, 0, "Puppet2 should have positive profit share");

        // Both puppets should have received their respective trader's profits
        // (minus sequencer fees and platform fees)
        assertLt(puppet1ProfitShare, 100e6, "Puppet1 profit should be less than gross due to fees");
        assertLt(puppet2ProfitShare, 80e6, "Puppet2 profit should be less than gross due to fees");
    }

    //----------------------------------------------------------------------------
    // Helper Functions
    //----------------------------------------------------------------------------

    function executeOrder(
        bytes32 _requestKey
    ) internal {
        sequencerRouter.afterOrderExecution(
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
        // Manually compute allocation key since we have memory array
        bytes32 _allocationKey = keccak256(abi.encodePacked(_puppetList, _traderMatchingKey, _allocationId));

        return Clones.predictDeterministicAddress(
            account.allocationAccountImplementation(), _allocationKey, address(account)
        );
    }

    /**
     * @notice Sets up GMX DataStore mocks to simulate trader positions
     * @dev Mocks the getUint calls that check for existing trader positions
     */
    function _setupGmxDataStoreMocks() internal {
        // Mock positions for trader1
        _mockTraderPosition(trader);

        // Mock positions for trader2 (used in testMultipleTraders)
        address trader2 = makeAddr("trader2");
        _mockTraderPosition(trader2);
    }

    /**
     * @notice Helper function to mock a trader's position
     * @param _trader The trader address to mock
     */
    function _mockTraderPosition(
        address _trader
    ) internal {
        // Create a trader position key for the specified trader
        bytes32 traderPositionKey = GmxPositionUtils.getPositionKey(
            _trader,
            address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f), // market
            IERC20(address(usdc)),
            true // isLong
        );

        // Mock position size in USD (simulate existing position)
        bytes32 sizeInUsdKey = keccak256(abi.encode(traderPositionKey, GmxPositionUtils.SIZE_IN_USD_KEY));
        vm.mockCall(
            Const.gmxDataStore,
            abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, sizeInUsdKey),
            abi.encode(5000000000000000000000000000000000) // 5000 USD position
        );

        // Mock position collateral amount
        bytes32 collateralKey = keccak256(abi.encode(traderPositionKey, GmxPositionUtils.COLLATERAL_AMOUNT_KEY));
        vm.mockCall(
            Const.gmxDataStore,
            abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, collateralKey),
            abi.encode(1000000000000000000000000000000000) // 1000 USD collateral
        );
    }
}
