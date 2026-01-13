// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MasterInfo} from "../position/interface/ITypes.sol";

/// @title Registry
/// @notice Stores master account registrations and token mappings for the Puppet protocol
/// @dev Universal contract deployed on all chains. MasterHook calls this during onInstall.
///      Also maps chain-agnostic token IDs to actual token addresses per chain.
contract Registry is CoreContract {
    struct Config {
        bytes32[] account7579CodeList;
    }

    Config internal config;

    mapping(bytes32 tokenId => IERC20) public tokenMap;
    mapping(IERC20 token => uint) public tokenCapMap;
    mapping(IERC7579Account master => MasterInfo) public registeredMap;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getMasterInfo(IERC7579Account _master) external view returns (MasterInfo memory) {
        return registeredMap[_master];
    }

    function isRegistered(IERC7579Account _master) external view returns (bool) {
        return address(registeredMap[_master].baseToken) != address(0);
    }

    function isAllowedCodeHash(bytes32 _codeHash) public view returns (bool) {
        bytes32[] memory _codeList = config.account7579CodeList;
        for (uint i; i < _codeList.length; ++i) {
            if (_codeList[i] == _codeHash) return true;
        }
        return false;
    }

    function setTokenCap(IERC20 _token, uint _cap) external auth {
        tokenCapMap[_token] = _cap;
        _logEvent("SetTokenCap", abi.encode(_token, _cap));
    }

    function setToken(bytes32 _tokenId, IERC20 _token) external auth {
        if (_tokenId == bytes32(0)) revert Error.Registry__InvalidTokenId();
        if (address(_token) == address(0)) revert Error.Registry__InvalidTokenAddress();
        tokenMap[_tokenId] = _token;
        _logEvent("SetToken", abi.encode(_tokenId, _token));
    }

    function createMaster(
        address _user,
        address _signer,
        IERC7579Account _master,
        IERC20 _baseToken,
        bytes32 _name
    ) external auth {
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_master) }
        if (!isAllowedCodeHash(_codeHash)) revert Error.Registry__InvalidAccountCodeHash();
        if (address(registeredMap[_master].baseToken) != address(0)) revert Error.Registry__AlreadyRegistered();
        if (tokenCapMap[_baseToken] == 0) revert Error.Registry__TokenNotAllowed();

        registeredMap[_master] = MasterInfo(_user, _signer, _baseToken, _name);

        _logEvent("CreateMaster", abi.encode(_master, _user, _signer, _baseToken, _name));
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        require(_config.account7579CodeList.length > 0, "Registry: empty code list");
        config = _config;
    }
}
