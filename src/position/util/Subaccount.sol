// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

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
        (_success, _returnData) = _contract.call{value: msg.value, gas: gasleft()}(_data);

        return (_success, _returnData);
    }

    function approveToken(address _spender, IERC20 _token, uint _amount) external onlyLogicOperator {
        SafeERC20.forceApprove(_token, _spender, _amount);
    }

    error Subaccount__NotCallbackCaller();
}
