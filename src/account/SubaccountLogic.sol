// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "src/utils/Router.sol";
import {SubaccountStore} from "./SubaccountStore.sol";
import {WNT} from "./../utils/WNT.sol";

contract SubaccountLogic is Auth {
    event SubaccountLogic__CreateSubaccount(address account, address subaccount);
    event SubaccountLogic__RemoveSubaccount(address account, address subaccount);
    event SubaccountLogic__UpdateActivity(address account, address subaccount, bytes32 actionType, uint maxAllowedCount, uint autoTopUpAmount);
    event SubaccountLogic__MaxAllowedCountReached(address account, address subaccount, bytes32 actionType);

    WNT public immutable wnt;

    constructor(Authority _authority, WNT _wnt) Auth(address(0), _authority) {
        wnt = _wnt;
    }

    receive() external payable {
        if (msg.sender != address(wnt)) {
            revert Subaccount__InvalidNativeTokenSender(msg.sender);
        }
    }

    function createSubaccount(SubaccountStore store, address account, address subaccount) external payable requiresAuth {
        store.createSubaccount(account, subaccount);
        emit SubaccountLogic__CreateSubaccount(account, subaccount);
    }

    function removeSubaccount(SubaccountStore store, address account, address subaccount) external payable requiresAuth {
        store.removeSubaccount(account);
        emit SubaccountLogic__RemoveSubaccount(account, subaccount);
    }

    function setAction(SubaccountStore store, address account, address subaccount, bytes32 actionType, uint maxAllowedCount, uint autoTopUpAmount)
        external
        payable
        requiresAuth
    {
        bytes32 key = getActionKey(account, subaccount, actionType);

        SubaccountStore.Action memory action = store.getAction(key);

        action.maxAllowedCount = maxAllowedCount;
        action.autoTopUpAmount = autoTopUpAmount;

        store.setAction(key, action);

        emit SubaccountLogic__UpdateActivity(account, subaccount, actionType, maxAllowedCount, autoTopUpAmount);
    }

    function send(Router router, SubaccountStore store, address account, address subAccount, uint executionFee, IERC20 token, address to, uint amount)
        external
        payable
        requiresAuth
        returns (bytes32)
    {
        uint startingGas = gasleft();

        SubaccountStore.Action memory action = _handleAction(store, subAccount, account, keccak256("send"));

        router.pluginTransfer(token, account, to, amount);

        uint autoTopUpAmount = action.autoTopUpAmount;
        if (autoTopUpAmount > 0) {
            _autoTopUpSubaccount(account, subAccount, startingGas, executionFee);
        }

        store.setAction(actionKey, action);

        return key;
    }

    function _handleAction(
        Router router,
        SubaccountStore store,
        address subaccount,
        address account,
        bytes32 actionType,
        uint startingGas,
        uint executionFee
    ) internal returns (SubaccountStore.Action memory action) {
        SubaccountStore.Account memory storedAccount = store.subaccountMap(account);

        if (storedAccount.subaccount != subaccount) {
            revert SubaccountLogic__InvalidSubaccountForAccount(account, subaccount);
        }

        bytes32 actionKey = getActionKey(account, subaccount, "send");
        action = store.getAction(actionKey);

        if (++action.actionCount > action.maxAllowedCount) revert SubaccountLogic__MaxAllowedCountReached(account, subaccount, actionType);

        if (wnt.allowance(account, address(router)) < action.autoTopUpAmount) return;
        if (wnt.balanceOf(account) < action.autoTopUpAmount) return;

        // cap the top up amount to the amount of native tokens used
        uint nativeTokensUsed = (startingGas - gasleft()) * tx.gasprice + executionFee;
        if (nativeTokensUsed < action.autoTopUpAmount) {
            action.autoTopUpAmount = nativeTokensUsed;
        }

        router.pluginTransfer(address(wnt), account, address(store), action.autoTopUpAmount);
    }

    function getActionKey(address account, address subaccount, bytes32 actionType) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, subaccount, actionType));
    }

    error Subaccount__InvalidNativeTokenSender(address sender);
    error SubaccountLogic__InvalidSubaccountForAccount(address account, address subAccount);
}
