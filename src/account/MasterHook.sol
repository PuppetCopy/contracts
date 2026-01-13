// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Error} from "../utils/Error.sol";
import {MasterRouter} from "./MasterRouter.sol";

/// @title MasterHook
/// @notice ERC-7579 Hook module for master accounts
/// @dev Validates master account calls through RouterProxy → MasterRouter.
///      Uses chain-agnostic tokenId for cross-chain deterministic addresses.
///      RouterProxy is deterministic (CREATE2), enabling same MasterHook address across chains.
contract MasterHook is IHook {
    struct InstallParams {
        address user;
        address signer;
        bytes32 baseTokenId; // Chain-agnostic token ID, resolved via Registry
        bytes32 name;
    }

    /// @notice Immutable router proxy - delegates to MasterRouter, which can be upgraded
    MasterRouter public immutable router;

    /// @param _routerProxy Address of RouterProxy (deterministic across chains)
    constructor(address _routerProxy) {
        router = MasterRouter(_routerProxy);
    }

    function preCheck(address caller, uint callValue, bytes calldata callData) external returns (bytes memory) {
        IERC7579Account master = IERC7579Account(msg.sender);
        return router.processPreCall(caller, master, callValue, callData);
    }

    function postCheck(bytes calldata hookData) external {
        IERC7579Account master = IERC7579Account(msg.sender);
        router.processPostCall(master, hookData);
    }

    function onInstall(bytes calldata _data) external {
        InstallParams memory params = abi.decode(_data, (InstallParams));
        IERC7579Account master = IERC7579Account(msg.sender);
        router.createMaster(params.user, params.signer, master, params.baseTokenId, params.name);
    }

    function onUninstall(bytes calldata) external pure {
        revert Error.MasterHook__UninstallDisabled();
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }
}
