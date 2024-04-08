// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {PositionStore} from "../store/PositionStore.sol";

library ExecuteIncreasePosition {
    struct CallConfig {
        PositionStore positionStore;
        address gmxOrderHandler;
    }

    function increase(CallConfig memory callConfig, bytes32 key, GmxPositionUtils.Props memory order) external {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getRequestAdjustment(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (mirrorPosition.size == 0) {
            PositionStore.RequestMatch memory matchRequest = callConfig.positionStore.getRequestMatch(positionKey);
            mirrorPosition.trader = matchRequest.trader;
            mirrorPosition.puppetList = matchRequest.puppetList;

            callConfig.positionStore.removeRequestMatch(positionKey);
        }

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
        callConfig.positionStore.removeRequestAdjustment(key);
    }

    error ExecuteIncreasePosition__UnauthorizedCaller();
}
