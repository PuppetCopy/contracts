// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {TraderSubAccount} from "./../utils/TraderSubAccount.sol";

contract PositionStore is StoreController {
    struct RequestAdjustment {
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

    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => MirrorPosition) public positionMap;

    mapping(address => TraderSubAccount) public traderSubaccountMap;

    address public logicContractImplementation;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRequestAdjustment(bytes32 _requestKey) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_requestKey];
    }

    function setRequestAdjustment(bytes32 _requestKey, RequestAdjustment memory _rmpa) external isSetter {
        requestAdjustmentMap[_requestKey] = _rmpa;
    }

    function removeRequestAdjustment(bytes32 _requestKey) external isSetter {
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

    function setTraderSubaccount(address _trader, TraderSubAccount _proxy) external isSetter {
        traderSubaccountMap[_trader] = _proxy;
    }

    function setLogicContractImplementation(address _positionLogicImplementation) external isSetter {
        logicContractImplementation = _positionLogicImplementation;
    }
}
