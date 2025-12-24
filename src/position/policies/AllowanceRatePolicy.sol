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
 * @title AllowanceRatePolicy
 * @notice Smart Sessions policy that limits transfers to a percentage of balance
 * @dev Validates that transfer amount <= (balance * allowanceRate / 10000)
 *
 * Usage:
 * 1. Puppet enables session with this policy
 * 2. Puppet sets allowance rate (basis points, 10000 = 100%)
 * 3. When session executes transfer, validates amount is within allowed rate
 */
contract AllowanceRatePolicy is IActionPolicy {
    // ============ Types ============

    struct Config {
        uint96 allowanceRate; // Basis points (10000 = 100%)
    }

    // ============ Storage ============

    // ConfigId => multiplexer => account => config
    mapping(ConfigId => mapping(address => mapping(address => Config))) internal _configs;

    // ============ Errors ============

    error InvalidAllowanceRate();

    // ============ ERC165 ============

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    // ============ IPolicy ============

    /**
     * @notice Initialize policy with allowance rate
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

        if (config.allowanceRate == 0 || config.allowanceRate > 10000) {
            revert InvalidAllowanceRate();
        }

        _configs[configId][msg.sender][account] = config;

        emit PolicySet(configId, msg.sender, account);
    }

    // ============ IActionPolicy ============

    /**
     * @notice Validate that transfer amount is within allowance rate
     * @dev Checks amount <= (balance * allowanceRate / 10000)
     */
    function checkAction(
        ConfigId id,
        address account,
        address target,
        uint256 value,
        bytes calldata data
    ) external view override returns (uint256) {
        // No ETH transfers
        if (value != 0) return VALIDATION_FAILED;

        // Must be transfer call
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        Config memory config = _configs[id][msg.sender][account];
        if (config.allowanceRate == 0) return VALIDATION_FAILED;

        // Decode amount from calldata
        (, uint256 amount) = abi.decode(data[4:], (address, uint256));

        // Check against balance * allowance rate
        // Target is the token contract
        uint256 balance = IERC20(target).balanceOf(account);
        uint256 maxAllowed = (balance * config.allowanceRate) / 10000;

        if (amount > maxAllowed) {
            return VALIDATION_FAILED;
        }

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
}
