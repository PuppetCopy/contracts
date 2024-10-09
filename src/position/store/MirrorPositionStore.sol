// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../../shared/Router.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract MirrorPositionStore is BankStore {
    struct RequestAdjustment {
        // bytes32 traderPositionKey;
        bytes32 allocationKey;
        bytes32 traderRequestKey;
        bytes32 matchKey;
        // bytes32 positionKey;
        uint sizeDelta;
        uint transactionCost;
    }

    struct UnhandledCallback {
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 matchKey => Subaccount) routeSubaccountMap;
    mapping(bytes32 matchKey => IERC20) routeTokenMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

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

    function setUnhandledCallback(
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) external auth {
        MirrorPositionStore.UnhandledCallback memory callbackResponse =
            MirrorPositionStore.UnhandledCallback({order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallback(
        bytes32 _key
    ) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_key];
    }

    function removeUnhandledCallback(
        bytes32 _key
    ) external auth {
        delete unhandledCallbackMap[_key];
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
