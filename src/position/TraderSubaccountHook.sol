// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Allocation} from "./Allocation.sol";

/**
 * @title TraderSubaccountHook
 * @notice Stateless ERC-7579 hook module that syncs utilization on subaccount transactions
 * @dev Installed on Rhinestone smart accounts, calls Allocation.syncUtilization()
 */
contract TraderSubaccountHook {
    uint256 constant MODULE_TYPE_HOOK = 4;

    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    // ============ ERC-7579 Module Interface ============

    function onInstall(bytes calldata) external {
        allocation.registerSubaccount(msg.sender, address(this));
    }

    function onUninstall(bytes calldata) external pure {}

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    // ============ ERC-7579 Hook Interface ============

    function preCheck(address, uint256, bytes calldata) external returns (bytes memory) {
        allocation.syncSettlement(msg.sender);
        return "";
    }

    function postCheck(bytes calldata) external {
        allocation.syncUtilization(msg.sender);
    }
}
