// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SubaccountStore} from "./store/SubaccountStore.sol";

contract Subaccount {
    SubaccountStore store;
    address public account;

    constructor(SubaccountStore _store, address _account) {
        store = _store;
        account = _account;
    }

    modifier onlyLogicOperator() {
        if (msg.sender != store.logicOperator()) revert Subaccount__NotCallbackCaller();
        _;
    }

    function execute(address _contract, bytes calldata _data) external payable onlyLogicOperator returns (bool _success, bytes memory _returnData) {
        return _contract.call{value: msg.value, gas: gasleft()}(_data);
    }

    error Subaccount__NotCallbackCaller();
}
