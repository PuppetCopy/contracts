// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {WNT} from "./../../utils/WNT.sol";
import {TransferUtils} from "./../../utils/TransferUtils.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

contract Subaccount is ReentrancyGuard {
    WNT wnt;
    SubaccountStore store;
    address account;

    constructor(WNT _wnt, SubaccountStore _store, address _account) {
        wnt = _wnt;
        store = _store;
        account = _account;
    }

    modifier onlyLogicOperator() {
        if (msg.sender != store.getLogicOperator()) revert Subaccount__NotCallbackCaller();
        _;
    }

    function getAccount() external view returns (address) {
        return account;
    }

    receive() external payable {
        if (msg.sender != address(wnt)) {
            revert Subaccount__InvalidNativeTokenSender(msg.sender);
        }
    }

    function execute(address _to, bytes calldata _data) external payable onlyLogicOperator returns (bool success, bytes memory returnData) {
        return _to.call{value: msg.value}(_data);
    }

    function depositWnt(uint amount) external payable nonReentrant {
        TransferUtils.depositAndSendWrappedNativeToken(wnt, store.holdingAddress(), store.tokenGasLimit(), address(store), amount);

        uint balance = store.wntBalance(msg.sender);

        store.setWntBalance(msg.sender, balance + amount);
    }

    error Subaccount__InvalidNativeTokenSender(address sender);
    error Subaccount__NotCallbackCaller();
}
