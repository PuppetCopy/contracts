// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

/// @title NonceLib
/// @notice Library for consuming bitpacked nonces with optional account scoping
/// @dev Stores 256 nonces per storage slot for gas efficiency
///      Inspired by The Compact's ConsumerLib
///      Errors defined in Error.sol: NonceLib__InvalidNonce, NonceLib__InvalidNonceForAccount
library NonceLib {
    /// @notice Consume a global nonce (not scoped to any account)
    /// @param scope Unique identifier for the nonce domain (4 bytes, e.g., 0x41545354 for "ATST")
    /// @param nonce The nonce to consume
    function consume(uint256 scope, uint256 nonce) internal {
        assembly ("memory-safe") {
            let freeMemoryPointer := mload(0x40)

            // Bucket slot = keccak256(scope ++ nonce[0:31])
            mstore(0x0c, scope)
            mstore(0x20, nonce)
            let bucketSlot := keccak256(0x28, 0x17)

            let bucketValue := sload(bucketSlot)
            let bit := shl(and(0xff, nonce), 1)
            if and(bit, bucketValue) {
                // Error.NonceLib__InvalidNonce(uint256) - selector: 0xc2751a08
                mstore(0x00, 0xc2751a08)
                mstore(0x20, nonce)
                revert(0x1c, 0x24)
            }

            sstore(bucketSlot, or(bucketValue, bit))
            mstore(0x40, freeMemoryPointer)
        }
    }

    /// @notice Check if a global nonce has been consumed
    /// @param scope Unique identifier for the nonce domain
    /// @param nonce The nonce to check
    /// @return consumed Whether the nonce has been consumed
    function isConsumed(uint256 scope, uint256 nonce) internal view returns (bool consumed) {
        assembly ("memory-safe") {
            let freeMemoryPointer := mload(0x40)

            mstore(0x0c, scope)
            mstore(0x20, nonce)

            consumed := gt(and(shl(and(0xff, nonce), 1), sload(keccak256(0x28, 0x17))), 0)

            mstore(0x40, freeMemoryPointer)
        }
    }

    /// @notice Consume a nonce scoped to a specific account
    /// @param scope Unique identifier for the nonce domain
    /// @param nonce The nonce to consume
    /// @param account The account to scope the nonce to
    function consumeBy(uint256 scope, uint256 nonce, address account) internal {
        assembly ("memory-safe") {
            let freeMemoryPointer := mload(0x40)

            // Bucket slot = keccak256(scope ++ account ++ nonce[0:31])
            mstore(0x20, account)
            mstore(0x0c, scope)
            mstore(0x40, nonce)
            let bucketSlot := keccak256(0x28, 0x37)

            let bucketValue := sload(bucketSlot)
            let bit := shl(and(0xff, nonce), 1)
            if and(bit, bucketValue) {
                // Error.NonceLib__InvalidNonceForAccount(address,uint256) - selector: 0x1be3eedf
                mstore(0x00, 0x1be3eedf)
                mstore(0x20, account)
                mstore(0x40, nonce)
                revert(0x1c, 0x44)
            }

            sstore(bucketSlot, or(bucketValue, bit))
            mstore(0x40, freeMemoryPointer)
        }
    }

    /// @notice Check if a scoped nonce has been consumed for an account
    /// @param scope Unique identifier for the nonce domain
    /// @param nonce The nonce to check
    /// @param account The account to check
    /// @return consumed Whether the nonce has been consumed
    function isConsumedBy(uint256 scope, uint256 nonce, address account) internal view returns (bool consumed) {
        assembly ("memory-safe") {
            let freeMemoryPointer := mload(0x40)

            mstore(0x20, account)
            mstore(0x0c, scope)
            mstore(0x40, nonce)

            consumed := gt(and(shl(and(0xff, nonce), 1), sload(keccak256(0x28, 0x37))), 0)

            mstore(0x40, freeMemoryPointer)
        }
    }
}
