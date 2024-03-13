// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {Subaccount} from "./../util/Subaccount.sol";

contract PositionStore is StoreController {
    struct RequestAdjustment {
        bytes32 requestKey;
        bytes32 positionKey;
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

    mapping(address => Subaccount) public traderSubaccountMap;

    address public logicContractImplementation;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRequestAdjustment(bytes32 _key) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_key];
    }

    function setRequestAdjustment(bytes32 _key, RequestAdjustment memory _ra) external isSetter {
        requestAdjustmentMap[_key] = _ra;
    }

    function removeRequestAdjustment(bytes32 _key) external isSetter {
        delete requestAdjustmentMap[_key];
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

    function setTraderSubaccount(address _trader, Subaccount _proxy) external isSetter {
        traderSubaccountMap[_trader] = _proxy;
    }

    function setLogicContractImplementation(address _positionLogicImplementation) external isSetter {
        logicContractImplementation = _positionLogicImplementation;
    }
}
