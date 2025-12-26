// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IModule, IHook} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {ModeCode, ModeLib, CallType, ExecType, CALLTYPE_SINGLE, CALLTYPE_BATCH, EXECTYPE_DEFAULT, EXECTYPE_TRY} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";

/**
 * @title TestSmartAccount
 * @notice Minimal ERC-7579 Smart Account for testing
 * @dev Uses modulekit interfaces and types, implements core functionality
 */
contract TestSmartAccount is IERC7579Account {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    // Module storage
    mapping(uint256 => mapping(address => bool)) internal _modules;
    address public installedHook;

    error UnsupportedCallType(CallType callType);
    error UnsupportedExecType(ExecType execType);
    error ExecutionFailed();
    error CallerNotAuthorized();

    // ============ Execution ============

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable {
        // Simulate Smart Sessions: caller must be installed as validator (or self-call)
        if (msg.sender != address(this) && !_modules[MODULE_TYPE_VALIDATOR][msg.sender]) revert CallerNotAuthorized();

        (CallType callType, ExecType execType,,) = mode.decode();

        // preCheck - pass full msg.data per ERC-7579 spec
        bytes memory hookData;
        if (installedHook != address(0)) {
            hookData = IHook(installedHook).preCheck(msg.sender, msg.value, msg.data);
        }

        if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata data) = executionCalldata.decodeSingle();
            if (execType == EXECTYPE_DEFAULT) {
                _execute(target, value, data);
            } else if (execType == EXECTYPE_TRY) {
                _tryExecute(target, value, data);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            if (execType == EXECTYPE_DEFAULT) {
                _executeBatch(executions);
            } else if (execType == EXECTYPE_TRY) {
                _tryExecuteBatch(executions);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else {
            revert UnsupportedCallType(callType);
        }

        // postCheck
        if (installedHook != address(0)) {
            IHook(installedHook).postCheck(hookData);
        }
    }

    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    ) external payable returns (bytes[] memory returnData) {
        // Caller must be installed as executor
        if (!_modules[MODULE_TYPE_EXECUTOR][msg.sender]) revert CallerNotAuthorized();

        (CallType callType, ExecType execType,,) = mode.decode();

        if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata data) = executionCalldata.decodeSingle();
            returnData = new bytes[](1);
            if (execType == EXECTYPE_DEFAULT) {
                returnData[0] = _execute(target, value, data);
            } else if (execType == EXECTYPE_TRY) {
                // EXECTYPE_TRY doesn't revert on failure - returns raw result (per ERC-7579 spec)
                (, returnData[0]) = _tryExecute(target, value, data);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            if (execType == EXECTYPE_DEFAULT) {
                returnData = _executeBatch(executions);
            } else if (execType == EXECTYPE_TRY) {
                returnData = _tryExecuteBatch(executions);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    // ============ Module Management ============

    function installModule(uint256 moduleTypeId, address module, bytes calldata initData) external payable {
        _modules[moduleTypeId][module] = true;
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            installedHook = module;
        }
        // Call onInstall if module implements IModule
        // Use low-level call to handle non-module contracts gracefully
        (bool success, bytes memory returnData) =
            module.call(abi.encodeWithSelector(IModule.onInstall.selector, initData));
        if (!success && returnData.length > 0) {
            // Module reverted with an error - propagate it
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        // If !success && returnData.length == 0, module doesn't implement onInstall - that's ok
        emit ModuleInstalled(moduleTypeId, module);
    }

    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData) external payable {
        // Call onUninstall - this should revert if module doesn't allow it
        IModule(module).onUninstall(deInitData);
        _modules[moduleTypeId][module] = false;
        emit ModuleUninstalled(moduleTypeId, module);
    }

    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata
    ) external view returns (bool) {
        return _modules[moduleTypeId][module];
    }

    // ============ Account Config ============

    function accountId() external pure returns (string memory) {
        return "test.smartaccount.v1";
    }

    function supportsExecutionMode(ModeCode) external pure returns (bool) {
        return true;
    }

    function supportsModule(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR
            || moduleTypeId == MODULE_TYPE_EXECUTOR
            || moduleTypeId == MODULE_TYPE_FALLBACK
            || moduleTypeId == MODULE_TYPE_HOOK;
    }

    // ============ ERC-1271 ============

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

    // ============ Internal Execution ============

    function _execute(address target, uint256 value, bytes calldata data) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    function _tryExecute(address target, uint256 value, bytes calldata data) internal returns (bool, bytes memory) {
        return target.call{value: value}(data);
    }

    function _executeBatch(Execution[] calldata executions) internal returns (bytes[] memory results) {
        results = new bytes[](executions.length);
        for (uint256 i; i < executions.length; i++) {
            results[i] = _execute(executions[i].target, executions[i].value, executions[i].callData);
        }
    }

    function _tryExecuteBatch(Execution[] calldata executions) internal returns (bytes[] memory results) {
        results = new bytes[](executions.length);
        for (uint256 i; i < executions.length; i++) {
            (bool success, bytes memory result) = _tryExecute(
                executions[i].target,
                executions[i].value,
                executions[i].callData
            );
            if (!success) revert ExecutionFailed();
            results[i] = result;
        }
    }

    receive() external payable {}

    // ============ Test Helpers ============

    /// @dev Helper for testing - allows direct token transfers from account
    function transfer(address token, address to, uint256 amount) external {
        (bool success,) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(success, "Transfer failed");
    }

}
