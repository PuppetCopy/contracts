// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getUserGeneratedRevenueKey(IERC20 token, address from, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, from, account));
    }

    function getRuleKey(IERC20 collateralToken, address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, puppet, trader));
    }

    function getAllownaceKey(IERC20 collateralToken, address puppet) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, puppet));
    }

    function getFundingActivityKey(address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader));
    }
}
