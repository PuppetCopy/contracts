// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";
import {IUserRouter} from "./utils/interfaces/IUserRouter.sol";
import {Allocate} from "./position/Allocate.sol";
import {Match} from "./position/Match.sol";
import {TokenRouter} from "./shared/TokenRouter.sol";
import {Registry} from "./account/Registry.sol";

/// @title UserRouter
/// @notice Entry point for user actions (subscription, allocation)
contract UserRouter is IUserRouter, CoreContract {
    struct Config {
        Allocate allocation;
        Match matcher;
        TokenRouter tokenRouter;
        Registry registry;
    }

    Config public config;

    function getConfig() external view returns (Config memory) {
        return config;
    }

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function isRegistered(IERC7579Account _master) external view returns (bool) {
        return config.registry.isRegistered(_master);
    }

    function setFilter(uint _dim, bytes32 _value, bool _allowed) external {
        config.matcher.setFilter(msg.sender, _dim, _value, _allowed);
    }

    function setPolicy(IERC7579Account _master, uint _allowanceRate, uint _throttlePeriod, uint _expiry) external {
        config.matcher.setPolicy(msg.sender, _master, _allowanceRate, _throttlePeriod, _expiry);
    }

    function allocate(
        address[] calldata _puppetList,
        uint[] calldata _requestedAmountList,
        Allocate.AllocateAttestation calldata _attestation
    ) external {
        config.allocation.allocate(
            config.registry, config.tokenRouter, config.matcher, IERC7579Account(msg.sender), _puppetList, _requestedAmountList, _attestation
        );
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        require(address(_config.allocation) != address(0), "UserRouter: invalid allocation");
        require(address(_config.matcher) != address(0), "UserRouter: invalid matcher");
        require(address(_config.tokenRouter) != address(0), "UserRouter: invalid tokenRouter");
        require(address(_config.registry) != address(0), "UserRouter: invalid registry");
        config = _config;
    }
}
