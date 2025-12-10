// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SequencerRouter} from "src/SequencerRouter.sol";
import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {Position} from "@gmx/contracts/position/Position.sol";
import {PositionStoreUtils} from "@gmx/contracts/position/PositionStoreUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {Error} from "src/utils/Error.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "test/mock/MockGmxExchangeRouter.t.sol";
import {MockGmxDataStore} from "test/mock/MockGmxDataStore.t.sol";

/**
 * @title TradingTest
 * @notice Test suite for position mirroring and trading operations
 * @dev Tests integration between Mirror, Settle, SequencerRouter, Subscribe, and Deposit
 * Updated to work with the decoupled Subscribe/Deposit architecture.
 */
contract TradingTest is BasicSetup {
    AccountStore allocationStore;
    AccountContract account;
    Settle settle;
    Subscribe subscribe;
    Mirror mirror;
    SequencerRouter sequencerRouter;
    MockGmxExchangeRouter mockGmxExchangeRouter;
    MockGmxDataStore mockGmxDataStore;

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

        subscribe = new Subscribe(
            dictator,
            Subscribe.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        mockGmxDataStore = new MockGmxDataStore();

        mirror = new Mirror(
            dictator,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(address(mockGmxExchangeRouter)),
                gmxDataStore: IGmxReadDataStore(address(mockGmxDataStore)),
                gmxOrderVault: address(0x1234),
                referralCode: 0x5055505045540000000000000000000000000000000000000000000000000000,
                maxPuppetList: 50,
                maxSequencerFeeToAllocationRatio: 0.1e30,
                maxSequencerFeeToAdjustmentRatio: 0.1e30,
                maxSequencerFeeToCloseRatio: 0.1e30,
                maxMatchOpenDuration: 30 seconds,
                maxMatchAdjustDuration: 60 seconds
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
            subscribe,
            mirror,
            settle,
            SequencerRouter.Config({
                matchBaseGasLimit: 1_300_853,
                matchPerPuppetGasLimit: 30_000,
                adjustBaseGasLimit: 910_663,
                adjustPerPuppetGasLimit: 3_412,
                settleBaseGasLimit: 1_300_853,
                settlePerPuppetGasLimit: 30_000,
                gasPriceBufferBasisPoints: 12000, // 120% (20% buffer)
                maxEthPriceAge: 300,
                maxIndexPriceAge: 3000,
                maxFiatPriceAge: 60_000,
                maxGasAge: 2000,
                stalledCheckInterval: 30_000,
                stalledPositionThreshold: 5 * 60 * 1000,
                minMatchTraderCollateral: 25e30,
                minAllocationUsd: 20e30,
                minAdjustUsd: 10e30
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
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(subscribe));
        dictator.setPermission(mirror, mirror.matchmake.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.adjust.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.close.selector, address(sequencerRouter));

        // Settle Contract Permissions
        dictator.setPermission(settle, settle.settle.selector, address(sequencerRouter));
        dictator.setPermission(settle, settle.collectAllocationAccountDust.selector, address(sequencerRouter));

        // Initialize contracts
        dictator.registerContract(account);
        dictator.registerContract(settle);
        dictator.registerContract(subscribe);
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
        dictator.setPermission(subscribe, subscribe.rule.selector, users.owner);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.matchmake.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.adjust.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.close.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.settleAllocation.selector, users.owner);
        dictator.setPermission(sequencerRouter, sequencerRouter.collectAllocationAccountDust.selector, users.owner);

        account.setDepositCapList(allowedTokens, allowanceCaps);

        // Setup puppet balances using owner permissions - owner deposits on behalf of puppets
        account.deposit(usdc, users.owner, puppet1, 1000e6);
        account.deposit(usdc, users.owner, puppet2, 800e6);

        // Set up trading rules using owner permissions
        subscribe.rule(
            mirror,
            usdc,
            puppet1,
            trader,
            Subscribe.RuleParams({
                allowanceRate: 2000, // 20%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        subscribe.rule(
            mirror,
            usdc,
            puppet2,
            trader,
            Subscribe.RuleParams({
                allowanceRate: 1500, // 15%
                throttleActivity: 2 hours,
                expiry: block.timestamp + 30 days
            })
        );
    }

    //----------------------------------------------------------------------------
    // Core Trading Functionality Tests
    //----------------------------------------------------------------------------

    function testRequestMatchSuccess() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // 1 USDC

        Mirror.CallParams memory callParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 1 ether);
        (address allocationAddress, bytes32 requestKey) =
            sequencerRouter.matchmake{value: 0.001 ether}(callParams, puppetList);

        // Verify allocation was created
        assertGt(mirror.allocationMap(allocationAddress), 0, "Allocation should be created");

        // Verify request was submitted to GMX
        assertNotEq(requestKey, bytes32(0), "Request key should be generated");

        // Verify sequencer fee was paid (owner had 200e6 initial balance from BasicSetup)
        assertEq(usdc.balanceOf(users.owner), 200e6 + sequencerFee, "Sequencer should receive fee");
    }

    function testRequestMatchInsufficientFunds() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 10000e6; // Excessive sequencer fee

        Mirror.CallParams memory callParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert();
        sequencerRouter.matchmake{value: 0.001 ether}(callParams, puppetList);
    }

    function testRequestAdjustSuccess() public {
        // First create an allocation and mirror position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // 1 USDC

        Mirror.CallParams memory initialCallParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 1 ether);
        (address allocationAddress,) = sequencerRouter.matchmake{value: 0.001 ether}(initialCallParams, puppetList);

        // Simulate GMX execution - mock the puppet position as existing with lastTargetSize
        uint lastTargetSize = mirror.lastTargetSizeMap(
            Position.getPositionKey(allocationAddress, address(wnt), address(usdc), true)
        );
        _mockPuppetPosition(allocationAddress, lastTargetSize);

        // Simulate trader increased their position (size increased by 50%)
        _updateTraderPosition(trader, 7500e30, 1000e6); // 7500 USD size, same collateral

        // Now test adjustment
        uint adjustSequencerFee = 0.5e6; // 0.5 USDC

        Mirror.CallParams memory adjustCallParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: adjustSequencerFee
        });

        vm.deal(users.owner, 1 ether);
        bytes32 adjustRequestKey = sequencerRouter.adjust{value: 0.001 ether}(adjustCallParams, puppetList);

        // Verify request was submitted
        assertNotEq(adjustRequestKey, bytes32(0), "Adjust request should be generated");
    }

    function testSettleSuccess() public {
        // First create allocation and position
        testRequestMatchSuccess();

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
            sequencerExecutionFee: 0.1e6,
            amount: 500e6 // The amount we minted to the allocation account
        });

        uint puppet1BalanceBefore = account.userBalanceMap(usdc, puppet1);
        uint puppet2BalanceBefore = account.userBalanceMap(usdc, puppet2);
        uint ownerFeeBalanceBefore = usdc.balanceOf(users.owner);

        (uint distributionAmount, uint platformFeeAmount) = sequencerRouter.settleAllocation(settleParams, puppetList);

        // Verify settlement occurred
        assertEq(settleParams.amount, 500e6, "Should have correct settlement amount");
        assertGt(distributionAmount, 0, "Should have distributed some amount");

        // Verify puppet balances increased
        assertGt(account.userBalanceMap(usdc, puppet1), puppet1BalanceBefore, "Puppet1 balance should increase");
        assertGt(account.userBalanceMap(usdc, puppet2), puppet2BalanceBefore, "Puppet2 balance should increase");

        // Verify platform fee was collected
        assertGt(platformFeeAmount, 0, "Platform fee should be collected");

        // Verify keeper fee paid out and total distribution matches available less fees
        uint ownerFeeBalanceAfter = usdc.balanceOf(users.owner);
        assertEq(ownerFeeBalanceAfter - ownerFeeBalanceBefore, settleParams.sequencerExecutionFee, "Keeper fee payout mismatch");

        // Allocation sum should match stored allocation map and Puppet shares
        uint[] memory puppetAllocations = mirror.getAllocationPuppetList(allocationAddress);
        uint allocationTotal = puppetAllocations[0] + puppetAllocations[1];
        assertEq(allocationTotal, mirror.allocationMap(allocationAddress), "Allocation sum mismatch");

        // Distributed amount should equal user balance delta + platform fee + keeper fee
        uint puppet1Delta = account.userBalanceMap(usdc, puppet1) - puppet1BalanceBefore;
        uint puppet2Delta = account.userBalanceMap(usdc, puppet2) - puppet2BalanceBefore;
        uint distributedTotal = puppet1Delta + puppet2Delta;
        uint accounted = distributedTotal + platformFeeAmount + settleParams.sequencerExecutionFee;
        // Allow for minor rounding dust from mulDiv
        assertTrue(accounted <= settleParams.amount, "Settlement over-accounted");
        assertLe(settleParams.amount - accounted, puppetList.length, "Settlement accounting mismatch");
    }

    function testSettleInvariantSumAllocations() public {
        testRequestMatchSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1;
        address allocationAddress = getAllocationAddress(usdc, trader, puppetList, allocationId);

        // Puppet allocations should sum to allocation map
        uint allocationMapValue = mirror.allocationMap(allocationAddress);
        uint[] memory puppetAllocations = mirror.getAllocationPuppetList(allocationAddress);
        uint sumAllocations = 0;
        for (uint i = 0; i < puppetAllocations.length; i++) {
            sumAllocations += puppetAllocations[i];
        }
        assertEq(sumAllocations, allocationMapValue, "Allocation sum mismatch");

        // After settle, distribution should not exceed settled funds (accounting for rounding)
        usdc.mint(allocationAddress, 500e6);
        Settle.CallSettle memory settleParams = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            sequencerFeeReceiver: users.owner,
            trader: trader,
            allocationId: allocationId,
            sequencerExecutionFee: 0.1e6,
            amount: 500e6
        });

        uint puppet1Before = account.userBalanceMap(usdc, puppet1);
        uint puppet2Before = account.userBalanceMap(usdc, puppet2);

        (uint distributed, uint platformFee) = sequencerRouter.settleAllocation(settleParams, puppetList);

        uint delta1 = account.userBalanceMap(usdc, puppet1) - puppet1Before;
        uint delta2 = account.userBalanceMap(usdc, puppet2) - puppet2Before;
        uint accounted = delta1 + delta2 + platformFee + settleParams.sequencerExecutionFee;
        assertTrue(accounted <= settleParams.amount, "Post-settle over-account");
        assertLe(settleParams.amount - accounted, puppetList.length, "Post-settle dust exceeds tolerance");
    }

    function testSetRuleExpiryTooSoonReverts() public {
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        uint shortExpiry = block.timestamp + 10 minutes;

        vm.expectRevert(abi.encodeWithSelector(Error.Subscribe__InvalidExpiryDuration.selector, subscribe.getConfig().minExpiryDuration));
        subscribe.rule(
            mirror,
            usdc,
            puppet1,
            trader,
            Subscribe.RuleParams({allowanceRate: 2000, throttleActivity: 1 hours, expiry: shortExpiry})
        );
    }


    function testCollectDust() public {
        // Create an allocation first
        testRequestMatchSuccess();

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

        uint dustCollected = sequencerRouter.collectAllocationAccountDust(allocationAddress, usdc, users.owner, 5e6);

        assertEq(dustCollected, 5e6, "Should collect all dust");
        assertEq(usdc.balanceOf(users.owner), ownerBalanceBefore + 5e6, "Owner should receive dust");
    }

    //----------------------------------------------------------------------------
    // Edge Cases & Error Conditions
    //----------------------------------------------------------------------------

    function testEmptyPuppetList() public {
        address[] memory emptyPuppetList = new address[](0);
        uint allocationId = getNextAllocationId();

        Mirror.CallParams memory callParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: 1e6
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert(Error.Mirror__PuppetListEmpty.selector);
        sequencerRouter.matchmake{value: 0.001 ether}(callParams, emptyPuppetList);
    }

    function testExpiredRule() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Fast forward time to expire the rules
        vm.warp(block.timestamp + 31 days);

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6; // Non-zero sequencer fee

        Mirror.CallParams memory callParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 1 ether);
        // Should revert because no valid puppets means no allocation, and sequencer fee check fails
        vm.expectRevert();
        sequencerRouter.matchmake{value: 0.001 ether}(callParams, puppetList);
    }

    function testThrottleActivity() public {
        // First mirror position
        testRequestMatchSuccess();

        // For this test, let's advance time just past puppet1's throttle (1 hour) but not puppet2's (2 hours)
        vm.warp(block.timestamp + 1.5 hours);

        // Sequencer should only include active (non-throttled) puppets
        // puppet2 is still throttled (2 hour throttle), so only puppet1 is included
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 0.01e6; // Small sequencer fee

        Mirror.CallParams memory callParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 1 ether);

        (address allocationAddress,) = sequencerRouter.matchmake{value: 0.001 ether}(callParams, puppetList);

        // Should get allocation only from puppet1
        uint allocatedAmount = mirror.allocationMap(allocationAddress);
        uint puppet1Expected = 1000e6 * 2000 / 10000; // 20% of 1000 USDC = 200 USDC
        // But puppet1's balance has been reduced from previous test
        // So let's just verify it's greater than 0 and less than expected
        assertGt(allocatedAmount, 0, "Should have some allocation from puppet1");
        assertLt(allocatedAmount, puppet1Expected, "Should be less than full expected due to reduced balance");
    }

    function testDustThresholdTooHigh() public {
        // Create an allocation first
        testRequestMatchSuccess();

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
        sequencerRouter.collectAllocationAccountDust(allocationAddress, usdc, users.owner, 15e6);
    }

    function testDecreasePosition() public {
        // First create and execute a position
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint sequencerFee = 1e6;

        Mirror.CallParams memory openParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: sequencerFee
        });

        vm.deal(users.owner, 2 ether);
        (address allocationAddress,) = sequencerRouter.matchmake{value: 0.001 ether}(openParams, puppetList);

        // Simulate GMX execution - mock the puppet position as existing with lastTargetSize
        uint lastTargetSize = mirror.lastTargetSizeMap(
            Position.getPositionKey(allocationAddress, address(wnt), address(usdc), true)
        );
        _mockPuppetPosition(allocationAddress, lastTargetSize);

        // Simulate trader decreased their position (size decreased by 50%)
        _updateTraderPosition(trader, 2500e30, 1000e6); // 2500 USD size, same collateral

        Mirror.CallParams memory decreaseParams = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId,
            sequencerFee: 0.5e6
        });

        bytes32 decreaseRequestKey = sequencerRouter.adjust{value: 0.001 ether}(decreaseParams, puppetList);
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
        subscribe.rule(
            mirror,
            usdc,
            puppet2,
            trader2,
            Subscribe.RuleParams({
                allowanceRate: 1000, // 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        // Create positions for both traders
        uint allocationId1 = getNextAllocationId();
        uint allocationId2 = getNextAllocationId();

        Mirror.CallParams memory callParams1 = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId1,
            sequencerFee: 0.5e6
        });

        Mirror.CallParams memory callParams2 = Mirror.CallParams({
            collateralToken: usdc,
            trader: trader2,
            market: address(wnt),
            sequencerFeeReceiver: users.owner,
            isLong: true,
            executionFee: 0.001 ether,
            allocationId: allocationId2,
            sequencerFee: 0.5e6
        });

        vm.deal(users.owner, 2 ether);

        // Create position for trader1
        (address allocation1,) = sequencerRouter.matchmake{value: 0.001 ether}(callParams1, puppetList1);

        // Create position for trader2
        (address allocation2,) = sequencerRouter.matchmake{value: 0.001 ether}(callParams2, puppetList2);

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
            sequencerExecutionFee: 0.1e6, // 0.1 USDC sequencer fee
            amount: 100e6 // The profit amount to settle (100 USDC)
        });

        (uint distributed1, uint platformFee1) = sequencerRouter.settleAllocation(settleParams1, puppetList1);

        // Settle trader2's position (puppet2 gets the profit)
        Settle.CallSettle memory settleParams2 = Settle.CallSettle({
            collateralToken: usdc,
            distributionToken: usdc,
            sequencerFeeReceiver: users.owner,
            trader: trader2,
            allocationId: allocationId2,
            sequencerExecutionFee: 0.1e6, // 0.1 USDC sequencer fee
            amount: 80e6 // The profit amount to settle (80 USDC)
        });

        (uint distributed2, uint platformFee2) = sequencerRouter.settleAllocation(settleParams2, puppetList2);

        // Verify settlements occurred
        assertEq(settleParams1.amount, 100e6, "Should settle full trader1 profit");
        assertEq(settleParams2.amount, 80e6, "Should settle full trader2 profit");
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
        bytes32 traderPositionKey = Position.getPositionKey(_trader, address(wnt), address(usdc), true);

        bytes32 sizeInUsdKey = keccak256(abi.encode(traderPositionKey, PositionStoreUtils.SIZE_IN_USD));
        mockGmxDataStore.setUint(sizeInUsdKey, 5000e30); // 5000 USD position

        bytes32 collateralKey = keccak256(abi.encode(traderPositionKey, PositionStoreUtils.COLLATERAL_AMOUNT));
        mockGmxDataStore.setUint(collateralKey, 1000e6); // 1000 USDC collateral (6 decimals)
    }

    /**
     * @notice Helper function to mock a puppet allocation position after GMX execution
     * @param _allocationAddress The allocation account address
     * @param _sizeInUsd The position size in USD
     */
    function _mockPuppetPosition(address _allocationAddress, uint _sizeInUsd) internal {
        bytes32 puppetPositionKey = Position.getPositionKey(_allocationAddress, address(wnt), address(usdc), true);

        bytes32 sizeInUsdKey = keccak256(abi.encode(puppetPositionKey, PositionStoreUtils.SIZE_IN_USD));
        mockGmxDataStore.setUint(sizeInUsdKey, _sizeInUsd);
    }

    /**
     * @notice Helper function to update a trader's position (simulate position change on GMX)
     * @param _trader The trader address
     * @param _newSizeInUsd New position size in USD
     * @param _newCollateral New collateral amount
     */
    function _updateTraderPosition(address _trader, uint _newSizeInUsd, uint _newCollateral) internal {
        bytes32 traderPositionKey = Position.getPositionKey(_trader, address(wnt), address(usdc), true);

        bytes32 sizeInUsdKey = keccak256(abi.encode(traderPositionKey, PositionStoreUtils.SIZE_IN_USD));
        mockGmxDataStore.setUint(sizeInUsdKey, _newSizeInUsd);

        bytes32 collateralKey = keccak256(abi.encode(traderPositionKey, PositionStoreUtils.COLLATERAL_AMOUNT));
        mockGmxDataStore.setUint(collateralKey, _newCollateral);
    }
}
