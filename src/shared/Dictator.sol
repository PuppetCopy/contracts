// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CoreContract} from "./../utils/CoreContract.sol";
import {Access} from "./../utils/auth/Access.sol";
import {Permission} from "./../utils/auth/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {Error} from "./Error.sol";

/// @title Dictator
/// @notice Authority contract that orchestrates permission management, configuration settings, and event logging
/// @dev The contract acts as the single source of truth for contract access and permissions, enabling
/// centralized management of multiple contracts. It facilitates the initialization and configuration of contracts, and
/// emits events to a unified log, allowing for seamless updates and consistent event tracking across the system
///
/// The Dictator allows:
/// - Centralized management of access rights and permissions for different contracts
/// - Initialization and configuration of core contracts through a standardized interface
/// - Emission of events from a single contract, simplifying monitoring and analytics
/// - Upgrading of logic contracts without disrupting event tracking or historical data
///
/// Note: The Dictator should be controlled by a DAO contract to ensure proper governance and security
contract Dictator is Ownable, IAuthority {
    event UpdateAccess(address target, bool enabled);
    event UpdatePermission(address target, bytes4 functionSig, bool enabled);
    event SetConfig(address target, bytes config);
    event LogEvent(address operator, string name, string version, string method, bytes data);
    event RemoveContractAccess(address target);

    mapping(address => bool) public contractAccessMap;

    function hasAccess(Access target, address user) external view returns (bool) {
        return target.canCall(user);
    }

    function hasPermission(Permission target, bytes4 functionSig, address user) external view returns (bool) {
        return target.canCall(functionSig, user);
    }

    constructor(
        address _owner
    ) Ownable(_owner) {}

    function setAccess(Access target, address user) public virtual onlyOwner {
        target.setAccess(user, true);

        emit UpdateAccess(address(target), true);
    }

    function removeAccess(Access target, address user) public virtual onlyOwner {
        target.setAccess(user, false);

        emit UpdateAccess(address(target), false);
    }

    function setPermission(Permission target, bytes4 functionSig, address user) public virtual onlyOwner {
        target.setPermission(functionSig, user, true);

        emit UpdatePermission(address(target), functionSig, true);
    }

    function removePermission(Permission target, bytes4 functionSig, address user) public virtual onlyOwner {
        target.setPermission(functionSig, user, false);

        emit UpdatePermission(address(target), functionSig, false);
    }

    function logEvent(string memory method, string memory name, string memory version, bytes memory data) external {
        if (!contractAccessMap[msg.sender]) revert Error.Dictator__ContractNotInitialized();

        emit LogEvent(msg.sender, method, name, version, data);
    }

    function initContract(CoreContract target, bytes calldata config) public onlyOwner {
        address targetAddress = address(target);

        if (contractAccessMap[targetAddress]) revert Error.Dictator__ContractAlreadyInitialized();
        contractAccessMap[targetAddress] = true;

        setConfig(target, config);
    }

    function setConfig(CoreContract target, bytes calldata config) public onlyOwner {
        address targetAddress = address(target);
        (bool success,) = targetAddress.call(abi.encodeWithSignature("setConfig(bytes)", config));

        if (!success) revert Error.Dictator__ConfigurationUpdateFailed();

        emit SetConfig(targetAddress, config);
    }

    function removeContractAccess(
        CoreContract target
    ) public onlyOwner {
        address targetAddress = address(target);

        if (!contractAccessMap[targetAddress]) revert Error.Dictator__ContractNotInitialized();
        contractAccessMap[targetAddress] = false;

        emit RemoveContractAccess(targetAddress);
    }
}
