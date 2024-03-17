// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library PuppetUtils {
    function getPuppetTraderKey(address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader));
    }
}
