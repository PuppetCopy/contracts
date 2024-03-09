// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

library PositionKey {
    function getRouteKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(market, isLong));
    }

    function getSubscriptionsKey(address puppet, address trader, address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(puppet, trader, market, isLong));
    }
}
