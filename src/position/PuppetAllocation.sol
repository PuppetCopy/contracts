// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IExecutor, MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, ModePayload, CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

contract PuppetAllocation is CoreContract, IExecutor {
    struct Config {
        uint transferGasLimit;
    }

    Config public config;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function fund(
        IERC7579Account _puppet,
        IERC20 _token,
        address _masterSubaccount,
        uint _amount
    ) external auth returns (bytes memory _result, bytes memory _error) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        try _puppet.executeFromExecutor{gas: config.transferGasLimit}(
            _mode,
            ExecutionLib.encodeSingle(
                address(_token),
                0,
                abi.encodeCall(IERC20.transfer, (_masterSubaccount, _amount))
            )
        ) returns (bytes[] memory _results) {
            _result = _results[0];
        } catch (bytes memory _reason) {
            _error = _reason;
        }
    }

    // ============================================================
    // IExecutor Module Implementation
    // ============================================================

    function isModuleType(uint256 _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address _puppet) external view returns (bool) {
        return IERC7579Account(_puppet).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "");
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external {}

    // ============================================================
    // Config
    // ============================================================

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.transferGasLimit == 0) revert Error.PuppetAllocation__InvalidTransferGasLimit();
        config = _config;
    }
}
