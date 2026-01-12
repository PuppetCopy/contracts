// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IExecutor, MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {
    ModeCode,
    ModePayload,
    CALLTYPE_SINGLE,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT
} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {NonceLib} from "../utils/NonceLib.sol";
import {Precision} from "../utils/Precision.sol";

/// @title Withdraw
/// @notice Intent-based cross-chain withdrawal with attestor price oracle
/// @dev Deployed via CREATE2 at same address across all chains.
///      User signs intent (shares + minAmountOut), attestor provides current price.
///      Execution is permissionless - anyone can submit with valid signatures.
///      Attestor tracks share burns off-chain via event sourcing.
///      Config controlled by Dictatorship (DAO in future).
contract Withdraw is CoreContract, EIP712, IExecutor {
    // ============ Errors ============

    error ExpiredDeadline();
    error ZeroShares();
    error InvalidUser();
    error InvalidMaster();
    error InvalidToken();
    error SharesMismatch();
    error NonceMismatch();
    error SharePriceBelowMin();
    error AmountBelowMin();
    error InvalidUserSignature();
    error InvalidAttestorSignature();
    error TransferAmountMismatch();
    error UninstallDisabled();
    error InvalidConfig();

    // ============ Constants ============

    bytes32 public constant INTENT_TYPEHASH =
        keccak256("WithdrawIntent(address user,address master,address token,uint256 shares,uint256 acceptableSharePrice,uint256 minAmountOut,uint256 nonce,uint256 deadline)");

    bytes32 public constant ATTESTATION_TYPEHASH =
        keccak256("WithdrawAttestation(address user,address master,address token,uint256 shares,uint256 sharePrice,uint256 nonce,uint256 deadline)");

    uint256 internal constant _NONCE_SCOPE = uint32(bytes4(keccak256("Withdraw")));

    ModeCode internal constant MODE_STRICT =
        ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00))));

    // ============ Structs ============

    /// @notice User's withdrawal intent - commits to burning shares with price floor
    struct WithdrawIntent {
        address user;
        address master;
        address token;
        uint256 shares;
        uint256 acceptableSharePrice;  // user's minimum acceptable price per share
        uint256 minAmountOut;          // slippage protection on final amount
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Attestor's validation - confirms intent and provides current price
    struct WithdrawAttestation {
        address user;
        address master;
        address token;
        uint256 shares;
        uint256 sharePrice;  // current NAV-derived price per share
        uint256 nonce;
        uint256 deadline;
    }

    struct Config {
        address attestor;
        uint256 gasLimit;
    }

    // ============ State ============

    Config public config;

    // ============ Constructor ============

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Withdraw", "1")
    {}

    // ============ External ============

    /// @notice Execute withdrawal with user intent and attestor validation
    /// @dev Permissionless - anyone can execute with valid signatures
    function withdraw(
        WithdrawIntent calldata intent,
        WithdrawAttestation calldata attestation,
        bytes calldata intentSignature,
        bytes calldata attestationSignature
    ) external {
        // Validate intent
        if (block.timestamp > intent.deadline) revert ExpiredDeadline();
        if (intent.shares == 0) revert ZeroShares();
        if (intent.user == address(0)) revert InvalidUser();
        if (intent.master == address(0)) revert InvalidMaster();

        // Validate attestation matches intent
        if (attestation.user != intent.user) revert InvalidUser();
        if (attestation.master != intent.master) revert InvalidMaster();
        if (attestation.token != intent.token) revert InvalidToken();
        if (attestation.shares != intent.shares) revert SharesMismatch();
        if (attestation.nonce != intent.nonce) revert NonceMismatch();
        if (block.timestamp > attestation.deadline) revert ExpiredDeadline();
        if (attestation.sharePrice < intent.acceptableSharePrice) revert SharePriceBelowMin();

        // Calculate amount and verify slippage protection
        uint256 amount = Precision.applyFactor(attestation.sharePrice, intent.shares);
        if (amount < intent.minAmountOut) revert AmountBelowMin();

        // Verify signatures
        bytes32 intentDigest = _hashTypedDataV4(keccak256(abi.encode(
            INTENT_TYPEHASH,
            intent.user,
            intent.master,
            intent.token,
            intent.shares,
            intent.acceptableSharePrice,
            intent.minAmountOut,
            intent.nonce,
            intent.deadline
        )));
        bytes32 attestationDigest = _hashTypedDataV4(keccak256(abi.encode(
            ATTESTATION_TYPEHASH,
            attestation.user,
            attestation.master,
            attestation.token,
            attestation.shares,
            attestation.sharePrice,
            attestation.nonce,
            attestation.deadline
        )));

        if (!SignatureCheckerLib.isValidSignatureNow(intent.user, intentDigest, intentSignature)) {
            revert InvalidUserSignature();
        }
        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, attestationDigest, attestationSignature)) {
            revert InvalidAttestorSignature();
        }

        // Consume nonce
        NonceLib.consume(_NONCE_SCOPE, intent.nonce);

        // Transfer assets from master to user
        IERC20 token = IERC20(intent.token);
        uint256 balanceBefore = token.balanceOf(intent.user);

        IERC7579Account(intent.master).executeFromExecutor{gas: config.gasLimit}(
            MODE_STRICT,
            ExecutionLib.encodeSingle(intent.token, 0, abi.encodeCall(IERC20.transfer, (intent.user, amount)))
        );

        uint256 balanceAfter = token.balanceOf(intent.user);
        if (balanceAfter - balanceBefore != amount) revert TransferAmountMismatch();

        _logEvent(
            "Withdraw",
            abi.encode(intent.user, intent.master, intent.token, intent.shares, attestation.sharePrice, amount, intent.nonce)
        );
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    // ============ Internal ============

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.attestor == address(0)) revert InvalidConfig();
        if (_config.gasLimit == 0) revert InvalidConfig();
        config = _config;
    }

    // ============ IExecutor Interface ============

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external pure {
        revert UninstallDisabled();
    }
}
