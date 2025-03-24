// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    enum AjustmentType {
        INCREASE,
        DECREASE,
        LIQUIDATE
    }

    function getMatchKey(IERC20 collateralToken, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, trader));
    }

    function getAllocationKey(address[] calldata _puppetList, bytes32 _matchKey, uint allocationId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_puppetList, _matchKey, allocationId));
    }
}
