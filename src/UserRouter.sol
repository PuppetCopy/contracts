// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";
import {IUserRouter} from "./utils/interfaces/IUserRouter.sol";
import {Allocation} from "./position/Allocation.sol";
import {VenueRegistry} from "./position/VenueRegistry.sol";

/**
 * @title UserRouter
 * @notice Passthrough router with configurable contract references
 * @dev DAO can update underlying contracts. Deployed behind RouterProxy.
 */
contract UserRouter is IUserRouter, CoreContract {
    struct Config {
        Allocation allocation;
        VenueRegistry venueRegistry;
    }

    Config public config;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    /// @inheritdoc IUserRouter
    function registerMasterSubaccount(address _account, address _signer, IERC7579Account _subaccount, IERC20 _token)
        external
    {
        config.allocation.registerMasterSubaccount(_account, _signer, _subaccount, _token);
    }

    /// @inheritdoc IUserRouter
    function validatePreCall(address _subaccount, address _msgSender, uint _msgValue, bytes calldata _msgData)
        external
        view
        returns (bytes memory hookData)
    {
        return config.venueRegistry.validatePreCall(_subaccount, _msgSender, _msgValue, _msgData);
    }

    /// @inheritdoc IUserRouter
    function processPostCall(address _subaccount, bytes calldata _hookData) external {
        config.venueRegistry.processPostCall(_subaccount, _hookData);
    }

    /// @inheritdoc IUserRouter
    function getPositionKeyList(bytes32 _matchingKey) external view returns (bytes32[] memory) {
        return config.venueRegistry.getPositionKeyList(_matchingKey);
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        require(address(_config.allocation) != address(0), "UserRouter: invalid allocation");
        require(address(_config.venueRegistry) != address(0), "UserRouter: invalid venueRegistry");
        config = _config;
    }
}
