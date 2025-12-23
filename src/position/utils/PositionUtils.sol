// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getTraderMatchingKey(IERC20 collateralToken, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(collateralToken, trader));
    }
}
