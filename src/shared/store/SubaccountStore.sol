// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {Subaccount} from "../Subaccount.sol";

contract SubaccountStore is Auth {
    mapping(address => Subaccount) public subaccountMap;

    address public operator;

    constructor(IAuthority _authority, address _operator) Auth(_authority) {
        operator = _operator;
    }

    function getSubaccount(address _user) external view returns (Subaccount) {
        return subaccountMap[_user];
    }

    function setSubaccount(address _user) external auth returns (Subaccount) {
        return subaccountMap[_user] = new Subaccount(this, _user);
    }

    function removeSubaccount(address _user) external auth {
        delete subaccountMap[_user];
    }

    function setOperator(address _operator) external auth {
        operator = _operator;
    }
}
