// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract PositionStore is BankStore {
    struct RequestMatch {
        address trader;
        address[] puppetList;
    }

    struct RequestAdjustment {
        bytes32 positionKey;
        uint[] puppetCollateralDeltaList;
        uint sizeDelta;
        uint collateralDelta;
        uint transactionCost;
    }

    struct MirrorPosition {
        address trader;
        address[] puppetList;
        uint[] collateralList;
        uint size;
        uint collateral;
        uint cumulativeTransactionCost;
    }

    struct UnhandledCallback {
        GmxPositionUtils.OrderExecutionStatus status;
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => RequestMatch) public requestMatchMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;

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

    function getRequestMatch(bytes32 _key) external view returns (RequestMatch memory) {
        return requestMatchMap[_key];
    }

    function setRequestMatch(bytes32 _key, RequestMatch calldata _rm) external auth {
        requestMatchMap[_key] = _rm;
    }

    function removeRequestMatch(bytes32 _key) external auth {
        delete requestMatchMap[_key];
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
}
