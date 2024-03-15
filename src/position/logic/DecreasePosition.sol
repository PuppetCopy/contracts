// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PositionUtils} from "../util/PositionUtils.sol";
import {PositionStore} from "../store/PositionStore.sol";

library DecreasePosition {
    function executeDecreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        PositionStore.RequestIncreaseAdjustment calldata request
    ) external {}

    function _requestDecreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        PositionStore.RequestIncreaseAdjustment memory request,
        bytes32 positionKey
    ) internal returns (bytes32 requestKey) {
        // ...
    }
}
