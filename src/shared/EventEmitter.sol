// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IEventEmitter} from "../utils/interfaces/IEventEmitter.sol";

contract EventEmitter is IEventEmitter {
    function logEvent(string calldata _method, bytes calldata _data) external {
        emit PuppetEventLog(msg.sender, _method, _data);
    }
}
