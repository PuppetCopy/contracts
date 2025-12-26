// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {GmxPositionParser} from "./GmxPositionParser.sol";

/**
 * @title PositionScope
 * @notice Tracks utilization and settlement per isolated position
 * @dev Each GMX position gets its own distribution scope, preventing mixing
 *
 * Flow:
 * 1. Master creates order → preCheck detects, creates scope with allocation snapshot
 * 2. Order executes → callback detected, scope marked as "active"
 * 3. Position closes → callback detected, settlement attributed to scope
 * 4. Puppets claim from their specific scope participation
 */
contract PositionScope {
    using GmxPositionParser for bytes;

    struct Scope {
        bytes32 positionKey;        // GMX position key
        address collateralToken;    // Collateral used
        uint256 totalUtilization;   // Total funds utilized for this position
        uint256 totalSettlement;    // Settlement received (could be > or < utilization)
        uint256 snapshotTime;       // When scope was created
        bool settled;               // Position fully closed
    }

    struct UserScopeData {
        uint256 utilization;        // User's contribution to this scope
        uint256 claimed;            // Amount already claimed
    }

    // Active scopes per matching key (collateral + master)
    mapping(bytes32 => bytes32[]) public activeScopeKeys;

    // Scope data
    mapping(bytes32 => Scope) public scopes;

    // User participation per scope
    mapping(bytes32 => mapping(address => UserScopeData)) public userScopes;

    // Pending order tracking (order submitted but not yet executed)
    mapping(bytes32 => bytes32) public pendingOrderToScope; // orderKey => scopeKey

    // ===================== Core Logic =====================

    /**
     * @notice Called from hook preCheck to detect position actions
     * @param _master The master's subaccount
     * @param _target Target contract being called
     * @param _callData The call data
     * @param _allocationSnapshot Current allocation state to snapshot
     */
    function onPreCheck(
        address _master,
        address _target,
        bytes calldata _callData,
        mapping(address => uint256) storage _allocationSnapshot
    ) internal returns (bytes32 scopeKey) {
        GmxPositionParser.PositionContext memory ctx = GmxPositionParser.parseAction(
            _master,
            _target,
            _callData
        );

        if (ctx.positionKey == bytes32(0)) return bytes32(0);

        scopeKey = _getScopeKey(ctx.positionKey, block.timestamp);

        if (ctx.isIncrease) {
            // Opening or adding to position
            Scope storage scope = scopes[scopeKey];

            if (scope.positionKey == bytes32(0)) {
                // New scope - initialize
                scope.positionKey = ctx.positionKey;
                scope.collateralToken = ctx.collateralToken;
                scope.snapshotTime = block.timestamp;

                bytes32 matchingKey = keccak256(abi.encode(ctx.collateralToken, _master));
                activeScopeKeys[matchingKey].push(scopeKey);
            }

            // Utilization will be recorded in postCheck when we see balance decrease
        }

        return scopeKey;
    }

    /**
     * @notice Called from hook postCheck to record utilization or settlement
     * @param _master The master's subaccount
     * @param _scopeKey The scope key from preCheck
     * @param _balanceChange Positive = settlement arrived, Negative = utilization
     * @param _puppetUtilizations How much each puppet contributed
     */
    function onPostCheck(
        address _master,
        bytes32 _scopeKey,
        int256 _balanceChange,
        address[] memory _puppets,
        uint256[] memory _puppetUtilizations
    ) internal {
        if (_scopeKey == bytes32(0)) return;

        Scope storage scope = scopes[_scopeKey];

        if (_balanceChange < 0) {
            // Funds left account = utilization for this position
            uint256 utilized = uint256(-_balanceChange);
            scope.totalUtilization += utilized;

            // Record per-puppet utilization for this scope
            for (uint256 i = 0; i < _puppets.length; i++) {
                userScopes[_scopeKey][_puppets[i]].utilization += _puppetUtilizations[i];
            }
        } else if (_balanceChange > 0) {
            // Funds arrived = settlement for this position
            uint256 settlement = uint256(_balanceChange);
            scope.totalSettlement += settlement;

            // Check if position is fully closed (no remaining size)
            // This would need to be determined from callback data
        }
    }

    /**
     * @notice Called when GMX callback indicates position is closed
     */
    function onPositionClosed(bytes32 _scopeKey) internal {
        scopes[_scopeKey].settled = true;
    }

    /**
     * @notice Calculate pending settlement for a user across all their scopes
     * @param _matchingKey The collateral + master key
     * @param _user The puppet address
     */
    function getPendingSettlement(
        bytes32 _matchingKey,
        address _user
    ) external view returns (uint256 pending) {
        bytes32[] memory scopeKeys = activeScopeKeys[_matchingKey];

        for (uint256 i = 0; i < scopeKeys.length; i++) {
            bytes32 scopeKey = scopeKeys[i];
            Scope memory scope = scopes[scopeKey];
            UserScopeData memory userData = userScopes[scopeKey][_user];

            if (userData.utilization == 0) continue;
            if (scope.totalUtilization == 0) continue;

            // User's share of settlement for this scope
            uint256 userShare = (scope.totalSettlement * userData.utilization) / scope.totalUtilization;
            uint256 unclaimed = userShare > userData.claimed ? userShare - userData.claimed : 0;

            pending += unclaimed;
        }
    }

    /**
     * @notice Claim settlement from settled scopes
     * @param _matchingKey The collateral + master key
     * @param _user The puppet address
     */
    function claim(
        bytes32 _matchingKey,
        address _user
    ) internal returns (uint256 totalClaimed) {
        bytes32[] storage scopeKeys = activeScopeKeys[_matchingKey];

        for (uint256 i = 0; i < scopeKeys.length; i++) {
            bytes32 scopeKey = scopeKeys[i];
            Scope storage scope = scopes[scopeKey];
            UserScopeData storage userData = userScopes[scopeKey][_user];

            if (userData.utilization == 0) continue;
            if (scope.totalUtilization == 0) continue;

            // Calculate user's share
            uint256 userShare = (scope.totalSettlement * userData.utilization) / scope.totalUtilization;
            uint256 unclaimed = userShare > userData.claimed ? userShare - userData.claimed : 0;

            if (unclaimed > 0) {
                userData.claimed += unclaimed;
                totalClaimed += unclaimed;
            }

            // If scope is settled and user fully claimed, could clean up
            // But keeping for auditability
        }
    }

    // ===================== Helpers =====================

    /**
     * @notice Generate unique scope key
     * @dev Includes timestamp to allow multiple positions on same market
     */
    function _getScopeKey(
        bytes32 _positionKey,
        uint256 _timestamp
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(_positionKey, _timestamp));
    }

    /**
     * @notice Get active scope for a position (most recent)
     */
    function getActiveScope(
        bytes32 _matchingKey,
        bytes32 _positionKey
    ) external view returns (bytes32) {
        bytes32[] memory scopeKeys = activeScopeKeys[_matchingKey];

        // Return most recent scope for this position
        for (uint256 i = scopeKeys.length; i > 0; i--) {
            if (scopes[scopeKeys[i - 1]].positionKey == _positionKey &&
                !scopes[scopeKeys[i - 1]].settled) {
                return scopeKeys[i - 1];
            }
        }

        return bytes32(0);
    }
}
