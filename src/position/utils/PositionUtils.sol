// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getMatchKey(IERC20 collateralToken, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, trader));
    }

    function getAllocationKey(bytes32 matchKey, bytes32 positionKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(matchKey, positionKey));
    }
}
