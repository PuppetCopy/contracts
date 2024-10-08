// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.27;

interface IGmxOracle {
    function getStablePrice(address dataStore, address token) external view returns (uint);
}
