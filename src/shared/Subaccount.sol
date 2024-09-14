// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth} from "../utils/access/Auth.sol";

contract Subaccount {
    Auth store;
    address public account;

    constructor(Auth _store, address _account) {
        store = _store;
        account = _account;
    }

    function execute(
        address _contract,
        bytes calldata _data
    ) external payable returns (bool _success, bytes memory _returnData) {
        if (!store.canCall(msg.sender)) revert Subaccount__UnauthorizedOperator();

        return _contract.call{value: msg.value, gas: gasleft()}(_data);
    }

    error Subaccount__UnauthorizedOperator();
}
