// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ====================== IBaseRouteFactory =====================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {IDataStore} from "../utilities/interfaces/IDataStore.sol";

interface IBaseRouteFactory {

    // ============================================================================================
    // External Functions
    // ============================================================================================

    /// @notice The ```registerRoute``` function deploys a new Route Account contract
    /// @param _dataStore The dataStore contract address
    /// @param _routeTypeKey The routeTypeKey
    /// @return _route The address of the new Route
    function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) external returns (address _route);

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterRoute(address indexed caller, address route, address dataStore, bytes32 routeTypeKey);
}