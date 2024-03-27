// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {GmxPositionUtils} from "./../util/GmxPositionUtils.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";

contract PositionStore is StoreController {
    struct RequestIncrease {
        address trader;
        uint[] puppetCollateralDeltaList;
        uint leverageTarget;
        uint sizeDelta;
        uint collateralDelta;
    }

    struct RequestDecrease {
        address trader;
        uint[] puppetCollateralDeltaList;
        uint sizeDelta;
        uint collateralDelta;
    }

    struct MirrorPosition {
        uint size;
        uint collateral;
        uint totalSize;
        uint totalCollateral;
        uint leverage;
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct UnhandledCallbackMap {
        GmxPositionUtils.OrderExecutionStatus status;
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    struct Activity {
        uint latestFunding;
        uint allowance;
    }

    mapping(bytes32 requestKey => RequestIncrease) public requestIncreaseMap;
    mapping(bytes32 requestKey => RequestDecrease) public requestDecreaseMap;

    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallbackMap) public unhandledCallbackMap;

    mapping(bytes32 ruleKey => Activity) public activityMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRequestIncreaseMap(bytes32 _key) external view returns (RequestIncrease memory) {
        return requestIncreaseMap[_key];
    }

    function setRequestIncreaseMap(bytes32 _key, RequestIncrease memory _req) external isSetter {
        requestIncreaseMap[_key] = _req;
    }

    function removeRequestIncreaseMap(bytes32 _key) external isSetter {
        delete requestIncreaseMap[_key];
    }

    function getRequestDecreaseMap(bytes32 _key) external view returns (RequestDecrease memory) {
        return requestDecreaseMap[_key];
    }

    function setRequestDecreaseMap(bytes32 _key, RequestDecrease calldata _req) external isSetter {
        requestDecreaseMap[_key] = _req;
    }

    function removeRequestDecreaseMap(bytes32 _key) external isSetter {
        delete requestDecreaseMap[_key];
    }

    function getMirrorPosition(bytes32 _key) external view returns (MirrorPosition memory) {
        return positionMap[_key];
    }

    function setMirrorPosition(bytes32 _key, MirrorPosition calldata _mp) external isSetter {
        positionMap[_key] = _mp;
    }

    function removeMirrorPosition(bytes32 _key) external isSetter {
        delete positionMap[_key];
    }

    function setUnhandledCallbackMap(
        GmxPositionUtils.OrderExecutionStatus _status,
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) external isSetter {
        PositionStore.UnhandledCallbackMap memory callbackResponse =
            PositionStore.UnhandledCallbackMap({status: _status, order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallbackMap(bytes32 _key) external view returns (UnhandledCallbackMap memory) {
        return unhandledCallbackMap[_key];
    }

    function setActivity(bytes32 _key, Activity calldata _activity) external isSetter {
        activityMap[_key] = _activity;
    }

    function getActivity(bytes32 _key) external view returns (Activity memory) {
        return activityMap[_key];
    }

    function getActivityList(bytes32 _routeKey, address[] calldata _addressList) external view returns (Activity[] memory) {
        uint length = _addressList.length;
        Activity[] memory _activity = new Activity[](length);

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PositionUtils.getRuleKey(_addressList[i], _routeKey);
            _activity[i] = activityMap[puppetTraderKey];
        }
        return _activity;
    }

    function setRuleActivityList(bytes32 _routeKey, address[] calldata _addressList, Activity[] calldata _activityList) external isSetter {
        uint length = _addressList.length;

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PositionUtils.getRuleKey(_addressList[i], _routeKey);
            activityMap[puppetTraderKey] = _activityList[i];
        }
    }
}
