// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    struct TraderCallParams {
        address account;
        address market;
        IERC20 collateralToken;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
    }

    function getCugarKey(IERC20 token, address user, uint cursorTime) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, user, cursorTime));
    }

    function getRuleKey(IERC20 token, address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(token, puppet, trader));
    }

    function getBalanceKey(IERC20 token, address puppet) internal pure returns (bytes32) {
        return keccak256(abi.encode(token, puppet));
    }

    function getFundingActivityKey(address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader));
    }
}
