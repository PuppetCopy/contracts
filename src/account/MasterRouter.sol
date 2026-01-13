// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {Access} from "../utils/auth/Access.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Position} from "../position/Position.sol";
import {Registry} from "./Registry.sol";

/// @title MasterRouter
/// @notice Immutable router for MasterHook to interact with Registry and Position
contract MasterRouter is Access {
    Registry public immutable registry;
    Position public immutable position;

    constructor(IAuthority _authority, Registry _registry, Position _position) Access(_authority) {
        registry = _registry;
        position = _position;
    }

    /// @notice Register a new master account
    /// @param _baseTokenId Chain-agnostic token ID, resolved to actual address via Registry
    function createMaster(
        address _user,
        address _signer,
        IERC7579Account _master,
        bytes32 _baseTokenId,
        bytes32 _name
    ) external auth {
        IERC20 baseToken = registry.tokenMap(_baseTokenId);
        if (address(baseToken) == address(0)) revert Error.Registry__TokenNotFound();
        registry.createMaster(_user, _signer, _master, baseToken, _name);
    }

    /// @notice Process pre-call validation for master account executions
    function processPreCall(
        address _caller,
        IERC7579Account _master,
        uint _callValue,
        bytes calldata _callData
    ) external auth returns (bytes memory) {
        return position.processPreCall(registry, _caller, _master, _callValue, _callData);
    }

    /// @notice Process post-call validation for master account executions
    function processPostCall(
        IERC7579Account _master,
        bytes calldata _hookData
    ) external auth {
        position.processPostCall(_master, _hookData);
    }
}
