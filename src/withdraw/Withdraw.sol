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
import {Error} from "../utils/Error.sol";
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
    bytes32 public constant INTENT_TYPEHASH =
        keccak256("WithdrawIntent(address user,address master,address token,uint256 shares,uint256 acceptableSharePrice,uint256 minAmountOut,uint256 nonce,uint256 deadline)");

    bytes32 public constant ATTESTATION_TYPEHASH =
        keccak256("WithdrawAttestation(address user,address master,address token,uint256 shares,uint256 sharePrice,uint256 blockNumber,uint256 blockTimestamp,uint256 nonce,uint256 deadline)");

    uint256 internal constant _NONCE_SCOPE = uint32(bytes4(keccak256("Withdraw")));

    ModeCode internal constant MODE_STRICT =
        ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00))));

    struct WithdrawIntent {
        address user;
        address master;
        address token;
        uint256 shares;
        uint256 acceptableSharePrice;
        uint256 minAmountOut;
        uint256 nonce;
        uint256 deadline;
    }

    struct WithdrawAttestation {
        address user;
        address master;
        address token;
        uint256 shares;
        uint256 sharePrice;
        uint256 blockNumber;
        uint256 blockTimestamp;
        uint256 nonce;
        uint256 deadline;
    }

    struct Config {
        address attestor;
        uint256 gasLimit;
        uint256 maxBlockStaleness;
        uint256 maxTimestampAge;
    }

    Config public config;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Withdraw", "1")
    {}

    function withdraw(
        WithdrawIntent calldata intent,
        WithdrawAttestation calldata attestation,
        bytes calldata intentSignature,
        bytes calldata attestationSignature
    ) external auth {
        if (block.timestamp > intent.deadline) revert Error.Withdraw__ExpiredDeadline();
        if (intent.shares == 0) revert Error.Withdraw__ZeroShares();
        if (intent.user == address(0)) revert Error.Withdraw__InvalidUser();
        if (intent.master == address(0)) revert Error.Withdraw__InvalidMaster();

        if (attestation.user != intent.user) revert Error.Withdraw__InvalidUser();
        if (attestation.master != intent.master) revert Error.Withdraw__InvalidMaster();
        if (attestation.token != intent.token) revert Error.Withdraw__InvalidToken();
        if (attestation.shares != intent.shares) revert Error.Withdraw__SharesMismatch();
        if (attestation.nonce != intent.nonce) revert Error.Withdraw__NonceMismatch();
        if (attestation.sharePrice < intent.acceptableSharePrice) revert Error.Withdraw__SharePriceBelowMin();
        if (block.timestamp > attestation.deadline) revert Error.Withdraw__ExpiredDeadline();
        if (block.number - attestation.blockNumber > config.maxBlockStaleness) revert Error.Withdraw__AttestationBlockStale(attestation.blockNumber, block.number, config.maxBlockStaleness);
        if (block.timestamp - attestation.blockTimestamp > config.maxTimestampAge) revert Error.Withdraw__AttestationTimestampStale(attestation.blockTimestamp, block.timestamp, config.maxTimestampAge);

        uint256 amount = Precision.applyFactor(attestation.sharePrice, intent.shares);
        if (amount < intent.minAmountOut) revert Error.Withdraw__AmountBelowMin();

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
            attestation.blockNumber,
            attestation.blockTimestamp,
            attestation.nonce,
            attestation.deadline
        )));

        if (!SignatureCheckerLib.isValidSignatureNow(intent.user, intentDigest, intentSignature)) {
            revert Error.Withdraw__InvalidUserSignature();
        }
        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, attestationDigest, attestationSignature)) {
            revert Error.Withdraw__InvalidAttestorSignature();
        }

        NonceLib.consume(_NONCE_SCOPE, intent.nonce);

        IERC20 token = IERC20(intent.token);
        uint256 balanceBefore = token.balanceOf(intent.user);

        IERC7579Account(intent.master).executeFromExecutor{gas: config.gasLimit}(
            MODE_STRICT,
            ExecutionLib.encodeSingle(intent.token, 0, abi.encodeCall(IERC20.transfer, (intent.user, amount)))
        );

        uint256 balanceAfter = token.balanceOf(intent.user);
        if (balanceAfter - balanceBefore != amount) revert Error.Withdraw__TransferAmountMismatch();

        _logEvent(
            "Withdraw",
            abi.encode(intent.user, intent.master, intent.token, intent.shares, attestation.sharePrice, amount, intent.nonce)
        );
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.attestor == address(0)) revert Error.Withdraw__InvalidConfig();
        if (_config.gasLimit == 0) revert Error.Withdraw__InvalidConfig();
        if (_config.maxBlockStaleness == 0) revert Error.Withdraw__InvalidConfig();
        if (_config.maxTimestampAge == 0) revert Error.Withdraw__InvalidConfig();
        config = _config;
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external pure {
        revert Error.Withdraw__UninstallDisabled();
    }
}
