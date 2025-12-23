// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

// ERC-7579 Module Type Constants
uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILED = 1;

uint256 constant MODULE_TYPE_VALIDATOR = 1;
uint256 constant MODULE_TYPE_EXECUTOR = 2;
uint256 constant MODULE_TYPE_FALLBACK = 3;
uint256 constant MODULE_TYPE_HOOK = 4;

// ERC-1271 Magic Values
bytes4 constant EIP1271_SUCCESS = 0x1626ba7e;
bytes4 constant EIP1271_FAILED = 0xFFFFFFFF;

/// @notice Minimal ERC-4337 PackedUserOperation for validation
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

/// @notice Base ERC-7579 module interface
interface IModule {
    /// @notice Called during module installation
    /// @param data Arbitrary data for initialization
    function onInstall(bytes calldata data) external;

    /// @notice Called during module uninstallation
    /// @param data Arbitrary data for cleanup
    function onUninstall(bytes calldata data) external;

    /// @notice Check if module is of a specific type
    /// @param moduleTypeId The module type to check
    /// @return True if module matches the type
    function isModuleType(uint256 moduleTypeId) external view returns (bool);

    /// @notice Check if module is initialized for an account
    /// @param smartAccount The account to check
    /// @return True if initialized
    function isInitialized(address smartAccount) external view returns (bool);
}

/// @notice ERC-7579 validator module interface
interface IValidator is IModule {
    /// @notice Validate an ERC-4337 user operation
    /// @param userOp The packed user operation
    /// @param userOpHash Hash of the user operation
    /// @return Validation result (0 = success, 1 = failure)
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256);

    /// @notice Validate an ERC-1271 signature
    /// @param sender The address that signed
    /// @param hash The hash that was signed
    /// @param data The signature data
    /// @return Magic value (0x1626ba7e = success)
    function isValidSignatureWithSender(address sender, bytes32 hash, bytes calldata data)
        external
        view
        returns (bytes4);
}

/// @notice ERC-7579 executor module interface
interface IExecutor is IModule {}

/// @notice ERC-7579 hook module interface
interface IHook is IModule {
    /// @notice Pre-execution check
    /// @param msgSender The original sender
    /// @param msgValue The value sent
    /// @param msgData The calldata
    /// @return hookData Data to pass to postCheck
    function preCheck(address msgSender, uint256 msgValue, bytes calldata msgData)
        external
        returns (bytes memory hookData);

    /// @notice Post-execution check
    /// @param hookData Data from preCheck
    function postCheck(bytes calldata hookData) external;
}

/// @notice ERC-7579 fallback module interface
interface IFallback is IModule {}
