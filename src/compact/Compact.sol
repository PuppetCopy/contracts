// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {ERC6909} from "solady/tokens/ERC6909.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {NonceLib} from "../utils/NonceLib.sol";

/// @title Compact
/// @notice Minimal ERC-6909 share accounting for cross-chain accounting
/// @dev Inspired by The Compact:
///      - Bitpacked nonces from ConsumerLib
///      - Domain separator caching from DomainLib
///      - ERC-6909 from Solady
contract Compact is ERC6909, CoreContract {
    /// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 internal constant _DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev keccak256(bytes("Puppet Compact"))
    bytes32 internal constant _NAME_HASH = 0xe0f9546cc9b441d1fb0a974383ef41ffcfbd3a4e4fb2cfb81dabef33cf43a8d1;

    /// @dev keccak256("1")
    bytes32 internal constant _VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    /// @dev keccak256("Mint(address to,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 internal constant _MINT_TYPEHASH = 0x3b2df060acc07d7a55f3b12269bbcce371d923af4acb349c915503b3b183dab4;

    /// @dev keccak256("Burn(address from,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 internal constant _BURN_TYPEHASH = 0x952d033443e48f0c1ec8d4985e300a50a13b6f9d9092437246f074ba5a18b0b6;

    /// @dev Nonce scope for bitpacked nonce buckets
    uint private constant _NONCE_SCOPE = 0x50757070; // "Pupp"

    struct Config {
        address attestor;
    }

    Config public config;

    /// @dev Chain ID at deployment for domain separator caching
    uint private immutable _INITIAL_CHAIN_ID;

    /// @dev Initial domain separator computed at deployment
    bytes32 private immutable _INITIAL_DOMAIN_SEPARATOR;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {
        _INITIAL_CHAIN_ID = block.chainid;
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator(block.chainid);
    }

    function claim(
        address to,
        uint tokenId,
        uint amount,
        uint nonce,
        uint deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert Error.Compact__ExpiredDeadline();

        bytes32 digest = _hashTypedData(keccak256(abi.encode(_MINT_TYPEHASH, to, tokenId, amount, nonce, deadline)));

        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, digest, signature)) {
            revert Error.Compact__InvalidSignature();
        }

        NonceLib.consumeBy(_NONCE_SCOPE, nonce, to);
        _mint(to, tokenId, amount);

        _logEvent("Mint", abi.encode(to, tokenId, amount, nonce));
    }

    function redeem(
        address from,
        uint tokenId,
        uint amount,
        uint nonce,
        uint deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert Error.Compact__ExpiredDeadline();

        bytes32 digest = _hashTypedData(keccak256(abi.encode(_BURN_TYPEHASH, from, tokenId, amount, nonce, deadline)));

        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, digest, signature)) {
            revert Error.Compact__InvalidSignature();
        }

        NonceLib.consumeBy(_NONCE_SCOPE, nonce, from);
        _burn(from, tokenId, amount);

        _logEvent("Burn", abi.encode(from, tokenId, amount, nonce));
    }

    /// @notice Authorized mint (for Allocate contract)
    /// @dev ERC6909 emits Transfer event
    function mint(address to, uint tokenId, uint amount) external auth {
        _mint(to, tokenId, amount);
    }

    /// @notice Authorized burn (for Allocate contract)
    /// @dev ERC6909 emits Transfer event
    function burn(address from, uint tokenId, uint amount) external auth {
        _burn(from, tokenId, amount);
    }

    function mintMany(address[] calldata recipientList, uint tokenId, uint[] calldata amountList) external auth {
        if (recipientList.length != amountList.length) revert Error.Compact__ArrayLengthMismatch();
        for (uint i; i < recipientList.length; ++i) {
            if (amountList[i] != 0) {
                _mint(recipientList[i], tokenId, amountList[i]);
            }
        }
    }

    function burnMany(address[] calldata ownerList, uint tokenId, uint[] calldata amountList) external auth {
        if (ownerList.length != amountList.length) revert Error.Compact__ArrayLengthMismatch();
        for (uint i; i < ownerList.length; ++i) {
            if (amountList[i] != 0) {
                _burn(ownerList[i], tokenId, amountList[i]);
            }
        }
    }

    /// @notice Get the domain separator for the current chain
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @notice Check if a nonce has been consumed for an account
    function isNonceConsumed(address account, uint nonce) external view returns (bool) {
        return NonceLib.isConsumedBy(_NONCE_SCOPE, nonce, account);
    }

    function name(uint) public pure override returns (string memory) {
        return "Puppet Share";
    }

    function symbol(uint) public pure override returns (string memory) {
        return "pSHARE";
    }

    function decimals(uint) public pure override returns (uint8) {
        return 18;
    }

    function tokenURI(uint) public pure override returns (string memory) {
        return "";
    }

    /// @notice ERC-165 interface support (combines ERC6909 and CoreContract)
    /// @dev ERC165: 0x01ffc9a7, ERC6909: 0x0f632fb3
    function supportsInterface(bytes4 interfaceId) public pure override(ERC6909, CoreContract) returns (bool result) {
        assembly {
            let s := shr(224, interfaceId)
            result := or(eq(s, 0x01ffc9a7), eq(s, 0x0f632fb3))
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _newConfig = abi.decode(_data, (Config));
        if (_newConfig.attestor == address(0)) revert Error.Compact__InvalidAttestor();
        config = _newConfig;
        _logEvent("SetConfig", abi.encode(_newConfig));
    }

    /// @dev Get current domain separator, recomputing if chain ID changed
    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _INITIAL_CHAIN_ID) {
            return _INITIAL_DOMAIN_SEPARATOR;
        }
        return _computeDomainSeparator(block.chainid);
    }

    /// @dev Compute EIP-712 domain separator for a given chain ID
    function _computeDomainSeparator(uint chainId) internal view returns (bytes32 domainSeparator) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), _NAME_HASH)
            mstore(add(m, 0x40), _VERSION_HASH)
            mstore(add(m, 0x60), chainId)
            mstore(add(m, 0x80), address())
            domainSeparator := keccak256(m, 0xa0)
        }
    }

    /// @dev Hash typed data with domain separator (EIP-712)
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32 digest) {
        bytes32 domainSep = _domainSeparator();
        assembly ("memory-safe") {
            let m := mload(0x40)
            mstore(0x00, 0x1901)
            mstore(0x20, domainSep)
            mstore(0x40, structHash)
            digest := keccak256(0x1e, 0x42)
            mstore(0x40, m)
        }
    }

}
