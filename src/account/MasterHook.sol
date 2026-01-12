// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Error} from "../utils/Error.sol";
import {Position} from "../position/Position.sol";
import {Registry} from "./Registry.sol";

/// @title MasterHook
/// @notice ERC-7579 Hook module for master accounts
/// @dev Validates master account calls through Position. Registry stores master info.
contract MasterHook is IHook {
    struct InstallParams {
        address user;
        address signer;
        IERC20 baseToken;
        bytes32 name;
    }

    Position public immutable position;
    Registry public immutable registry;

    constructor(Position _position, Registry _registry) {
        position = _position;
        registry = _registry;
    }

    function preCheck(address caller, uint callValue, bytes calldata callData) external returns (bytes memory) {
        IERC7579Account master = IERC7579Account(msg.sender);
        return position.processPreCall(registry, caller, master, callValue, callData);
    }

    function postCheck(bytes calldata hookData) external {
        IERC7579Account master = IERC7579Account(msg.sender);
        position.processPostCall(master, hookData);
    }

    function onInstall(bytes calldata _data) external {
        InstallParams memory params = abi.decode(_data, (InstallParams));
        IERC7579Account master = IERC7579Account(msg.sender);
        registry.createMaster(params.user, params.signer, master, params.baseToken, params.name);
    }

    function onUninstall(bytes calldata) external pure {
        revert Error.MasterHook__UninstallDisabled();
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _account) external view returns (bool) {
        return registry.isRegistered(IERC7579Account(_account));
    }
}
