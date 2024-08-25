// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {EventEmitter} from "./EventEmitter.sol";
import {Permission} from "./access/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

abstract contract CoreContract is Permission, EIP712 {
    EventEmitter eventEmitter;

    string private name = _EIP712Name();
    string private version = _EIP712Version();

    constructor(
        string memory _name,
        string memory _version,
        IAuthority _authority,
        EventEmitter _eventEmitter
    ) EIP712(_name, _version) Permission(_authority) {
        eventEmitter = _eventEmitter;
    }

    function logEvent(string memory method, bytes memory data) internal {
        eventEmitter.logEvent(name, version, method, data);
    }
}
