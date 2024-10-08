// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {EventEmitter} from "./EventEmitter.sol";
import {Permission} from "./auth/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

abstract contract CoreContract is Permission, EIP712 {
    EventEmitter eventEmitter;

    string private name;
    string private version;

    constructor(
        string memory _name,
        string memory _version,
        IAuthority _authority,
        EventEmitter _eventEmitter
    ) EIP712(_name, _version) Permission(_authority) {
        eventEmitter = _eventEmitter;

        name = _name;
        version = _version;
    }

    function logEvent(string memory eventName, bytes memory data) internal {
        eventEmitter.logEvent(name, version, eventName, data);
    }
}
