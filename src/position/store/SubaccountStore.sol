// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "src/utils/StoreController.sol";
import {Subaccount} from "./../util/Subaccount.sol";

contract SubaccountStore is StoreController {
    mapping(address => uint) public wntBalance;
    mapping(address => Subaccount) public subaccountMap;

    uint public nativeTokenGasLimit = 50_000;
    uint public tokenGasLimit = 200_000;
    address public holdingAddress;

    address public logicOperator;

    constructor(Authority _authority, address _holdingAddress, address _initSetter) StoreController(_authority, _initSetter) {
        holdingAddress = _holdingAddress;
    }

    function setWntBalance(address _address, uint _value) external isSetter {
        wntBalance[_address] = _value;
    }

    function getSubaccount(address _address) external view returns (Subaccount) {
        return subaccountMap[_address];
    }

    function setSubaccount(address _address, Subaccount _subaccount) external {
        subaccountMap[_address] = _subaccount;
    }

    function removeSubaccount(address _address) external {
        delete subaccountMap[_address];
    }

    function setNativeTokenGasLimit(uint _value) external isSetter {
        nativeTokenGasLimit = _value;
    }

    function setTokenGasLimit(uint _value) external isSetter {
        tokenGasLimit = _value;
    }

    function setHoldingAddress(address _address) external isSetter {
        holdingAddress = _address;
    }

    function setLogicOperator(address _address) external isSetter {
        logicOperator = _address;
    }
}
