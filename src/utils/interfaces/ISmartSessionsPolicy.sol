// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PackedUserOperation} from "./IERC7579Module.sol";

// ============ Smart Sessions Types ============

/// @notice Unique identifier for a permission configuration
type ConfigId is bytes32;

/// @notice Unique identifier for a permission
type PermissionId is bytes32;

/// @notice Unique identifier for an action
type ActionId is bytes32;

// Empty constants
ConfigId constant EMPTY_CONFIGID = ConfigId.wrap(bytes32(0));
PermissionId constant EMPTY_PERMISSIONID = PermissionId.wrap(bytes32(0));
ActionId constant EMPTY_ACTIONID = ActionId.wrap(bytes32(0));

// Validation return values
uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILED = 1;

// ============ Policy Interfaces ============

/**
 * @title IPolicy
 * @notice Base interface for Smart Sessions policies
 * @dev External contracts that enforce policies/permissions on 4337/7579 executions
 *
 * Storage pattern: mapping(ConfigId => mapping(multiplexer => mapping(account => state)))
 * - ConfigId: unique identifier for this policy configuration
 * - multiplexer: the SmartSessions module address (msg.sender during validation)
 * - account: the smart account this policy applies to
 */
interface IPolicy is IERC165 {
    /// @notice Emitted when a policy is configured for an account
    event PolicySet(ConfigId indexed id, address indexed multiplexer, address indexed account);

    /// @notice Thrown when policy is not initialized for the given parameters
    error PolicyNotInitialized(ConfigId id, address multiplexer, address account);

    /**
     * @notice Initialize policy configuration for an account
     * @dev Called by SmartSessions when enabling a session with this policy.
     *      MUST overwrite current state (not merge).
     *      Should minimize external calls during validation phase.
     * @param account The smart account address
     * @param configId Unique identifier for this configuration
     * @param initData Policy-specific initialization data
     */
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external;
}

/**
 * @title IUserOpPolicy
 * @notice Policy interface for validating entire UserOperations
 * @dev Called during ERC-4337 validation phase
 */
interface IUserOpPolicy is IPolicy {
    /**
     * @notice Validate a UserOperation against this policy
     * @param id The configuration identifier
     * @param userOp The packed user operation to validate
     * @return VALIDATION_SUCCESS (0) or VALIDATION_FAILED (1)
     */
    function checkUserOpPolicy(
        ConfigId id,
        PackedUserOperation calldata userOp
    ) external returns (uint256);
}

/**
 * @title IActionPolicy
 * @notice Policy interface for validating individual actions within executions
 * @dev Called for each action in batched ERC-7579 executions
 */
interface IActionPolicy is IPolicy {
    /**
     * @notice Validate an action against this policy
     * @param id The configuration identifier
     * @param account The smart account executing the action
     * @param target The target contract being called
     * @param value The ETH value being sent
     * @param data The calldata for the action
     * @return VALIDATION_SUCCESS (0) or VALIDATION_FAILED (1)
     */
    function checkAction(
        ConfigId id,
        address account,
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (uint256);
}

/**
 * @title I1271Policy
 * @notice Policy interface for validating ERC-1271 signatures
 * @dev Used to restrict what can be signed via the smart account
 */
interface I1271Policy is IPolicy {
    /**
     * @notice Validate an ERC-1271 signature request
     * @param id The configuration identifier
     * @param requestSender The address requesting signature validation
     * @param account The smart account
     * @param hash The hash being signed
     * @param signature The signature data
     * @return True if signature should be allowed
     */
    function check1271SignedAction(
        ConfigId id,
        address requestSender,
        address account,
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bool);
}

// ============ Helper Library ============

/**
 * @title ConfigIdLib
 * @notice Helper functions for ConfigId type
 */
library ConfigIdLib {
    function eq(ConfigId a, ConfigId b) internal pure returns (bool) {
        return ConfigId.unwrap(a) == ConfigId.unwrap(b);
    }

    function isNull(ConfigId id) internal pure returns (bool) {
        return ConfigId.unwrap(id) == bytes32(0);
    }
}
