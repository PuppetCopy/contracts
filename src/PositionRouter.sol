// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {WNT} from "./utils/WNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {IGmxExchangeRouter} from "./position/interface/IGmxExchangeRouter.sol";
import {IncreasePosition} from "./position/logic/IncreasePosition.sol";

import {PositionUtils} from "./position/util/PositionUtils.sol";
import {PositionLogic} from "./position/PositionLogic.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {SubaccountStore} from "./position/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";

import {IGmxDatastore} from "./position/interface/IGmxDatastore.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";

contract PositionRouter is MulticallRouter, IGmxOrderCallbackReceiver {
    event PositionRouter__SetConfig(uint timestamp, PositionRouterConfig config);

    struct PositionRouterParams {
        Dictator dictator;
        WNT wnt;
        Router router;
        PositionStore positionStore;
    }

    struct PositionRouterConfig {
        Router router;
        PositionLogic positionLogic;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
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
    }

    function requestIncreasePosition(PositionUtils.CallPositionAdjustment calldata callIncreaseParams) external nonReentrant {
        IncreasePosition.CallConfig memory callConfig = IncreasePosition.CallConfig({
            router: params.router,
            subaccountStore: config.subaccountStore,
            positionStore: config.positionStore,
            puppetStore: config.puppetStore,
            gmxExchangeRouter: config.gmxExchangeRouter,
            gmxDatastore: config.gmxDatastore,
            depositCollateralToken: config.depositCollateralToken,
            feeReceiver: config.feeReceiver,
            trader: msg.sender,
            referralCode: config.referralCode,
            limitPuppetList: config.limitPuppetList,
            adjustmentFeeFactor: config.adjustmentFeeFactor,
            minMatchExpiryDuration: config.minMatchExpiryDuration,
            callbackGasLimit: config.callbackGasLimit,
            minMatchTokenAmount: config.minMatchTokenAmount
        });

        config.positionLogic.requestIncreasePosition(callConfig, callIncreaseParams);
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
        IncreasePosition.CallbackConfig memory callConfig = IncreasePosition.CallbackConfig({
            positionStore: config.positionStore,
            gmxCallbackOperator: config.gmxCallbackOperator,
            caller: msg.sender
        });

        config.positionLogic.handlOperatorCallback(callConfig, key, order, eventData);
    }

    function _setConfig(PositionRouterConfig memory _config) internal {
        config = _config;

        emit PositionRouter__SetConfig(block.timestamp, _config);
    }

    // governance

    // function setRewardLogic(RewardLogic rewardLogic) external requiresAuth {
    //     config.rewardLogic = rewardLogic;
    // }
}
