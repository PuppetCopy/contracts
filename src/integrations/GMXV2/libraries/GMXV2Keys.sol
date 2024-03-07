// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ======================== RouteReader =========================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

/// @title GMXV2Keys
/// @author johnnyonline
/// @notice Keys for values in the DataStore
library GMXV2Keys {

    /// @dev key for GMX V2's Router
    bytes32 public constant ROUTER = keccak256(abi.encode("GMXV2_ROUTER"));
    /// @dev key for GMX V2's Exchange Router
    bytes32 public constant EXCHANGE_ROUTER = keccak256(abi.encode("GMXV2_EXCHANGE_ROUTER"));
    /// @dev key for GMX V2's Order Vault
    bytes32 public constant ORDER_VAULT = keccak256(abi.encode("GMXV2_ORDER_VAULT"));
    /// @dev key for GMX V2's Order Handler
    bytes32 public constant ORDER_HANDLER = keccak256(abi.encode("GMXV2_ORDER_HANDLER"));
    /// @dev key for GMX V2's Reader
    bytes32 public constant GMX_READER = keccak256(abi.encode("GMXV2_GMX_READER"));
    /// @dev key for GMX V2's DataStore
    bytes32 public constant GMX_DATA_STORE = keccak256(abi.encode("GMXV2_GMX_DATA_STORE"));

    // -------------------------------------------------------------------------------------------

    function routeMarketToken(address _route) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("GMXV2_ROUTE_MARKET_TOKEN", _route));
    }
}