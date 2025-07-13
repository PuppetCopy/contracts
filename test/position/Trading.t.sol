// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KeeperRouter} from "src/keeperRouter.sol";
import {Allocation} from "src/position/Allocation.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
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
    Allocation allocation;
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

        allocation = new Allocation(
            dictator,
            allocationStore,
            Allocation.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.05e30, // 5%
                maxKeeperFeeToCollectDustRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.1e30, // 10%
                gmxOrderVault: address(0x1234), // Mock GMX OrderVault
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
                refundExecutionFeeReceiver: address(0x9999)
            })
        );

        keeperRouter = new KeeperRouter(dictator, mirrorPosition, matchingRule, allocation);

        // Set up permissions for owner to act on behalf of users
        dictator.setAccess(allocationStore, address(allocation));
        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));

        // TokenRouter permissions for stores
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));

        // MatchingRule needs permission to call allocation functions
        dictator.setPermission(allocation, allocation.initializeTraderActivityThrottle.selector, address(matchingRule));

        // KeeperRouter needs permission to call allocation and mirrorPosition functions
        dictator.setPermission(allocation, allocation.createAllocation.selector, address(keeperRouter));
        dictator.setPermission(allocation, allocation.collectKeeperFee.selector, address(keeperRouter));
        dictator.setPermission(allocation, allocation.settle.selector, address(keeperRouter));
        dictator.setPermission(allocation, allocation.collectDust.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, address(keeperRouter));

        // Initialize contracts
        dictator.initContract(allocation);
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
        dictator.setPermission(allocation, allocation.setTokenDustThresholdList.selector, users.owner);

        dictator.setPermission(keeperRouter, keeperRouter.requestMirror.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.settle.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, users.owner);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, users.owner);

        // Owner permissions to act on behalf of users
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, users.owner);
        dictator.setPermission(matchingRule, matchingRule.setRule.selector, users.owner);

        // Setup puppet balances using owner permissions - owner deposits on behalf of puppets
        matchingRule.deposit(usdc, users.owner, puppet1, 1000e6);
        matchingRule.deposit(usdc, users.owner, puppet2, 800e6);

        // Set up trading rules using owner permissions
        matchingRule.setRule(
            allocation,
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
            allocation,
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

        Allocation.CallAllocation memory allocParams = Allocation.CallAllocation({
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
            triggerPrice: 0
        });

        vm.deal(users.owner, 1 ether);
        (address allocationAddress, bytes32 requestKey) =
            keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);

        // Verify allocation was created
        assertGt(allocation.getAllocation(allocationAddress), 0, "Allocation should be created");

        // Verify request was submitted to GMX
        assertNotEq(requestKey, bytes32(0), "Request key should be generated");

        // Verify keeper fee was paid
        assertEq(usdc.balanceOf(users.owner), keeperFee, "Keeper should receive fee");
    }

    function testRequestMirrorInsufficientFunds() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = getNextAllocationId();
        uint keeperFee = 10000e6; // Excessive keeper fee

        Allocation.CallAllocation memory allocParams = Allocation.CallAllocation({
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
            triggerPrice: 0
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert();
        keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);
    }

    function testRequestAdjustSuccess() public {
        // First create an allocation
        testRequestMirrorSuccess();

        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1; // From the previous test
        uint keeperFee = 0.5e6; // 0.5 USDC

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: usdc,
            trader: trader,
            market: address(wnt),
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 500e30,
            sizeDeltaInUsd: 2500e30,
            acceptablePrice: 3100e30,
            triggerPrice: 0
        });

        Allocation.CallAllocation memory allocParams = Allocation.CallAllocation({
            collateralToken: usdc,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: users.owner
        });

        vm.deal(users.owner, 1 ether);
        bytes32 requestKey = keeperRouter.requestAdjust{value: 0.001 ether}(callParams, allocParams);

        // Verify request was submitted
        assertNotEq(requestKey, bytes32(0), "Adjust request should be generated");
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

        Allocation.CallSettle memory settleParams = Allocation.CallSettle({
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
            keeperRouter.settle(settleParams, puppetList);

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

        allocation.setTokenDustThresholdList(tokens, thresholds);

        // Send small amount (dust) to allocation account - owner can mint
        usdc.mint(allocationAddress, 5e6); // 5 USDC < 10 USDC threshold

        uint keeperBalanceBefore = usdc.balanceOf(users.owner);

        uint dustCollected = keeperRouter.collectDust(allocationAddress, usdc, users.owner);

        assertEq(dustCollected, 5e6, "Should collect all dust");
        assertEq(usdc.balanceOf(users.owner), keeperBalanceBefore + 5e6, "Keeper should receive dust");
    }

    //----------------------------------------------------------------------------
    // Edge Cases & Error Conditions
    //----------------------------------------------------------------------------

    function testEmptyPuppetList() public {
        address[] memory emptyPuppetList = new address[](0);
        uint allocationId = getNextAllocationId();

        Allocation.CallAllocation memory allocParams = Allocation.CallAllocation({
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
            triggerPrice: 0
        });

        vm.deal(users.owner, 1 ether);
        vm.expectRevert(Error.Allocation__PuppetListEmpty.selector);
        keeperRouter.requestMirror{value: 0.001 ether}(allocParams, callParams);
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
        bytes32 _allocationKey = keccak256(abi.encodePacked(_puppetList, _traderMatchingKey, _allocationId));

        return Clones.predictDeterministicAddress(
            allocation.allocationAccountImplementation(), _allocationKey, address(allocation)
        );
    }
}
