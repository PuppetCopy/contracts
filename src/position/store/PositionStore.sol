// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenRouter} from "./../../shared/TokenRouter.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract PositionStore is BankStore {
    struct RequestAdjustment {
        bytes32 allocationKey;
        bytes32 sourceRequestKey;
        bytes32 matchKey;
        uint sizeDelta;
        uint transactionCost;
    }

    struct UnhandledCallback {
        GmxPositionUtils.Props order;
        address operator;
        bytes eventData;
        bytes32 key;
    }

    mapping(bytes32 matchKey => Subaccount) routeSubaccountMap;
    mapping(bytes32 matchKey => IERC20) routeTokenMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    uint unhandledCallbackListId = 0;
    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}

    function getRequestAdjustment(
        bytes32 _key
    ) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_key];
    }

    function setRequestAdjustment(bytes32 _key, RequestAdjustment calldata _ra) external auth {
        requestAdjustmentMap[_key] = _ra;
    }

    function removeRequestAdjustment(
        bytes32 _key
    ) external auth {
        delete requestAdjustmentMap[_key];
    }

    function removeRequestDecrease(
        bytes32 _key
    ) external auth {
        delete requestAdjustmentMap[_key];
    }

    function setUnhandledCallbackList(
        GmxPositionUtils.Props calldata _order,
        address _operator,
        bytes32 _key,
        bytes calldata _eventData
    ) external auth returns (uint) {
        PositionStore.UnhandledCallback memory callbackResponse =
            PositionStore.UnhandledCallback({order: _order, operator: _operator, eventData: _eventData, key: _key});

        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = callbackResponse;

        return id;
    }

    function getUnhandledCallback(
        uint _id
    ) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_id];
    }

    function removeUnhandledCallback(
        uint _id
    ) external auth {
        delete unhandledCallbackMap[_id];
    }

    function getSubaccount(
        bytes32 _key
    ) external view returns (Subaccount) {
        return routeSubaccountMap[_key];
    }

    function createSubaccount(bytes32 _key, address _account) external auth returns (Subaccount) {
        return routeSubaccountMap[_key] = new Subaccount(this, _account);
    }
}
