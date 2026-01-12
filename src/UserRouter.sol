// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "./utils/CoreContract.sol";
import {Error} from "./utils/Error.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";
import {IUserRouter} from "./utils/interfaces/IUserRouter.sol";
import {Allocate} from "./position/Allocate.sol";
import {Match} from "./position/Match.sol";
import {Position} from "./position/Position.sol";
import {TokenRouter} from "./shared/TokenRouter.sol";

/// @title UserRouter
/// @notice Passthrough router for MasterHook to Allocate/Position contracts
contract UserRouter is IUserRouter, CoreContract {
    struct Config {
        Allocate allocation;
        Match matcher;
        Position position;
        TokenRouter tokenRouter;
        address masterHook;
    }

    Config public config;

    function getConfig() external view returns (Config memory) {
        return config;
    }

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function createMaster(
        address _user,
        address _signer,
        IERC7579Account _master,
        IERC20 _baseToken,
        bytes32 _name
    ) external {
        if (msg.sender != config.masterHook) revert Error.UserRouter__UnauthorizedCaller();
        config.allocation.createMaster(_user, _signer, _master, _baseToken, _name);
    }

    function disposeMaster(IERC7579Account _master) external {
        if (msg.sender != config.masterHook) revert Error.UserRouter__UnauthorizedCaller();
        config.allocation.disposeMaster(_master);
    }

    function isDisposed(IERC7579Account _master) external view returns (bool) {
        (,,,, bool disposed,) = config.allocation.registeredMap(_master);
        return disposed;
    }

    function processPreCall(address _msgSender, IERC7579Account _master, uint _msgValue, bytes calldata _msgData)
        external
        view
        returns (bytes memory hookData)
    {
        return config.position.processPreCall(_msgSender, _master, _msgValue, _msgData);
    }

    function processPostCall(bytes calldata _hookData) external {
        config.position.processPostCall(IERC7579Account(msg.sender), _hookData);
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
            config.tokenRouter, config.matcher, IERC7579Account(msg.sender), _puppetList, _requestedAmountList, _attestation
        );
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        require(address(_config.allocation) != address(0), "UserRouter: invalid allocation");
        require(address(_config.matcher) != address(0), "UserRouter: invalid matcher");
        require(address(_config.position) != address(0), "UserRouter: invalid position");
        require(address(_config.tokenRouter) != address(0), "UserRouter: invalid tokenRouter");
        require(_config.masterHook != address(0), "UserRouter: invalid masterHook");
        config = _config;
    }
}
