// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {MirrorPosition} from "./MirrorPosition.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract GmxExecutionCallback is CoreContract, IGmxOrderCallbackReceiver {
    struct Config {
        MirrorPosition mirrorPosition;
        address refundExecutionFeeReceiver; // Address to receive execution fee refunds
    }

    struct UnhandledCallback {
        address operator;
        bytes32 key;
        bytes error;
    }

    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

    uint public unhandledCallbackListId = 0;
    Config public config;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority) {
        _setConfig(abi.encode(_config));
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
            try config.mirrorPosition.execute(key) {}
            catch (bytes memory err) {
                _storeUnhandledCallback(key, err);
            }
        } else if (GmxPositionUtils.isLiquidateOrder(order.numbers.orderType)) {
            try config.mirrorPosition.liquidate(order.addresses.account) {}
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


    function refundExecutionFee(
        bytes32 key,
        bytes calldata /*eventData*/
    ) external payable auth {
        require(msg.value > 0, "No execution fee to refund");

        // Refund the execution fee to the configured receiver
        (bool success, ) = config.refundExecutionFeeReceiver.call{value: msg.value}("");
        require(success, Error.GmxExecutionCallback__FailedRefundExecutionFee());

        _logEvent("RefundExecutionFee", abi.encode(key, msg.value));
    }

    function _storeUnhandledCallback(bytes32 _key, bytes memory error) internal {
        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = UnhandledCallback({operator: msg.sender, key: _key, error: error});

        _logEvent("StoreUnhandledCallback", abi.encode(id, error, _key));
    }

    /// @notice  Sets the configuration parameters via governance
    /// @param _data The encoded configuration data
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes memory _data
    ) internal override {
        config = abi.decode(_data, (Config));

        require(address(config.mirrorPosition) != address(0), "Invalid mirror position address");
    }
}
