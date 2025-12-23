// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Allocation} from "./Allocation.sol";
import {IERC7579Account} from "../utils/interfaces/IERC7579Account.sol";

/**
 * @title SubaccountModule
 * @notice Stateless ERC-7579 hook module that syncs utilization on subaccount transactions
 * @dev Installed on Rhinestone smart accounts, calls Allocation.syncUtilization()
 */
contract SubaccountModule {
    uint256 constant MODULE_TYPE_HOOK = 4;

    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    // ============ ERC-7579 Module Interface ============

    function onInstall(bytes calldata) external {
        allocation.registerSubaccount(IERC7579Account(msg.sender), address(this));
    }

    function onUninstall(bytes calldata) external pure {}

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    // ============ ERC-7579 Hook Interface ============

    function preCheck(address, uint256, bytes calldata callData) external returns (bytes memory) {
        allocation.syncSettlement(IERC7579Account(msg.sender));
        return callData; // Pass GMX calldata through to postCheck
    }

    function postCheck(bytes calldata hookData) external {
        allocation.syncUtilization(IERC7579Account(msg.sender), hookData); // Pass calldata for indexing
    }
}
