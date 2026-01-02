// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {IUserRouter} from "../utils/interfaces/IUserRouter.sol";

/**
 * @title MasterHook
 * @notice ERC-7579 Hook for master subaccounts in Puppet protocol
 * @dev Permissionless hook that enables fund-raising through Allocation
 *
 * Lifecycle:
 * - onInstall: registers subaccount with Allocation (no token - chosen at deposit time)
 * - preCheck: validates all executions to whitelisted venues
 * - onUninstall: freezing handled by Allocation.onUninstall
 *
 * A master can create many subaccounts, each registration is immutable.
 * Token choice happens at deposit time and is validated via tokenCapMap whitelist.
 *
 * References RouterProxy for upgradability - DAO can update underlying contracts.
 */
contract MasterHook is IHook {
    struct InstallParams {
        address account;    // master account that owns this subaccount
        address signer;     // session signer for trading operations
        bytes32 name;       // subaccount identifier (e.g. "main", "eth_long")
    }

    IUserRouter public immutable router;

    /// @notice Registered subaccounts (for isInitialized check)
    mapping(address subaccount => bool) public registered;

    constructor(IUserRouter _router) {
        router = _router;
    }

    function preCheck(address msgSender, uint msgValue, bytes calldata msgData) external returns (bytes memory) {
        // msgSender = master, msg.sender = subaccount
        // Token is extracted from execution data by Position/Stage handlers
        return router.processPreCall(msgSender, msg.sender, msgValue, msgData);
    }

    function postCheck(bytes calldata hookData) external view {
        router.processPostCall(msg.sender, hookData);
    }

    /// @notice Install hook and register subaccount
    /// @dev Token is not specified here - masters/puppets choose token at deposit time
    /// @param _data Encoded InstallParams struct
    function onInstall(bytes calldata _data) external {
        IERC7579Account subaccount = IERC7579Account(msg.sender);

        // Decode install parameters
        InstallParams memory params = abi.decode(_data, (InstallParams));

        // Mark as registered
        registered[msg.sender] = true;

        // Register with Allocation - token is not specified at this stage
        router.registerMasterSubaccount(params.account, params.signer, subaccount, params.name);
    }

    /// @notice Uninstall hook
    /// @dev Position closing and freezing handled by Allocation.onUninstall
    function onUninstall(bytes calldata) external {
        registered[msg.sender] = false;
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    /// @notice Check if hook is initialized for account
    function isInitialized(address _account) external view returns (bool) {
        return registered[_account];
    }
}
