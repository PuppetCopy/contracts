// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";

contract PositionStore is StoreController {
    struct RequestIncreaseAdjustment {
        bytes32 requestKey;
        int sizeDelta;
        uint collateralDelta;
        uint targetLeverage;
        uint[] puppetCollateralDeltaList;
    }

    struct MirrorPosition {
        uint collateral;
        uint size;
        uint leverage;
        uint latestUpdateTimestamp;
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct CallbackResponse {
        bytes32 key;
        PositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 positionKey => RequestIncreaseAdjustment) public pendingRequestIncreaseAdjustmentMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;
    mapping(bytes32 positionKey => CallbackResponse) public callbackResponseMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getPendingRequestIncreaseAdjustmentMap(bytes32 _key) external view returns (RequestIncreaseAdjustment memory) {
        return pendingRequestIncreaseAdjustmentMap[_key];
    }

    function setPendingRequestIncreaseAdjustmentMap(bytes32 _key, RequestIncreaseAdjustment memory _req) external isSetter {
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

    function setCallbackResponse(bytes32 _key, CallbackResponse calldata _callbackResponse) external isSetter {
        callbackResponseMap[_key] = _callbackResponse;
    }

    function getCallbackResponse(bytes32 _key) external view returns (CallbackResponse memory) {
        return callbackResponseMap[_key];
    }
}
