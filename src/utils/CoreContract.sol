// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {Error} from "../shared/Error.sol";
import {Permission} from "./auth/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

abstract contract CoreContract is Permission {
    string private name;
    string private version;

    constructor(
        string memory _name,
        IAuthority _authority
    ) Permission(_authority) {
        name = _name;
    }

    function setConfig(
        bytes calldata data
    ) external onlyAuthority {
        _setConfig(data);
        _logEvent("SetConfig", data);
    }

    function _logEvent(string memory method, bytes memory data) internal {
        authority.logEvent(method, name, data);
    }

    function _setConfig(
        bytes calldata data
    ) internal virtual {}
}
