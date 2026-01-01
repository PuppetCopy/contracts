// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {
    ModeLib,
    ModeCode,
    CallType,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_STATIC
} from "modulekit/accounts/common/lib/ModeLib.sol";

import {IUserRouter} from "../utils/interfaces/IUserRouter.sol";

/**
 * @title MasterHook
 * @notice ERC-7579 Hook for master subaccounts in Puppet protocol
 * @dev Permissionless hook that enables fund-raising through Allocation
 *
 * Lifecycle:
 * - onInstall: registers as master subaccount via Allocation.registerMasterSubaccount
 * - preCheck: validates all executions to whitelisted venues
 * - onUninstall: requires all positions closed, freezes matching key
 *
 * A master can create many subaccounts, each registration is immutable.
 * Once configured, subaccount settings cannot be changed.
 *
 * References RouterProxy for upgradability - DAO can update underlying contracts.
 */
contract MasterHook is IHook {
    error MasterHook__InvalidExecution();
    error MasterHook__PositionsNotClosed();

    IUserRouter public immutable router;

    constructor(IUserRouter _router) {
        router = _router;
    }

    function preCheck(address msgSender, uint msgValue, bytes calldata msgData) external view returns (bytes memory) {
        if (msgData.length < 4) revert MasterHook__InvalidExecution();
        return router.validatePreCall(msg.sender, msgSender, msgValue, msgData);
    }

    function postCheck(bytes calldata hookData) external {
        router.settle(msg.sender, hookData);
    }

    /// @notice Install hook and register as master subaccount
    /// @param _data Encoded (account, signer, token)
    function onInstall(bytes calldata _data) external {
        IERC7579Account subaccount = IERC7579Account(msg.sender);

        // Decode install parameters
        (address account, address signer, IERC20 token) = abi.decode(_data, (address, address, IERC20));

        // Register as master subaccount - enables fund raising
        router.registerMasterSubaccount(account, signer, subaccount, token);
    }

    /// @notice Uninstall hook - requires positions closed, freezes matching key
    /// @param _data Encoded (token)
    function onUninstall(bytes calldata _data) external view {
        IERC7579Account subaccount = IERC7579Account(msg.sender);

        IERC20 token = abi.decode(_data, (IERC20));

        // Verify all positions are closed
        bytes32 matchingKey = _getMatchingKey(token, subaccount);
        bytes32[] memory positionKeys = router.getPositionKeyList(matchingKey);
        if (positionKeys.length > 0) revert MasterHook__PositionsNotClosed();

        // Freeze is handled by Allocation.onUninstall when executor is removed
        // The hook uninstall just validates conditions are met
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    /// @notice Check if hook is initialized for account
    /// @dev Returns true - actual registration state is in Allocation contract
    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function _getMatchingKey(IERC20 _token, IERC7579Account _subaccount) internal pure returns (bytes32) {
        return keccak256(abi.encode(_token, _subaccount));
    }
}
