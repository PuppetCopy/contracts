// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IGMXDataStore} from "./IGMXDataStore.sol";
import {IGMXMarket} from "./IGMXMarket.sol";
import {IGMXPosition} from "./IGMXPosition.sol";

interface IGMXReader {
    function getMarketBySalt(address dataStore, bytes32 salt) external view returns (IGMXMarket.Props memory);
    function getPosition(IGMXDataStore dataStore, bytes32 key) external view returns (IGMXPosition.Props memory);
}