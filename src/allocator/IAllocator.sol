// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IAllocator - The Compact's allocator interface
/// @notice Interface that allocators must implement to authorize transfers from resource locks
/// @dev See https://github.com/Uniswap/the-compact
interface IAllocator {
    /// @notice Validate a transfer from a resource lock
    /// @param operator The address executing the transfer
    /// @param from The address of the resource lock owner
    /// @param to The recipient address
    /// @param id The ERC6909 token ID (lockTag + tokenAddress)
    /// @param amount The amount being transferred
    /// @return bytes4 Must return 0x1a808f91 (attest selector) to approve
    function attest(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external returns (bytes4);

    /// @notice Authorize a claim submitted through The Compact
    /// @param claimHash Hash of the claim data
    /// @param arbiter Address that can arbitrate disputes
    /// @param sponsor Address sponsoring the claim
    /// @param nonce Replay protection nonce
    /// @param expires Timestamp when authorization expires
    /// @param idsAndAmounts Array of [tokenId, amount] pairs
    /// @param allocatorData Custom data for authorization (e.g., signature)
    /// @return bytes4 Must return 0x7bb023f7 (authorizeClaim selector) to approve
    function authorizeClaim(
        bytes32 claimHash,
        address arbiter,
        address sponsor,
        uint256 nonce,
        uint256 expires,
        uint256[2][] calldata idsAndAmounts,
        bytes calldata allocatorData
    ) external returns (bytes4);

    /// @notice Check if allocatorData authorizes a claim (view function for off-chain use)
    /// @dev Same parameters as authorizeClaim but returns bool instead of executing
    function isClaimAuthorized(
        bytes32 claimHash,
        address arbiter,
        address sponsor,
        uint256 nonce,
        uint256 expires,
        uint256[2][] calldata idsAndAmounts,
        bytes calldata allocatorData
    ) external view returns (bool);
}
