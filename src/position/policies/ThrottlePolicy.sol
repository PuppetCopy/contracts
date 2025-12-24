// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {
    IActionPolicy,
    ConfigId,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "../../utils/interfaces/ISmartSessionsPolicy.sol";

/**
 * @title ThrottlePolicy
 * @notice Smart Sessions policy that enforces minimum time between transfers per recipient
 * @dev Tracks last activity timestamp per-recipient (trader subaccount) and validates throttle period has passed
 *
 * Usage:
 * 1. Puppet enables session with this policy
 * 2. Puppet sets throttle period (seconds between allowed transfers per trader)
 * 3. When session executes transfer, validates enough time has passed for that specific recipient
 *
 * This allows puppets to allocate to multiple traders without being globally throttled.
 * Each trader has independent throttle tracking.
 */
contract ThrottlePolicy is IActionPolicy {
    // ============ Types ============

    struct Config {
        uint32 throttlePeriod; // Seconds between allowed transfers
    }

    struct State {
        uint32 lastActivity; // Last transfer timestamp
    }

    // ============ Storage ============

    // ConfigId => multiplexer => account => config
    mapping(ConfigId => mapping(address => mapping(address => Config))) internal _configs;

    // ConfigId => multiplexer => account => recipient => state (per-trader throttling)
    mapping(ConfigId => mapping(address => mapping(address => mapping(address => State)))) internal _states;

    // ============ Errors ============

    error InvalidThrottlePeriod();

    // ============ ERC165 ============

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    // ============ IPolicy ============

    /**
     * @notice Initialize policy with throttle period
     * @param account The puppet account
     * @param configId Unique identifier for this configuration
     * @param initData ABI-encoded Config struct
     */
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external override {
        Config memory config = abi.decode(initData, (Config));

        _configs[configId][msg.sender][account] = config;
        // State is initialized per-recipient on first transfer (starts at 0)

        emit PolicySet(configId, msg.sender, account);
    }

    // ============ IActionPolicy ============

    /**
     * @notice Validate that throttle period has passed since last transfer to this recipient
     * @dev Updates lastActivity per-recipient on successful validation
     */
    function checkAction(
        ConfigId id,
        address account,
        address, /* target */
        uint256 value,
        bytes calldata data
    ) external override returns (uint256) {
        // No ETH transfers
        if (value != 0) return VALIDATION_FAILED;

        // Must be transfer call
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        // Decode recipient from transfer(address to, uint256 amount)
        address recipient = abi.decode(data[4:36], (address));

        Config memory config = _configs[id][msg.sender][account];
        State storage state = _states[id][msg.sender][account][recipient];

        // Check throttle (skip check if lastActivity is 0 - first transfer to this recipient)
        if (state.lastActivity != 0) {
            if (block.timestamp < state.lastActivity + config.throttlePeriod) {
                return VALIDATION_FAILED;
            }
        }

        // Update last activity for this recipient
        state.lastActivity = uint32(block.timestamp);

        return VALIDATION_SUCCESS;
    }

    // ============ View Functions ============

    function getConfig(
        ConfigId id,
        address multiplexer,
        address account
    ) external view returns (Config memory) {
        return _configs[id][multiplexer][account];
    }

    function getState(
        ConfigId id,
        address multiplexer,
        address account,
        address recipient
    ) external view returns (State memory) {
        return _states[id][multiplexer][account][recipient];
    }

    function canTransferTo(
        ConfigId id,
        address multiplexer,
        address account,
        address recipient
    ) external view returns (bool) {
        Config memory config = _configs[id][multiplexer][account];
        State memory state = _states[id][multiplexer][account][recipient];

        if (state.lastActivity == 0) return true;
        return block.timestamp >= state.lastActivity + config.throttlePeriod;
    }
}
