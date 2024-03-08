// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ==================== BaseRouteFactory ========================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {IDataStore} from "./utilities/interfaces/IDataStore.sol";

/// @title BaseRouteFactory
/// @author johnnyonline
/// @notice BaseRouteFactory is used by the Orchestrator to create new Route Accounts
abstract contract BaseRouteFactory {
    function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) virtual external returns (address _route);
}