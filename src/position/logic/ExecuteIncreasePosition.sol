// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {PositionStore} from "../store/PositionStore.sol";

library ExecuteIncreasePosition {
    struct CallConfig {
        PositionStore positionStore;
        address gmxOrderHandler;
    }

    struct CallParams {
        PositionStore.MirrorPosition mirrorPosition;
        IGmxEventUtils.EventLogData eventLogData;
        bytes32 positionKey;
        bytes32 requestKey;
        bytes32 routeKey;
        address outputTokenAddress;
        address puppetStoreAddress;
        IERC20 outputToken;
        uint totalAmountOut;
    }

    function increase(CallConfig memory callConfig, bytes32 key, GmxPositionUtils.Props memory order) external {

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestIncrease memory request = callConfig.positionStore.getRequestIncreaseMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.totalCollateral += order.numbers.initialCollateralDeltaAmount;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.totalSize += order.numbers.sizeDeltaUsd;

        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
        callConfig.positionStore.removeRequestIncreaseMap(key);
    }

    error ExecuteIncreasePosition__UnauthorizedCaller();
}
