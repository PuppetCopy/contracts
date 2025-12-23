// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Error} from "../utils/Error.sol";
import {IERC7579Account} from "../utils/interfaces/IERC7579Account.sol";
import {
    IValidator,
    PackedUserOperation,
    MODULE_TYPE_VALIDATOR,
    VALIDATION_SUCCESS,
    EIP1271_SUCCESS
} from "../utils/interfaces/IERC7579Module.sol";
import {PuppetAccount} from "./PuppetAccount.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

interface IAllocation {
    function allocationBalance(bytes32 traderMatchingKey, address user) external view returns (uint);
}

interface IPuppetModule {
    function setPolicy(address _trader, IERC20 _collateralToken, bytes calldata _data) external;
    function removePolicy(address _trader, IERC20 _collateralToken) external;
}

/**
 * @title PuppetModule
 * @notice ERC-7579 validator module for puppet subaccounts
 * @dev Installed on puppet's ERC-7579 smart account
 *
 * Implements IValidator interface for ERC-7579 compatibility.
 * 1. Registers the puppet subaccount with PuppetAccount on install
 * 2. Forwards policy management calls to PuppetAccount
 * 3. Contains validation logic (upgradeable by deploying new module)
 */
contract PuppetModule is IValidator, IPuppetModule {
    event PolicySet(address indexed puppet, address indexed trader, IERC20 indexed collateralToken, bytes data);

    struct PolicyParams {
        uint allowanceRate; // basis points (10000 = 100%)
        uint throttleActivity; // seconds between allocations
        uint expiry; // timestamp when policy expires (0 = never)
    }

    struct Policy {
        uint allowanceRate;
        uint throttleActivity;
        uint expiry;
        uint lastActivityTimestamp;
    }

    PuppetAccount public immutable puppetAccount;
    IAllocation public immutable allocation;

    constructor(PuppetAccount _puppetAccount, address _allocation) {
        puppetAccount = _puppetAccount;
        allocation = IAllocation(_allocation);
    }

    // ============ ERC-7579 Module Interface ============

    function onInstall(bytes calldata) external override {
        puppetAccount.registerPuppet(IERC7579Account(msg.sender), address(this));
    }

    function onUninstall(bytes calldata) external pure override {}

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isInitialized(address) external pure override returns (bool) {
        return true;
    }

    // ============ Policy Management (forwarded to PuppetAccount) ============

    /**
     * @notice Set policy to follow a trader
     * @dev Called by puppet's subaccount, forwards to PuppetAccount
     * @param _trader The trader to follow
     * @param _collateralToken The collateral token
     * @param _data Encoded PolicyParams (allowanceRate, throttleActivity, expiry)
     */
    function setPolicy(address _trader, IERC20 _collateralToken, bytes calldata _data) external {
        // Validate policy params before storing
        PolicyParams memory _params = abi.decode(_data, (PolicyParams));
        if (_params.allowanceRate == 0 || _params.allowanceRate > 10000) revert Error.PuppetAccount__InvalidPolicy();
        if (_params.expiry != 0 && _params.expiry <= block.timestamp) revert Error.PuppetAccount__InvalidPolicy();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);

        // Store full Policy with initial lastActivityTimestamp = 0
        Policy memory _policy = Policy({
            allowanceRate: _params.allowanceRate,
            throttleActivity: _params.throttleActivity,
            expiry: _params.expiry,
            lastActivityTimestamp: 0
        });

        bytes memory _policyData = abi.encode(_policy);
        puppetAccount.setPolicy(IERC7579Account(msg.sender), _traderMatchingKey, _policyData);

        emit PolicySet(msg.sender, _trader, _collateralToken, _policyData);
    }

    /**
     * @notice Remove policy for a trader
     */
    function removePolicy(address _trader, IERC20 _collateralToken) external {
        puppetAccount.removePolicy(IERC7579Account(msg.sender), _trader, _collateralToken);
    }

    // ============ Validation (called via puppet subaccount) ============

    /**
     * @notice Validate allocation against puppet's policy
     * @dev Called by puppet subaccount. msg.sender is the puppet. Returns 0 if invalid.
     * @param _trader The trader address
     * @param _collateralToken The collateral token
     * @param _requestedAmount Amount requested for allocation
     * @return Allowed amount (0 if validation fails)
     */
    function validatePolicy(address _trader, IERC20 _collateralToken, uint _requestedAmount)
        external
        returns (uint)
    {
        address _puppet = msg.sender;

        // Verify puppet has this module installed
        if (!IERC7579Account(_puppet).isModuleInstalled(MODULE_TYPE_VALIDATOR, address(this), "")) {
            return 0;
        }

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        Policy memory _policy = _getPolicy(_puppet, _traderMatchingKey);

        // Check policy exists
        if (_policy.allowanceRate == 0) return 0;

        // Check expiry
        if (_policy.expiry != 0 && block.timestamp > _policy.expiry) return 0;

        // Check throttle (skip for first allocation when lastActivityTimestamp is 0)
        if (_policy.lastActivityTimestamp > 0 && _policy.lastActivityTimestamp + _policy.throttleActivity > block.timestamp) {
            return 0;
        }

        // Calculate max allowed based on puppet's balance and allowance rate
        uint _puppetBalance = _collateralToken.balanceOf(_puppet);
        uint _currentAllocation = allocation.allocationBalance(_traderMatchingKey, _puppet);
        uint _availableBalance = _puppetBalance > _currentAllocation ? _puppetBalance - _currentAllocation : 0;
        uint _maxAllowed = (_availableBalance * _policy.allowanceRate) / 10000;

        if (_requestedAmount > _maxAllowed) return 0;

        // Update policy with new lastActivityTimestamp
        _policy.lastActivityTimestamp = block.timestamp;
        puppetAccount.setPolicy(IERC7579Account(_puppet), _traderMatchingKey, abi.encode(_policy));

        return _requestedAmount;
    }

    // ============ ERC-7579 Validator Interface ============

    /// @notice Validates ERC-4337 user operations (permits all for puppet accounts)
    function validateUserOp(PackedUserOperation calldata, bytes32) external pure override returns (uint256) {
        return VALIDATION_SUCCESS;
    }

    /// @notice Validates ERC-1271 signatures (permits all for puppet accounts)
    function isValidSignatureWithSender(address, bytes32, bytes calldata) external pure override returns (bytes4) {
        return EIP1271_SUCCESS;
    }

    // ============ Internal ============

    function _getPolicy(address _puppet, bytes32 _traderMatchingKey) internal view returns (Policy memory) {
        bytes memory _data = puppetAccount.policyMap(_puppet, _traderMatchingKey);
        if (_data.length == 0) return Policy(0, 0, 0, 0);

        return abi.decode(_data, (Policy));
    }
}
