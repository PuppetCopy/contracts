// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {PositionUtils} from "./../util/PositionUtils.sol";

interface IPositionLogicCallbackOperator {
    function forwardCallback(bytes32 key, PositionUtils.Props memory order, bytes memory eventData) external;
}