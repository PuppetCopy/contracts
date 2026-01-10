// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {NonceLib} from "../utils/NonceLib.sol";

/// @title Attest
/// @notice General attestation contract for cross-chain signature verification
/// @dev Uses bitpacked nonces for efficient replay protection (inspired by The Compact)
///      Payload-agnostic: callers provide the digest, Attest verifies signature and nonce
contract Attest is CoreContract {
    /// @dev Nonce scope for bitpacked nonce buckets
    uint256 private constant _NONCE_SCOPE = 0x41545354; // "ATST"

    struct Config {
        address attestor;
    }

    Config public config;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
    {}

    /// @notice Verify attestor signature and consume nonce
    /// @param _digest The EIP-712 digest to verify (caller computes this)
    /// @param _signature The attestor's signature
    /// @param _nonce The nonce for replay protection (global, not scoped per account)
    function verify(
        bytes32 _digest,
        bytes calldata _signature,
        uint _nonce
    ) external auth {
        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, _digest, _signature)) {
            revert Error.Attest__InvalidSignature();
        }
        NonceLib.consume(_NONCE_SCOPE, _nonce);
    }

    /// @notice Check if a nonce has been consumed
    function isNonceConsumed(uint256 nonce) external view returns (bool) {
        return NonceLib.isConsumed(_NONCE_SCOPE, nonce);
    }

    /// @notice Get the attestor address
    function getAttestor() external view returns (address) {
        return config.attestor;
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _newConfig = abi.decode(_data, (Config));
        if (_newConfig.attestor == address(0)) revert Error.Attest__InvalidAttestor();
        config = _newConfig;
        _logEvent("SetConfig", abi.encode(_newConfig));
    }
}
