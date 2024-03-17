// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PositionUtils} from "../util/PositionUtils.sol";
import {PositionStore} from "../store/PositionStore.sol";

library DecreasePosition {
    function executeDecreasePosition() external {}

    function _requestDecreasePosition() internal returns (bytes32 requestKey) {
        // ...
    }
}
