// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Router} from "./../../shared/Router.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract PositionStore is BankStore {
    struct RequestAdjustment {
        bytes32 positionKey;
        uint traderSizeDelta;
        uint traderCollateralDelta;
        uint puppetSizeDelta;
        uint puppetCollateralDelta;
        uint transactionCost;
    }

    struct MirrorPosition {
        // match
        address trader;
        address[] puppetList;
        uint[] collateralList;
        // execution
        uint traderSize;
        uint traderCollateral;
        uint puppetSize;
        uint puppetCollateral;
        uint cumulativeTransactionCost;
    }

    struct UnhandledCallback {
        GmxPositionUtils.OrderExecutionStatus status;
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;

    mapping(address => Subaccount) public subaccountMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getRequestAdjustment(bytes32 _key) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_key];
    }

    function setRequestAdjustment(bytes32 _key, RequestAdjustment calldata _ra) external auth {
        requestAdjustmentMap[_key] = _ra;
    }

    function removeRequestAdjustment(bytes32 _key) external auth {
        delete requestAdjustmentMap[_key];
    }

    function removeRequestDecrease(bytes32 _key) external auth {
        delete requestAdjustmentMap[_key];
    }

    function getMirrorPosition(bytes32 _key) external view returns (MirrorPosition memory) {
        return positionMap[_key];
    }

    function setMirrorPosition(bytes32 _key, MirrorPosition calldata _mp) external auth {
        positionMap[_key] = _mp;
    }

    function removeMirrorPosition(bytes32 _key) external auth {
        delete positionMap[_key];
    }

    function setUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus _status,
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) external auth {
        PositionStore.UnhandledCallback memory callbackResponse =
            PositionStore.UnhandledCallback({status: _status, order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallback(bytes32 _key) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_key];
    }

    function removeUnhandledCallback(bytes32 _key) external auth {
        delete unhandledCallbackMap[_key];
    }

    function getSubaccount(address _user) external view returns (Subaccount) {
        return subaccountMap[_user];
    }

    function createSubaccount(address _user) external auth returns (Subaccount) {
        return subaccountMap[_user] = new Subaccount(this, _user);
    }
}
