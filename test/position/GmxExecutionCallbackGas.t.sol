// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {GmxExecutionCallback} from "src/position/GmxExecutionCallback.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockGmxExchangeRouter} from "test/mock/MockGmxExchangeRouter.sol";
import {Const} from "script/Const.sol";

contract GmxExecutionCallbackGasTest is Test {
    GmxExecutionCallback gmxExecutionCallback;
    MirrorPosition mirrorPosition;
    Dictatorship dictator;
    TokenRouter tokenRouter;
    AllocationStore allocationStore;
    MockERC20 usdc;
    MockGmxExchangeRouter mockGmxRouter;

    address owner = makeAddr("owner");
    address gmxOrderHandler = makeAddr("gmxOrderHandler");
    address trader = makeAddr("trader");

    // Storage variables to avoid stack too deep
    GmxPositionUtils.EventLogData emptyEventData;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy basic infrastructure
        dictator = new Dictatorship(owner);
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config(200_000));
        dictator.initContract(tokenRouter);
        usdc = new MockERC20("USDC", "USDC", 6);
        mockGmxRouter = new MockGmxExchangeRouter();
        
        // Deploy AllocationStore
        allocationStore = new AllocationStore(dictator, tokenRouter);
        
        // Deploy MirrorPosition first with placeholder callback handler
        address placeholderCallback = address(0x1236);
        mirrorPosition = new MirrorPosition(
            dictator,
            allocationStore,
            MirrorPosition.Config({
                gmxExchangeRouter: IGmxExchangeRouter(address(mockGmxRouter)),
                callbackHandler: placeholderCallback,
                gmxOrderVault: address(0x1235),
                referralCode: bytes32("TEST"),
                increaseCallbackGasLimit: 2_000_000,
                decreaseCallbackGasLimit: 2_000_000,
                platformSettleFeeFactor: 0.1e30,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30,
                maxKeeperFeeToAdjustmentRatio: 0.1e30,
                maxKeeperFeeToCollectDustRatio: 0.1e30
            })
        );

        // Deploy GmxExecutionCallback
        gmxExecutionCallback = new GmxExecutionCallback(
            dictator,
            GmxExecutionCallback.Config({
                mirrorPosition: mirrorPosition,
                refundExecutionFeeReceiver: owner
            })
        );

        // Register the callback with the dictator to allow logging
        dictator.initContract(gmxExecutionCallback);

        // Set up permissions for the callback to be called by gmxOrderHandler
        dictator.setPermission(
            gmxExecutionCallback,
            gmxExecutionCallback.afterOrderExecution.selector,
            gmxOrderHandler
        );
        dictator.setPermission(
            gmxExecutionCallback,
            gmxExecutionCallback.afterOrderCancellation.selector,
            gmxOrderHandler
        );
        dictator.setPermission(
            gmxExecutionCallback,
            gmxExecutionCallback.afterOrderFrozen.selector,
            gmxOrderHandler
        );
        dictator.setPermission(
            gmxExecutionCallback,
            gmxExecutionCallback.refundExecutionFee.selector,
            gmxOrderHandler
        );

        // Allow mirrorPosition to be called by the callback
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.execute.selector,
            address(gmxExecutionCallback)
        );
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.liquidate.selector,
            address(gmxExecutionCallback)
        );

        // Initialize empty event data in storage
        _initEmptyEventData();

        vm.stopPrank();
    }

    function _initEmptyEventData() internal {
        // Initialize all empty arrays for EventLogData
        emptyEventData.addressItems.items = new GmxPositionUtils.AddressKeyValue[](0);
        emptyEventData.addressItems.arrayItems = new GmxPositionUtils.AddressArrayKeyValue[](0);
        emptyEventData.uintItems.items = new GmxPositionUtils.UintKeyValue[](0);
        emptyEventData.uintItems.arrayItems = new GmxPositionUtils.UintArrayKeyValue[](0);
        emptyEventData.intItems.items = new GmxPositionUtils.IntKeyValue[](0);
        emptyEventData.intItems.arrayItems = new GmxPositionUtils.IntArrayKeyValue[](0);
        emptyEventData.boolItems.items = new GmxPositionUtils.BoolKeyValue[](0);
        emptyEventData.boolItems.arrayItems = new GmxPositionUtils.BoolArrayKeyValue[](0);
        emptyEventData.bytes32Items.items = new GmxPositionUtils.Bytes32KeyValue[](0);
        emptyEventData.bytes32Items.arrayItems = new GmxPositionUtils.Bytes32ArrayKeyValue[](0);
        emptyEventData.bytesItems.items = new GmxPositionUtils.BytesKeyValue[](0);
        emptyEventData.bytesItems.arrayItems = new GmxPositionUtils.BytesArrayKeyValue[](0);
        emptyEventData.stringItems.items = new GmxPositionUtils.StringKeyValue[](0);
        emptyEventData.stringItems.arrayItems = new GmxPositionUtils.StringArrayKeyValue[](0);
    }

    function createMockOrder(GmxPositionUtils.OrderType orderType) internal view returns (GmxPositionUtils.Props memory order) {
        order.addresses.account = address(0x1001);
        order.addresses.receiver = address(0x1002);
        order.addresses.cancellationReceiver = address(0x1002);
        order.addresses.callbackContract = address(0x1003);
        order.addresses.uiFeeReceiver = address(0);
        order.addresses.market = address(0x1004);
        order.addresses.initialCollateralToken = address(usdc);
        order.addresses.swapPath = new address[](0);

        order.numbers.orderType = orderType;
        order.numbers.decreasePositionSwapType = GmxPositionUtils.DecreasePositionSwapType.NoSwap;
        order.numbers.sizeDeltaUsd = 1000e30;
        order.numbers.initialCollateralDeltaAmount = 100e6;
        order.numbers.triggerPrice = 0;
        order.numbers.acceptablePrice = 2000e30;
        order.numbers.executionFee = 1e15;
        order.numbers.callbackGasLimit = 100000;
        order.numbers.minOutputAmount = 0;
        order.numbers.updatedAtTime = block.timestamp;
        order.numbers.validFromTime = block.timestamp;

        order.flags.isLong = true;
        order.flags.shouldUnwrapNativeToken = false;
        order.flags.isFrozen = false;
        order.flags.autoCancel = false;
    }

    function testAfterOrderExecutionGasUsage_IncreaseOrder() public {
        bytes32 key = keccak256("test_increase_order");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketIncrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderExecution(key, order, emptyEventData);
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for increase order callback:", gasUsed);
        
        uint unhandledCount = gmxExecutionCallback.unhandledCallbackListId();
        assertEq(unhandledCount, 1, "Should have 1 unhandled callback");
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionGasUsage_DecreaseOrder() public {
        bytes32 key = keccak256("test_decrease_order");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderExecution(key, order, emptyEventData);
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for decrease order callback:", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderCancellationGasUsage() public {
        bytes32 key = keccak256("test_cancellation");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderCancellation(key, order, emptyEventData);
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for order cancellation callback:", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderFrozenGasUsage() public {
        bytes32 key = keccak256("test_frozen");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderFrozen(key, order, emptyEventData);
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for order frozen callback:", gasUsed);
        
        vm.stopPrank();
    }
}