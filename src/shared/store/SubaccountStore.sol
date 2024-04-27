// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "./StoreController.sol";
import {Subaccount} from "../Subaccount.sol";

contract SubaccountStore is StoreController {
    mapping(address => Subaccount) public subaccountMap;

    address public operator;

    constructor(Authority _authority, address _setter) StoreController(_authority, _setter) {}

    function getSubaccount(address _address) external view returns (Subaccount) {
        return subaccountMap[_address];
    }

    function setSubaccount(address _address, Subaccount _subaccount) external isSetter {
        subaccountMap[_address] = _subaccount;
    }

    function removeSubaccount(address _address) external isSetter {
        delete subaccountMap[_address];
    }

    function setOperator(address _address) external isSetter {
        operator = _address;
    }
}
