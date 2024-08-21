// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {EventEmitter} from "./EventEmitter.sol";

import {Auth} from "./access/Auth.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

abstract contract CoreContract is Auth, EIP712 {
    EventEmitter eventEmitter;

    constructor(
        string memory _name,
        string memory _version,
        IAuthority _authority,
        EventEmitter _eventEmitter
    ) EIP712(_name, _version) Auth(_authority) {
        eventEmitter = _eventEmitter;
    }
}
