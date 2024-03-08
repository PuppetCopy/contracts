// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utilities/StoreController.sol";
import {TraderProxy} from "./../TraderProxy.sol";

contract PositionStore is StoreController {
    struct MirrorPosition {
        uint deposit;
        uint[] puppetAccountList;
        uint[] puppetDepositList;
    }

    address public positionLogicImplementation;

    struct ExecutionMediator {
        address callbackCaller;
        address positionLogic;
    }

    mapping(address => MirrorPosition) public mpMap;
    mapping(address => TraderProxy) public traderProxyMap;
    ExecutionMediator public mediator;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getMirrorPosition(address _user) external view returns (MirrorPosition memory) {
        return mpMap[_user];
    }

    function setMirrorPosition(address _user, MirrorPosition memory _mp) external isSetter {
        mpMap[_user] = _mp;
    }

    function setExecutionMediator(ExecutionMediator memory _mediator) external isSetter {
        mediator = _mediator;
    }

    function setPositionLogicImplementation(address _positionLogicImplementation) external isSetter {
        positionLogicImplementation = _positionLogicImplementation;
    }

    function setTraderProxy(address _trader, TraderProxy _proxy) external isSetter {
        traderProxyMap[_trader] = _proxy;
    }
    
}
