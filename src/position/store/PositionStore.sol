// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {TraderSubAccount} from "./../utils/TraderSubAccount.sol";

contract PositionStore is StoreController {
    struct RequestMirrorPositionAdjustment {
        bytes32 requestKey;
        address[] puppetList;
        uint[] puppetCollateralDeltaList;
        uint sizeDelta;
        uint collateralDelta;
        uint leverage;
    }

    struct MirrorPosition {
        address[] puppetList;
        uint[] puppetDepositList;
        uint deposit;
        uint size;
        uint leverage;
    }

    address public positionLogicImplementation;

    mapping(bytes32 requestKey => RequestMirrorPositionAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;

    mapping(address => TraderSubAccount) public traderSubAccountMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRequestMirrorPositionAdjustment(bytes32 _requestKey) external view returns (RequestMirrorPositionAdjustment memory) {
        return requestAdjustmentMap[_requestKey];
    }

    function setRequestMirrorPositionAdjustment(bytes32 _requestKey, RequestMirrorPositionAdjustment memory _rmpa) external isSetter {
        requestAdjustmentMap[_requestKey] = _rmpa;
    }

    function removeRequestMirrorPositionAdjustment(bytes32 _requestKey) external isSetter {
        delete requestAdjustmentMap[_requestKey];
    }

    function getMirrorPosition(bytes32 _positionKey) external view returns (MirrorPosition memory) {
        return positionMap[_positionKey];
    }

    function setMirrorPosition(bytes32 _positionKey, MirrorPosition memory _mp) external isSetter {
        positionMap[_positionKey] = _mp;
    }

    function removeMirrorPosition(bytes32 _positionKey) external isSetter {
        delete positionMap[_positionKey];
    }

    function setPositionLogicImplementation(address _positionLogicImplementation) external isSetter {
        positionLogicImplementation = _positionLogicImplementation;
    }

    function setTraderProxy(address _trader, TraderSubAccount _proxy) external isSetter {
        traderSubAccountMap[_trader] = _proxy;
    }
}
