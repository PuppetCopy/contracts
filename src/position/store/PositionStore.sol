// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";
import {Subaccount} from "./../util/Subaccount.sol";

contract PositionStore is StoreController {
    struct RequestIncrease {
        bytes32 requestKey;
        int sizeDelta;
        uint collateralDelta;
        uint targetLeverage;
        uint[] puppetCollateralDeltaList;
        bytes32 positionKey;
        Subaccount subaccount;
        address subaccountAddress;
    }

    struct MirrorPosition {
        uint collateral;
        uint size;
        uint leverage;
        uint latestUpdateTimestamp;
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct UnhandledCallbackMap {
        PositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 positionKey => RequestIncrease) public pendingRequestIncreaseAdjustmentMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallbackMap) public unhandledCallbackMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getPendingRequestIncreaseAdjustmentMap(bytes32 _key) external view returns (RequestIncrease memory) {
        return pendingRequestIncreaseAdjustmentMap[_key];
    }

    function setPendingRequestIncreaseAdjustmentMap(bytes32 _key, RequestIncrease memory _req) external isSetter {
        pendingRequestIncreaseAdjustmentMap[_key] = _req;
    }

    function removePendingRequestIncreaseAdjustmentMap(bytes32 _key) external isSetter {
        delete pendingRequestIncreaseAdjustmentMap[_key];
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

    function setUnhandledCallbackMap(bytes32 _key, PositionUtils.Props calldata _order, bytes calldata _eventData) external isSetter {
        PositionStore.UnhandledCallbackMap memory callbackResponse = PositionStore.UnhandledCallbackMap({order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallbackMap(bytes32 _key) external view returns (UnhandledCallbackMap memory) {
        return unhandledCallbackMap[_key];
    }
}
