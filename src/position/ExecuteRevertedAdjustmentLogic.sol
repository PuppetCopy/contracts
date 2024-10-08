// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteRevertedAdjustmentLogic is CoreContract {
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter
    ) CoreContract("ExecuteRevertedAdjustmentLogic", "1", _authority, _eventEmitter) {}

    function handleCancelled(bytes32 key, GmxPositionUtils.Props memory order) external auth {
        // TODO: implement
    }
    function handleFrozen(bytes32 key, GmxPositionUtils.Props memory order) external auth {
        // TODO: implement
    }

    // governance
}
