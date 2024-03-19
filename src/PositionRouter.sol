// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {IGmxDatastore} from "./position/interface/IGmxDatastore.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {IGmxExchangeRouter} from "./position/interface/IGmxExchangeRouter.sol";
import {RequestIncreasePosition} from "./position/logic/RequestIncreasePosition.sol";
import {ExecutePosition} from "./position/logic/ExecutePosition.sol";

import {GmxPositionUtils} from "./position/util/GmxPositionUtils.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {SubaccountStore} from "./position/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PositionLogic} from "./position/PositionLogic.sol";
import {SubaccountLogic} from "./position/util/SubaccountLogic.sol";
import {GmxOrder} from "./position/logic/GmxOrder.sol";
import {PuppetLogic} from "./position/PuppetLogic.sol";

import {Subaccount} from "./position/util/Subaccount.sol";

contract PositionRouter is Auth, ReentrancyGuard, IGmxOrderCallbackReceiver {
    event PositionRouter__SetConfig(uint timestamp, PositionRouterConfig config);

    struct PositionRouterParams {
        Dictator dictator;
        Router router;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        PuppetStore puppetStore;
    }

    struct PositionRouterConfig {
        Router router;
        SubaccountLogic subaccountLogic;
        PositionLogic positionLogic;
        PuppetLogic puppetLogic;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address gmxRouter;
        address dao;
        address feeReceiver;
        address gmxCallbackCaller;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint minExecutionFee;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
        bytes32 referralCode;
    }

    PositionRouterParams params;
    PositionRouterConfig config;

    constructor(Authority _authority, PositionRouterParams memory _params, PositionRouterConfig memory _config) Auth(address(0), _authority) {
        _setConfig(_config);
        params = _params;
    }

    function createSubaccount(address account) external nonReentrant {
        config.subaccountLogic.createSubaccount(params.subaccountStore, account);
    }

    function request(GmxOrder.CallParams calldata callParams) external nonReentrant {
        Subaccount subaccount = params.subaccountStore.getSubaccount(msg.sender);
        address subaccountAddress = address(subaccount);

        config.positionLogic.requestIncreasePosition(
            GmxOrder.CallConfig({
                router: config.router,
                positionStore: params.positionStore,
                gmxExchangeRouter: config.gmxExchangeRouter,
                gmxRouter: config.gmxRouter,
                gmxCallbackOperator: address(this),
                feeReceiver: config.feeReceiver,
                referralCode: config.referralCode,
                callbackGasLimit: config.callbackGasLimit
            }),
            RequestIncreasePosition.RequestConfig({
                puppetLogic: config.puppetLogic,
                puppetStore: params.puppetStore,
                gmxDatastore: config.gmxDatastore,
                trader: msg.sender,
                limitPuppetList: config.limitPuppetList,
                adjustmentFeeFactor: config.adjustmentFeeFactor,
                callbackGasLimit: config.callbackGasLimit,
                minMatchTokenAmount: config.minMatchTokenAmount,
                subaccount: subaccount,
                subaccountAddress: subaccountAddress
            }),
            callParams
        );
    }

    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    // internal

    function _handlOperatorCallback(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) internal {
        if (config.gmxCallbackCaller != msg.sender) revert PositionLogic__UnauthorizedCaller();

        try config.positionLogic.handlOperatorCallback(
            ExecutePosition.CallConfig({
                positionStore: params.positionStore,
                puppetStore: params.puppetStore,
                gmxCallbackOperator: address(this),
                caller: msg.sender
            }),
            key,
            order,
            eventData
        ) {} catch {
            // store callback data, the rest of the logic will attempt to execute the callback data
            // in case of failure we can recovery the callback data and attempt to execute it again
            params.positionStore.setUnhandledCallbackMap(key, order, eventData);
        }
    }

    // governance

    function setConfig(PositionRouterConfig memory _config) external requiresAuth {
        _setConfig(_config);
    }

    function _setConfig(PositionRouterConfig memory _config) internal {
        config = _config;

        emit PositionRouter__SetConfig(block.timestamp, _config);
    }

    error PositionLogic__UnauthorizedCaller();
}
