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
                callbackHandler: placeholderCallback, // Temporary address
                gmxOrderVault: address(0x1235), // Mock address
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

        vm.stopPrank();
    }

    function createMockOrder(GmxPositionUtils.OrderType orderType) internal view returns (GmxPositionUtils.Props memory) {
        return GmxPositionUtils.Props({
            addresses: GmxPositionUtils.Addresses({
                account: address(0x1001),
                receiver: address(0x1002),
                callbackContract: address(0x1003),
                uiFeeReceiver: address(0),
                market: address(0x1004),
                initialCollateralToken: IERC20(address(usdc)),
                swapPath: new address[](0)
            }),
            numbers: GmxPositionUtils.Numbers({
                orderType: orderType,
                decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
                initialCollateralDeltaAmount: 100e6,
                sizeDeltaUsd: 1000e30,
                triggerPrice: 0,
                acceptablePrice: 2000e30,
                executionFee: 1e15,
                callbackGasLimit: 100000,
                minOutputAmount: 0,
                updatedAtBlock: block.number
            }),
            flags: GmxPositionUtils.Flags({
                isLong: true,
                shouldUnwrapNativeToken: false,
                isFrozen: false
            })
        });
    }

    function testAfterOrderExecutionGasUsage_IncreaseOrder() public {
        bytes32 key = keccak256("test_increase_order");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketIncrease);
        
        vm.startPrank(gmxOrderHandler);
        
        // Measure gas usage
        uint gasBefore = gasleft();
        
        // This should succeed but store an unhandled callback since there's no request
        gmxExecutionCallback.afterOrderExecution(key, order, "");
        
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for increase order callback (with unhandled storage):", gasUsed);
        
        // Check that the callback was stored as unhandled
        uint unhandledCount = gmxExecutionCallback.unhandledCallbackListId();
        assertEq(unhandledCount, 1, "Should have 1 unhandled callback");
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionGasUsage_DecreaseOrder() public {
        bytes32 key = keccak256("test_decrease_order");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderExecution(key, order, "");
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for decrease order callback (with unhandled storage):", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionGasUsage_LiquidationOrder() public {
        bytes32 key = keccak256("test_liquidation_order");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.Liquidation);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderExecution(key, order, "");
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for liquidation order callback (with unhandled storage):", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionGasUsage_InvalidOrderType() public {
        bytes32 key = keccak256("test_invalid_order");
        // Create a valid order but we'll test with an edge case order type
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.LimitSwap); // Not increase/decrease/liquidation
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderExecution(key, order, "");
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for non-position order type callback:", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionWithLimitedGas() public {
        bytes32 key = keccak256("test_limited_gas");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        // Test with exactly 100k gas (the limit from the transaction)
        bool success;
        bytes memory returnData;
        
        (success, returnData) = address(gmxExecutionCallback).call{gas: 100000}(
            abi.encodeWithSelector(
                gmxExecutionCallback.afterOrderExecution.selector,
                key,
                order,
                ""
            )
        );
        
        console.log("100k gas call success:", success);
        if (!success) {
            console.log("Revert reason length:", returnData.length);
            if (returnData.length > 0) {
                console.logBytes(returnData);
            }
        }
        
        // Test with progressively higher gas limits to find the minimum required
        uint[] memory gasLimits = new uint[](8);
        gasLimits[0] = 150000;  // 150k
        gasLimits[1] = 200000;  // 200k
        gasLimits[2] = 250000;  // 250k
        gasLimits[3] = 300000;  // 300k
        gasLimits[4] = 350000;  // 350k
        gasLimits[5] = 400000;  // 400k
        gasLimits[6] = 450000;  // 450k
        gasLimits[7] = 500000;  // 500k
        
        for (uint i = 0; i < gasLimits.length; i++) {
            (success, returnData) = address(gmxExecutionCallback).call{gas: gasLimits[i]}(
                abi.encodeWithSelector(
                    gmxExecutionCallback.afterOrderExecution.selector,
                    key,
                    order,
                    ""
                )
            );
            
            console.log(string(abi.encodePacked(uint2str(gasLimits[i]/1000), "k gas call success:")), success);
            
            if (success) {
                console.log("SUCCESS! Minimum gas required is approximately:", gasLimits[i]);
                break;
            }
        }
        
        vm.stopPrank();
    }
    
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function testAfterOrderCancellationGasUsage() public {
        bytes32 key = keccak256("test_cancellation");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderCancellation(key, order, "");
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for order cancellation callback:", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderFrozenGasUsage() public {
        bytes32 key = keccak256("test_frozen");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        uint gasBefore = gasleft();
        gmxExecutionCallback.afterOrderFrozen(key, order, "");
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for order frozen callback:", gasUsed);
        
        vm.stopPrank();
    }

    function testAfterOrderExecutionGasUsage_DirectCall() public {
        bytes32 key = keccak256("test_direct_call");
        GmxPositionUtils.Props memory order = createMockOrder(GmxPositionUtils.OrderType.MarketDecrease);
        
        vm.startPrank(gmxOrderHandler);
        
        // Measure gas usage for the callback without going through MirrorPosition
        uint gasBefore = gasleft();
        
        // This should go through the try-catch and store unhandled callback
        gmxExecutionCallback.afterOrderExecution(key, order, "");
        
        uint gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for direct callback call:", gasUsed);
        
        // Check that unhandled callback was stored
        uint unhandledCount = gmxExecutionCallback.unhandledCallbackListId();
        console.log("Unhandled callbacks stored:", unhandledCount);
        
        vm.stopPrank();
    }
}
