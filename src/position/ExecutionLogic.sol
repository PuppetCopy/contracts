// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecutionLogic is CoreContract {
    PuppetStore immutable puppetStore;
    PositionStore immutable positionStore;

    constructor(
        IAuthority _authority,
        PuppetStore _puppetStore,
        PositionStore _positionStore
    ) CoreContract("ExecutionLogic", "1", _authority) {
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function handleCancelled(
        bytes32 key,
        GmxPositionUtils.Props memory order,
        bytes calldata eventData
    ) external auth {
        revert("Not implemented");
    }

    function handleFrozen(
        bytes32 key, //
        GmxPositionUtils.Props memory order,
        bytes calldata eventData
    ) external auth {
        revert("Not implemented");
    }

    function handleExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
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

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.allocationKey);

        allocation.size += request.sizeDelta;
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

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.allocationKey);

        if (allocation.size == 0) {
            revert Error.ExecutionLogic__PositionDoesNotExist();
        }

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

    function _setConfig(
        bytes calldata data
    ) internal override {
        revert("Not implemented");
    }
}
