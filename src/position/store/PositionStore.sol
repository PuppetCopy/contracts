// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";

contract PositionStore is StoreController {
    struct RequestAdjustment {
        bytes32 requestKey;
        bytes32 positionKey;
        uint sizeDelta;
        uint collateralDelta;
        uint leverage;
        uint[] puppetCollateralDeltaList;
        address[] puppetList;
        bytes32[] ruleKeyList;
    }

    struct MirrorPosition {
        address[] puppetList;
        uint[] puppetDepositList;
        uint deposit;
        uint size;
        uint leverage;
        uint latestUpdateTimestamp;
    }

    mapping(address => RequestAdjustment) public pendingTraderRequestMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getPendingTraderRequest(address _address) external view returns (RequestAdjustment memory) {
        return pendingTraderRequestMap[_address];
    }

    function setPendingTraderRequest(address _address, RequestAdjustment memory _req) external isSetter {
        pendingTraderRequestMap[_address] = _req;
    }

    function removePendingTraderRequest(address _address) external isSetter {
        delete pendingTraderRequestMap[_address];
    }

    function getMirrorPosition(bytes32 _key) external view returns (MirrorPosition memory) {
        return positionMap[_key];
    }

    function setMirrorPosition(bytes32 _key, MirrorPosition memory _mp) external isSetter {
        positionMap[_key] = _mp;
    }

    function removeMirrorPosition(bytes32 _key) external isSetter {
        delete positionMap[_key];
    }
}
