// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Access} from "./../utils/auth/Access.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

// @title EventEmitter
// @dev Contract to emit events
// This allows main events to be emitted from a single contract
// Logic contracts can be updated while re-using the same eventEmitter contract
// Peripheral services like monitoring or analytics would be able to continue
// to work without an update and without segregating historical data
contract EventEmitter is Access {
    event LogEvent(address operator, string name, string version, string method, bytes data);

    constructor(IAuthority _authority) Access(_authority) {
        authority = _authority;
    }

    // @dev emit a general event log
    // @param eventName the name of the event
    // @param eventData the event data
    function logEvent(
        string calldata name,
        string calldata version,
        string calldata method,
        bytes calldata data
    ) external auth {
        emit LogEvent(msg.sender, name, version, method, data);
    }
}
