// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {GmxPositionUtils} from "./../util/GmxPositionUtils.sol";

contract PositionStore is StoreController {
    struct RequestIncrease {
        address trader;
        uint[] puppetCollateralDeltaList;
        uint leverage;
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
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct UnhandledCallbackMap {
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 requestKey => RequestIncrease) public requestIncreaseMap;
    // mapping(bytes32 requestKey => RequestIncrease) public requestReduceTargetLeverageMap;
    mapping(bytes32 requestKey => RequestDecrease) public requestDecreaseMap;

    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallbackMap) public unhandledCallbackMap;

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

    // function getRequestReduceTargetLeverageMap(bytes32 _key) external view returns (RequestIncrease memory) {
    //     return requestReduceTargetLeverageMap[_key];
    // }

    // function setRequestReduceTargetLeverageMap(bytes32 _key, RequestIncrease calldata _req) external isSetter {
    //     requestReduceTargetLeverageMap[_key] = _req;
    // }

    // function removeRequestReduceTargetLeverageMap(bytes32 _key) external isSetter {
    //     delete requestReduceTargetLeverageMap[_key];
    // }

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

    function setUnhandledCallbackMap(bytes32 _key, GmxPositionUtils.Props calldata _order, bytes calldata _eventData) external isSetter {
        PositionStore.UnhandledCallbackMap memory callbackResponse = PositionStore.UnhandledCallbackMap({order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallbackMap(bytes32 _key) external view returns (UnhandledCallbackMap memory) {
        return unhandledCallbackMap[_key];
    }
}
