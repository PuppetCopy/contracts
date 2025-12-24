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
 * @title AllowedRecipientPolicy
 * @notice Smart Sessions policy that restricts transfers to whitelisted recipients
 * @dev Validates that ERC20.transfer() calls go to allowed trader subaccounts
 *
 * Usage:
 * 1. Puppet enables session with this policy
 * 2. Puppet adds allowed recipients (trader subaccounts) via Smart Sessions initData
 * 3. When session executes transfer, this policy validates recipient is allowed
 */
contract AllowedRecipientPolicy is IActionPolicy {
    // ============ Storage ============

    // ConfigId => multiplexer => account => recipient => allowed
    mapping(ConfigId => mapping(address => mapping(address => mapping(address => bool)))) internal _allowedRecipients;

    // ConfigId => multiplexer => account => recipients list (for enumeration)
    mapping(ConfigId => mapping(address => mapping(address => address[]))) internal _recipientsList;

    // ============ Events ============

    event RecipientAdded(ConfigId indexed id, address indexed account, address indexed recipient);
    event RecipientRemoved(ConfigId indexed id, address indexed account, address indexed recipient);

    // ============ ERC165 ============

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    // ============ IPolicy ============

    /**
     * @notice Initialize policy with allowed recipients
     * @param account The puppet account
     * @param configId Unique identifier for this configuration
     * @param initData ABI-encoded array of allowed recipient addresses
     */
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external override {
        // Clear existing recipients
        address[] storage existing = _recipientsList[configId][msg.sender][account];
        for (uint i = 0; i < existing.length; i++) {
            _allowedRecipients[configId][msg.sender][account][existing[i]] = false;
        }
        delete _recipientsList[configId][msg.sender][account];

        // Decode and add new recipients
        address[] memory recipients = abi.decode(initData, (address[]));
        for (uint i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            if (recipient != address(0) && !_allowedRecipients[configId][msg.sender][account][recipient]) {
                _allowedRecipients[configId][msg.sender][account][recipient] = true;
                _recipientsList[configId][msg.sender][account].push(recipient);
                emit RecipientAdded(configId, account, recipient);
            }
        }

        emit PolicySet(configId, msg.sender, account);
    }

    // ============ IActionPolicy ============

    /**
     * @notice Validate that transfer recipient is allowed
     * @dev Only validates ERC20.transfer() calls
     */
    function checkAction(
        ConfigId id,
        address account,
        address, /* target */
        uint256 value,
        bytes calldata data
    ) external view override returns (uint256) {
        // No ETH transfers
        if (value != 0) return VALIDATION_FAILED;

        // Must be transfer call (4 byte selector + 64 bytes args)
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        // Decode recipient from calldata
        (address recipient,) = abi.decode(data[4:], (address, uint256));

        // Check if recipient is allowed
        if (!_allowedRecipients[id][msg.sender][account][recipient]) {
            return VALIDATION_FAILED;
        }

        return VALIDATION_SUCCESS;
    }

    // ============ View Functions ============

    function isRecipientAllowed(
        ConfigId id,
        address multiplexer,
        address account,
        address recipient
    ) external view returns (bool) {
        return _allowedRecipients[id][multiplexer][account][recipient];
    }

    function getAllowedRecipients(
        ConfigId id,
        address multiplexer,
        address account
    ) external view returns (address[] memory) {
        return _recipientsList[id][multiplexer][account];
    }
}
