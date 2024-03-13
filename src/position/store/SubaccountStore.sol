// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "src/utils/StoreController.sol";

// import {ISubaccount} from "./../interface/ISubaccount.sol";
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

    function getSubaccount(address _account) external view returns (Subaccount) {
        return subaccountMap[_account];
    }

    function createSubaccount(address _account, Subaccount _subaccount) external {
        subaccountMap[_account] = _subaccount;
    }

    function removeSubaccount(address _account) external {
        delete subaccountMap[_account];
    }

    function setNativeTokenGasLimit(uint _nativeTokenGasLimit) external requiresAuth {
        nativeTokenGasLimit = _nativeTokenGasLimit;
    }

    function setHoldingAddress(address _holdingAddress) external requiresAuth {
        holdingAddress = _holdingAddress;
    }

    function setTokenGasLimit(uint _tokenGasLimit) external requiresAuth {
        tokenGasLimit = _tokenGasLimit;
    }

    function setWntBalance(address _account, uint _balance) external requiresAuth {
        wntBalance[_account] = _balance;
    }

    function setLogicOperator(address _subaccountImplementation) external requiresAuth {
        logicOperator = _subaccountImplementation;
    }

    function getLogicOperator() external view returns (address) {
        return logicOperator;
    }
}
