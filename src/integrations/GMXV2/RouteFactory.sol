// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ====================== RouteFactory ==========================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {GMXV2Keys} from "./libraries/GMXV2Keys.sol";

import {BaseRouteFactory, IDataStore} from "../../integrations/BaseRouteFactory.sol";

import {TradeRoute} from "./TradeRoute.sol";
import {Keys} from "../libraries/Keys.sol";

/// @title RouteFactory
/// @notice This contract extends the ```BaseRouteFactory``` and is modified to fit GMX V2
contract RouteFactory is BaseRouteFactory {
    /// @inheritdoc BaseRouteFactory
    function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) external override returns (address _route) {
        _route = address(new TradeRoute(_dataStore));

        bytes memory _data = _dataStore.getBytes(Keys.routeTypeDataKey(_routeTypeKey));
        address _marketToken = abi.decode(_data, (address));
        _dataStore.setAddress(GMXV2Keys.routeMarketToken(_route), _marketToken);

        emit RegisterRoute(msg.sender, _route, address(_dataStore), _routeTypeKey);
    }

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterRoute(address indexed caller, address route, address dataStore, bytes32 routeTypeKey);
}
