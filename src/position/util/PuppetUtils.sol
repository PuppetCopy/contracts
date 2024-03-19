// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library PuppetUtils {
    function getRuleKey(address puppet, bytes32 routeKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, routeKey));
    }

    function getRuleKey(address puppet, address trader, address collateralToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, getRouteKey(trader, collateralToken)));
    }

    function getRouteKey(address trader, address collateralToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(trader, collateralToken));
    }
}
