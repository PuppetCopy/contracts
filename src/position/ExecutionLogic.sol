// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";

import {UnhandledCallbackLogic} from "./UnhandledCallbackLogic.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecutionLogic is CoreContract, IGmxOrderCallbackReceiver {
    PuppetStore immutable puppetStore;
    PositionStore immutable positionStore;
    UnhandledCallbackLogic immutable unhandledCallbackLogic;

    constructor(
        IAuthority _authority,
        PuppetStore _puppetStore,
        PositionStore _positionStore
    ) CoreContract("ExecutionLogic", "1", _authority) {
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function handleCancelled(bytes32 key, GmxPositionUtils.Props memory order, bytes calldata eventData) internal {
        revert("Not implemented");
    }

    function handleFrozen(
        bytes32 key, //
        GmxPositionUtils.Props memory order,
        bytes calldata eventData
    ) internal {
        revert("Not implemented");
    }

    function handleExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) internal {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            increase(key, order, eventData);
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            decrease(key, order, eventData);
        } else {
            revert Error.PositionRouter__InvalidOrderType(order.numbers.orderType);
        }
    }

    function increase(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) internal {
        PositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        require(request.matchKey != 0, Error.ExecutionLogic__RequestDoesNotMatchExecution());

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.allocationKey);

        allocation.size += request.sizeDelta;
        puppetStore.setAllocation(request.allocationKey, allocation);
        positionStore.removeRequestAdjustment(requestKey);

        _logEvent(
            "ExecuteIncrease",
            abi.encode(
                requestKey,
                request.sourceRequestKey,
                request.allocationKey,
                request.matchKey,
                request.sizeDelta,
                request.transactionCost,
                allocation.size
            )
        );
    }

    function decrease(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) internal {
        PositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        require(request.matchKey != 0, Error.ExecutionLogic__RequestDoesNotMatchExecution());

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.allocationKey);

        require(allocation.size > 0, Error.ExecutionLogic__PositionDoesNotExist());

        uint recordedAmountIn = puppetStore.recordTransferIn(allocation.collateralToken);
        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (request.sizeDelta < allocation.size) {
            uint adjustedAllocation = allocation.allocated * request.sizeDelta / allocation.size;
            uint profit = recordedAmountIn > adjustedAllocation ? recordedAmountIn - adjustedAllocation : 0;

            allocation.profit += profit;
            allocation.settled += recordedAmountIn;
            allocation.size -= request.sizeDelta;
        } else {
            allocation.profit = recordedAmountIn > allocation.allocated ? recordedAmountIn - allocation.allocated : 0;
            allocation.settled += recordedAmountIn;
            allocation.size = 0;
        }

        positionStore.removeRequestDecrease(requestKey);
        puppetStore.setAllocation(request.allocationKey, allocation);

        _logEvent(
            "ExecuteDecrease",
            abi.encode(
                requestKey,
                request.sourceRequestKey,
                request.allocationKey,
                request.matchKey,
                request.sizeDelta,
                request.transactionCost,
                recordedAmountIn,
                allocation.settled
            )
        );
    }

    /**
     * @notice Called after an order is executed.
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        handleExecution(key, order, eventData);
        // try handleExecution(key, order, eventData) {
        //     // Successful execution
        // } catch {
        //     unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        // }
    }

    /**
     * @notice Called after an order is cancelled.
     */
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        handleCancelled(key, order, eventData);
        // try handleCancelled(key, order, eventData) {
        //     // Successful cancellation handling
        // } catch {
        //     unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        // }
    }

    /**
     * @notice Called after an order is frozen.
     */
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        handleFrozen(key, order, eventData);
        // try handleFrozen(key, order, eventData) {
        //     // Successful frozen handling
        // } catch {
        //     unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        // }
    }
}
