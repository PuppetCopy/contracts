// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {WNT} from "./utils/WNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {IGmxDatastore} from "./position/interface/IGmxDatastore.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {IGmxExchangeRouter} from "./position/interface/IGmxExchangeRouter.sol";
import {IncreasePosition} from "./position/logic/IncreasePosition.sol";

import {PositionUtils} from "./position/util/PositionUtils.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {SubaccountStore} from "./position/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PositionLogic} from "./position/PositionLogic.sol";
import {SubaccountLogic} from "./position/util/SubaccountLogic.sol";

contract PositionRouter is MulticallRouter, IGmxOrderCallbackReceiver {
    event PositionRouter__SetConfig(uint timestamp, PositionRouterConfig config);

    struct PositionRouterParams {
        Dictator dictator;
        WNT wnt;
        Router router;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        PuppetStore puppetStore;
    }

    struct PositionRouterConfig {
        Router router;
        PositionLogic positionLogic;
        SubaccountLogic subaccountLogic;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address gmxRouter;
        IERC20 depositCollateralToken;
        address dao;
        address feeReceiver;
        address gmxCallbackOperator;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint minMatchExpiryDuration;
        uint minExecutionFee;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
        bytes32 referralCode;
    }

    PositionRouterParams params;
    PositionRouterConfig config;

    constructor(Dictator dictator, WNT wnt, Router router, PositionRouterConfig memory _config, PositionRouterParams memory _params)
        MulticallRouter(dictator, wnt, router, _config.dao)
    {
        _setConfig(_config);
        params = _params;
        config.gmxCallbackOperator = address(this);
    }

    function createSubaccount(address account) external nonReentrant {
        config.subaccountLogic.createSubaccount(params.subaccountStore, account);
    }

    function requestIncreasePosition(IncreasePosition.CallParams calldata callParams) external nonReentrant {
        IncreasePosition.CallConfig memory callConfig = IncreasePosition.CallConfig({
            router: params.router,
            subaccountStore: params.subaccountStore,
            positionStore: params.positionStore,
            puppetStore: params.puppetStore,
            gmxExchangeRouter: config.gmxExchangeRouter,
            gmxDatastore: config.gmxDatastore,
            depositCollateralToken: config.depositCollateralToken,
            gmxRouter: config.gmxRouter,
            gmxCallbackOperator: config.gmxCallbackOperator,
            feeReceiver: config.feeReceiver,
            trader: msg.sender,
            referralCode: config.referralCode,
            limitPuppetList: config.limitPuppetList,
            adjustmentFeeFactor: config.adjustmentFeeFactor,
            callbackGasLimit: config.callbackGasLimit,
            minMatchTokenAmount: config.minMatchTokenAmount
        });

        config.positionLogic.requestIncreasePosition(callConfig, callParams);
    }

    function afterOrderExecution(bytes32 key, PositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderCancellation(bytes32 key, PositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderFrozen(bytes32 key, PositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function setConfig(PositionRouterConfig memory _config) external requiresAuth {
        _setConfig(_config);
    }

    // internal

    function _handlOperatorCallback(bytes32 key, PositionUtils.Props calldata order, bytes calldata eventData) internal {
        if (config.gmxCallbackOperator != msg.sender) revert PositionLogic__UnauthorizedCaller();

        try config.positionLogic.handlOperatorCallback(
            PositionUtils.CallbackConfig({
                positionStore: params.positionStore,
                puppetStore: params.puppetStore,
                gmxCallbackOperator: config.gmxCallbackOperator,
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

    function _setConfig(PositionRouterConfig memory _config) internal {
        config = _config;

        emit PositionRouter__SetConfig(block.timestamp, _config);
    }

    // governance

    // function setRewardLogic(RewardLogic rewardLogic) external requiresAuth {
    //     config.rewardLogic = rewardLogic;
    // }

    error PositionLogic__UnauthorizedCaller();
}
