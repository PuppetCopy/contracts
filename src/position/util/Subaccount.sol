// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../../utils/Router.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

contract Subaccount {
    SubaccountStore store;

    address public account;
    uint public balance;

    constructor(SubaccountStore _store, address _account) {
        store = _store;
        account = _account;
    }

    modifier onlyLogicOperator() {
        if (msg.sender != store.logicOperator()) revert Subaccount__NotCallbackCaller();
        _;
    }

    function deposit() public payable onlyLogicOperator {
        balance += msg.value;
    }

    function withdraw(uint _amount) external onlyLogicOperator {
        if (_amount > balance) revert Subaccount__TransferFailed(msg.sender, _amount);

        balance -= _amount;

        (bool _success,) = msg.sender.call{value: _amount}("");
        if (!_success) {
            revert Subaccount__TransferFailed(msg.sender, _amount);
        }
    }

    function execute(address _from, bytes calldata _data) external payable onlyLogicOperator returns (bool _success, bytes memory _returnData) {
        uint _startLimit = gasleft();

        if (_startLimit > balance) revert Subaccount__NotEnoughGas(account, _startLimit);
        if (_from != account) revert Subaccount__NotAccountOwner();

        (_success, _returnData) = account.call{gas: _startLimit}(_data);

        uint _gasCost = (_startLimit - gasleft()) * tx.gasprice;

        balance -= _gasCost;

        return (_success, _returnData);
    }

    function depositToken(Router _router, IERC20 _token, uint _amount) external {
        _router.pluginTransfer(_token, account, address(this), _amount);
        _token.approve(address(_router), _amount);
    }

    error Subaccount__NotAccountOwner();
    error Subaccount__NotCallbackCaller();
    error Subaccount__TransferFailed(address to, uint amount);
    error Subaccount__NotEnoughGas(address account, uint gasCost);
}
