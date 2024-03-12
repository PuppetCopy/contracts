// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

library PuppetUtils {
    function getRuleKey(address puppet, address trader, bytes32 routeKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader, routeKey));
    }
}
