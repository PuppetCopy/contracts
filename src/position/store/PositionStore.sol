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
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct UnhandledCallback {
        GmxPositionUtils.OrderExecutionStatus status;
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 requestKey => RequestIncrease) public requestIncreaseMap;
    mapping(bytes32 requestKey => RequestDecrease) public requestDecreaseMap;

    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRequestIncrease(bytes32 _key) external view returns (RequestIncrease memory) {
        return requestIncreaseMap[_key];
    }

    function setRequestIncrease(bytes32 _key, RequestIncrease memory _req) external isSetter {
        requestIncreaseMap[_key] = _req;
    }

    function removeRequestIncrease(bytes32 _key) external isSetter {
        delete requestIncreaseMap[_key];
    }

    function getRequestDecrease(bytes32 _key) external view returns (RequestDecrease memory) {
        return requestDecreaseMap[_key];
    }

    function setRequestDecrease(bytes32 _key, RequestDecrease calldata _req) external isSetter {
        requestDecreaseMap[_key] = _req;
    }

    function removeRequestDecrease(bytes32 _key) external isSetter {
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

    function setUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus _status,
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) external isSetter {
        PositionStore.UnhandledCallback memory callbackResponse =
            PositionStore.UnhandledCallback({status: _status, order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallback(bytes32 _key) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_key];
    }

    // function setActivity(bytes32 _key, uint _time) external isSetter {
    //     tradeFundingActivityMap[_key] = _time;
    // }

    // function getActivity(bytes32 _key) external view returns (uint) {
    //     return tradeFundingActivityMap[_key];
    // }

    // function getActivityList(bytes32[] calldata _keyList) external view returns (uint[] memory) {
    //     uint _length = _keyList.length;
    //     uint[] memory _activities = new uint[](_keyList.length);
    //     for (uint i = 0; i < _length; i++) {
    //         _activities[i] = tradeFundingActivityMap[_keyList[i]];
    //     }
    //     return _activities;
    // }

    // function setActivityList(bytes32[] memory _keyList, uint[] calldata _amountList) external isSetter {
    //     uint _length = _keyList.length;
    //     for (uint i = 0; i < _length; i++) {
    //         tradeFundingActivityMap[_keyList[i]] = _amountList[i];
    //     }
    // }

    // function getTokenAllowanceActivity(bytes32 _key) external view returns (uint) {
    //     return tokenAllowanceActivityMap[_key];
    // }

    // function setTokenAllowanceActivity(bytes32 _key, uint _amount) external isSetter {
    //     tokenAllowanceActivityMap[_key] = _amount;
    // }

    // function getMatchingActivity(address collateralToken, address trader, address[] calldata _puppetList)
    //     external
    //     view
    //     returns (uint[] memory _activityList, uint[] memory _allowanceOptimList)
    // {
    //     uint length = _puppetList.length;

    //     _activityList = new uint[](length);
    //     _allowanceOptimList = new uint[](length);

    //     for (uint i = 0; i < length; i++) {
    //         _activityList[i] = tradeFundingActivityMap[PositionUtils.getFundingActivityKey(_puppetList[i], trader)];
    //         _allowanceOptimList[i] = tokenAllowanceActivityMap[PositionUtils.getAllownaceKey(collateralToken, _puppetList[i])];
    //     }
    //     return (_activityList, _allowanceOptimList);
    // }

    // function setMatchingActivity(
    //     address collateralToken,
    //     address trader,
    //     address[] calldata _puppetList,
    //     uint[] calldata _activityList,
    //     uint[] calldata _sampledAllowanceList
    // ) external isSetter {
    //     uint length = _puppetList.length;

    //     for (uint i = 0; i < length; i++) {
    //         tradeFundingActivityMap[PositionUtils.getFundingActivityKey(_puppetList[i], trader)] = _activityList[i];
    //         tokenAllowanceActivityMap[PositionUtils.getAllownaceKey(collateralToken, _puppetList[i])] = _sampledAllowanceList[i];
    //     }
    // }
}
