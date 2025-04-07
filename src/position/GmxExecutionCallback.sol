// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {MirrorPosition} from "./MirrorPosition.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract GmxExecutionCallback is CoreContract, IGmxOrderCallbackReceiver {
    struct UnhandledCallback {
        address operator;
        bytes32 key;
        bytes error;
    }

    MirrorPosition immutable position;

    uint public unhandledCallbackListId = 0;
    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

    constructor(IAuthority _authority, MirrorPosition _position) CoreContract(_authority) {
        position = _position;
    }

    /**
     * @notice Called after an order is executed.
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata /*eventData*/
    ) external auth {
        if (
            GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)
                || GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)
        ) {
            try position.execute(key) {}
            catch (bytes memory err) {
                _storeUnhandledCallback(key, err);
            }
        } else if (GmxPositionUtils.isLiquidateOrder(order.numbers.orderType)) {
            try position.liquidate(order.addresses.account) {}
            catch (bytes memory err) {
                _storeUnhandledCallback(key, err);
            }
        } else {
            _storeUnhandledCallback(key, "Invalid order type");
        }
    }

    /**
     * @notice Called after an order is cancelled.
     */
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) external auth {
        _storeUnhandledCallback(key, "Cancellation not implemented");
    }

    /**
     * @notice Called after an order is frozen.
     */
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) external auth {
        _storeUnhandledCallback(key, "Freezing not implemented");
    }

    function _storeUnhandledCallback(bytes32 _key, bytes memory error) internal {
        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = UnhandledCallback({operator: msg.sender, key: _key, error: error});

        _logEvent("StoreUnhandledCallback", abi.encode(id, error, _key));
    }
}
