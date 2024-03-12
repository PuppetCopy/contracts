// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "./../utils/StoreController.sol";

contract SubaccountStore is StoreController {
    struct Account {
        address account;
        address subaccount;
    }

    struct Action {
        uint actionCount;
        uint maxAllowedCount;
        uint autoTopUpAmount;
    }

    mapping(address => Account) subaccountMap;
    mapping(bytes32 => Action) actionMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getSubaccount(address _account) external view returns (Account memory) {
        return subaccountMap[_account];
    }

    function createSubaccount(address _account, address _subaccount) external {
        subaccountMap[_account] = Account(_account, _subaccount);
    }

    function removeSubaccount(address _account) external {
        delete subaccountMap[_account];
    }

    function setAction(bytes32 _key, Action calldata _action) external {
        actionMap[_key] = _action;
    }

    function getAction(bytes32 _key) external view returns (Action memory) {
        return actionMap[_key];
    }

    function removeAction(bytes32 _key) external {
        delete actionMap[_key];
    }
}
