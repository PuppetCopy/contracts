// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getRouteKey(IERC20 token, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(token, trader));
    }
}
