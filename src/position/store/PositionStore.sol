// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {GmxPositionUtils} from "./../util/GmxPositionUtils.sol";
import {Subaccount} from "./../util/Subaccount.sol";

contract PositionStore is StoreController {
    struct RequestIncrease {
        bytes32 requestKey;
        bytes32 routeKey;
        uint collateralDelta;
        int sizeDelta;
        uint targetLeverage;
        uint[] puppetCollateralDeltaList;
        bytes32 positionKey;
        IERC20 collateralToken;
        Subaccount subaccount;
        address subaccountAddress;
        MirrorPosition mirrorPosition;
    }

    struct MirrorPosition {
        uint size;
        uint collateral;
        uint[] puppetDepositList;
        address[] puppetList;
    }

    struct UnhandledCallbackMap {
        GmxPositionUtils.Props order;
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

    function setUnhandledCallbackMap(bytes32 _key, GmxPositionUtils.Props calldata _order, bytes calldata _eventData) external isSetter {
        PositionStore.UnhandledCallbackMap memory callbackResponse = PositionStore.UnhandledCallbackMap({order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallbackMap(bytes32 _key) external view returns (UnhandledCallbackMap memory) {
        return unhandledCallbackMap[_key];
    }
}
