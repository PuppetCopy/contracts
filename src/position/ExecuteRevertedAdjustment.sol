// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";

import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteRevertedAdjustment is Permission, EIP712 {
    event ExecuteRevertedAdjustment__SetConfig(uint timestamp, CallConfig callConfig);

    struct CallConfig {
        string handlehandle;
    }

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("Position Router", "1") {
        _setConfig(_callConfig);
    }

    function handleCancelled(bytes32 key, GmxPositionUtils.Props memory order) external auth {
        // TODO: implement
    }
    function handleFrozen(bytes32 key, GmxPositionUtils.Props memory order) external auth {
        // TODO: implement
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit ExecuteRevertedAdjustment__SetConfig(block.timestamp, callConfig);
    }
}
