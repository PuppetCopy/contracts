// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {Subaccount} from "../Subaccount.sol";
import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract SubaccountStore is Auth {
    mapping(address => Subaccount) public subaccountMap;

    address public operator;

    constructor(IAuthority _authority, address _operator) Auth(_authority) {
        operator = _operator;
    }

    function getSubaccount(address _user) external view returns (Subaccount) {
        return subaccountMap[_user];
    }

    function createSubaccount(address _user) external returns (Subaccount) {
        return subaccountMap[_user] = new Subaccount(this, _user);
    }

    function setOperator(address _operator) external auth {
        operator = _operator;
    }
}
