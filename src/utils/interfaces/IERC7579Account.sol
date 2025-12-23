// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

// ============ Execution Mode Types ============

/// @notice Call type for execution mode (1 byte)
/// @dev 0x00 = single call, 0x01 = batch, 0xfe = staticcall, 0xff = delegatecall
type CallType is bytes1;

/// @notice Execution type for execution mode (1 byte)
/// @dev 0x00 = revert on failure, 0x01 = try/catch error handling
type ExecType is bytes1;

/// @notice Mode selector for custom execution modes (4 bytes)
type ModeSelector is bytes4;

/// @notice Mode payload for additional mode data (22 bytes)
type ModePayload is bytes22;

/// @notice Encoded execution mode (32 bytes)
/// @dev Layout: [callType(1) | execType(1) | unused(4) | modeSelector(4) | modePayload(22)]
type ModeCode is bytes32;

// Call type constants
CallType constant CALLTYPE_SINGLE = CallType.wrap(0x00);
CallType constant CALLTYPE_BATCH = CallType.wrap(0x01);
CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);
CallType constant CALLTYPE_DELEGATECALL = CallType.wrap(0xFF);

// Exec type constants
ExecType constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
ExecType constant EXECTYPE_TRY = ExecType.wrap(0x01);

/// @notice Single execution struct
struct Execution {
    address target;
    uint256 value;
    bytes callData;
}

// ============ Account Interfaces ============

/// @notice ERC-7579 Execution interface
/// @dev Handles execution of calls from the account
interface IERC7579Execution {
    /// @notice Execute a call from the account
    /// @param mode The execution mode (callType, execType, selector, payload)
    /// @param executionCalldata Encoded execution data
    function execute(bytes32 mode, bytes calldata executionCalldata) external;

    /// @notice Execute a call from an executor module
    /// @param mode The execution mode
    /// @param executionCalldata Encoded execution data
    /// @return returnData Array of return data from each call
    function executeFromExecutor(bytes32 mode, bytes calldata executionCalldata)
        external
        returns (bytes[] memory returnData);
}

/// @notice ERC-7579 Account Configuration interface
interface IERC7579AccountConfig {
    /// @notice Get the account implementation identifier
    /// @return accountImplementationId Unique identifier string
    function accountId() external view returns (string memory accountImplementationId);

    /// @notice Check if account supports an execution mode
    /// @param encodedMode The encoded execution mode
    /// @return True if mode is supported
    function supportsExecutionMode(bytes32 encodedMode) external view returns (bool);

    /// @notice Check if account supports a module type
    /// @param moduleTypeId The module type identifier
    /// @return True if module type is supported
    function supportsModule(uint256 moduleTypeId) external view returns (bool);
}

/// @notice ERC-7579 Module Configuration interface
interface IERC7579ModuleConfig {
    /// @notice Emitted when a module is installed
    event ModuleInstalled(uint256 moduleTypeId, address module);

    /// @notice Emitted when a module is uninstalled
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    /// @notice Install a module on the account
    /// @param moduleTypeId The type of module (1=validator, 2=executor, 3=fallback, 4=hook)
    /// @param module The module address
    /// @param initData Initialization data for the module
    function installModule(uint256 moduleTypeId, address module, bytes calldata initData) external;

    /// @notice Uninstall a module from the account
    /// @param moduleTypeId The type of module
    /// @param module The module address
    /// @param deInitData De-initialization data for the module
    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData) external;

    /// @notice Check if a module is installed
    /// @param moduleTypeId The type of module
    /// @param module The module address
    /// @param additionalContext Additional context for the check
    /// @return True if module is installed
    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata additionalContext)
        external
        view
        returns (bool);
}

/// @notice Full ERC-7579 Account interface
/// @dev Combines execution, account config, and module config interfaces
interface IERC7579Account is IERC7579Execution, IERC7579AccountConfig, IERC7579ModuleConfig {}

// ============ Utility Library ============

/// @notice Library for encoding/decoding execution mode
library ModeLib {
    /// @notice Encode execution mode from components
    function encode(CallType callType, ExecType execType, ModeSelector selector, ModePayload payload)
        internal
        pure
        returns (ModeCode)
    {
        return ModeCode.wrap(
            bytes32(
                abi.encodePacked(
                    CallType.unwrap(callType),
                    ExecType.unwrap(execType),
                    bytes4(0), // unused
                    ModeSelector.unwrap(selector),
                    ModePayload.unwrap(payload)
                )
            )
        );
    }

    /// @notice Encode default single call mode
    function encodeSimpleSingle() internal pure returns (ModeCode) {
        return encode(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, ModeSelector.wrap(0x00000000), ModePayload.wrap(bytes22(0)));
    }

    /// @notice Encode default batch call mode
    function encodeSimpleBatch() internal pure returns (ModeCode) {
        return encode(CALLTYPE_BATCH, EXECTYPE_DEFAULT, ModeSelector.wrap(0x00000000), ModePayload.wrap(bytes22(0)));
    }

    /// @notice Decode execution mode into components
    function decode(ModeCode mode)
        internal
        pure
        returns (CallType callType, ExecType execType, ModeSelector selector, ModePayload payload)
    {
        bytes32 raw = ModeCode.unwrap(mode);
        callType = CallType.wrap(bytes1(raw));
        execType = ExecType.wrap(bytes1(raw << 8));
        selector = ModeSelector.wrap(bytes4(raw << 48));
        payload = ModePayload.wrap(bytes22(raw << 80));
    }

    /// @notice Get call type from mode
    function getCallType(ModeCode mode) internal pure returns (CallType) {
        return CallType.wrap(bytes1(ModeCode.unwrap(mode)));
    }

    /// @notice Get exec type from mode
    function getExecType(ModeCode mode) internal pure returns (ExecType) {
        return ExecType.wrap(bytes1(ModeCode.unwrap(mode) << 8));
    }
}

/// @notice Library for encoding execution calldata
library ExecutionLib {
    /// @notice Encode a single execution
    function encodeSingle(address target, uint256 value, bytes memory callData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(target, value, callData);
    }

    /// @notice Decode a single execution
    function decodeSingle(bytes calldata executionCalldata)
        internal
        pure
        returns (address target, uint256 value, bytes calldata callData)
    {
        target = address(bytes20(executionCalldata[:20]));
        value = uint256(bytes32(executionCalldata[20:52]));
        callData = executionCalldata[52:];
    }

    /// @notice Encode a batch of executions
    function encodeBatch(Execution[] memory executions) internal pure returns (bytes memory) {
        return abi.encode(executions);
    }

    /// @notice Decode a batch of executions
    function decodeBatch(bytes calldata executionCalldata) internal pure returns (Execution[] calldata executions) {
        assembly {
            let ptr := add(executionCalldata.offset, calldataload(executionCalldata.offset))
            executions.offset := add(ptr, 0x20)
            executions.length := calldataload(ptr)
        }
    }
}
