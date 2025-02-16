// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";

import {PositionLogic} from "./PositionLogic.sol";
import {UnhandledCallbackLogic} from "./UnhandledCallbackLogic.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecutionCallbackLogic is CoreContract, IGmxOrderCallbackReceiver {
    UnhandledCallbackLogic immutable unhandledCallbackLogic;
    PositionLogic immutable positionLogic;

    constructor(IAuthority _authority, PositionLogic _positionLogic) CoreContract("ExecutionCallbackLogic", "1", _authority) {
        positionLogic = _positionLogic;
    }

    /**
     * @notice Called after an order is executed.
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            positionLogic.increase(key, order, eventData);
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            positionLogic.decrease(key, order, eventData);
        } else {
            revert Error.PositionRouter__InvalidOrderType(order.numbers.orderType);
        }
    }

    /**
     * @notice Called after an order is cancelled.
     */
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        revert("Not implemented");
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
        revert("Not implemented");
        // try handleFrozen(key, order, eventData) {
        //     // Successful frozen handling
        // } catch {
        //     unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        // }
    }
}
