// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";

import {Router} from "src/utils/Router.sol";

import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {PositionLogic} from "./../PositionLogic.sol";

import {GmxOrder} from "./GmxOrder.sol";

library ExecutePosition {
    struct CallConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        address gmxOrderHandler;
    }

    function increase(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);
        PositionStore.RequestIncrease memory request = callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey);

        mirrorPosition.size += order.numbers.sizeDeltaUsd;
        mirrorPosition.collateral += order.numbers.initialCollateralDeltaAmount;

        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
        callConfig.positionStore.removePendingRequestIncreaseAdjustmentMap(positionKey);

        if (request.sizeDelta < 0) {
            // GmxOrder.call(gmxCallConfig, callParams, request);
            // RequestDecreasePosition.request(callConfig, callIncreaseParams);
        }

        // address outputToken = eventLogData.addressItems.items[0].value;
        // uint outputAmount = eventLogData.uintItems.items[0].value;
    }

    function decrease(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecutePosition__UnexpectedEventData();
        }

        address outputToken = eventLogData.addressItems.items[0].value;
        uint outputAmount = eventLogData.uintItems.items[0].value;

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );
        callConfig.positionStore.removePendingRequestIncreaseAdjustmentMap(positionKey);

        // request.subaccount.depositToken(callConfig.router, callConfig.depositCollateralToken, callParams.collateralDelta);
        // SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subaccountAddress, request.collateralDelta);
    }

    error ExecutePosition__UnexpectedEventData();
}
