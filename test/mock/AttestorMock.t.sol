// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/src/Test.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Withdraw} from "src/withdraw/Withdraw.sol";

/// @title AttestorMock
/// @notice Test helper for signing attestations with a known private key
/// @dev Uses Foundry's vm.sign for EIP-712 signatures
contract AttestorMock is Test {
    uint256 public attestorPrivateKey;
    address public attestorAddress;

    constructor(uint256 _privateKey) {
        attestorPrivateKey = _privateKey;
        attestorAddress = vm.addr(_privateKey);
    }

    // ============ Withdraw Signatures ============

    function signWithdrawAttestation(
        Withdraw withdraw,
        address user,
        address master,
        address token,
        uint256 shares,
        uint256 sharePrice,
        uint256 nonce,
        uint256 deadline
    ) external view returns (Withdraw.WithdrawAttestation memory, bytes memory) {
        Withdraw.WithdrawAttestation memory attestation = Withdraw.WithdrawAttestation({
            user: user,
            master: master,
            token: token,
            shares: shares,
            sharePrice: sharePrice,
            blockNumber: block.number,
            blockTimestamp: block.timestamp,
            nonce: nonce,
            deadline: deadline
        });

        bytes32 structHash = keccak256(
            abi.encode(
                withdraw.ATTESTATION_TYPEHASH(),
                user,
                master,
                token,
                shares,
                sharePrice,
                block.number,
                block.timestamp,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = _computeWithdrawDomainSeparator(address(withdraw));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return (attestation, signature);
    }

    function _computeWithdrawDomainSeparator(address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Withdraw"),
                keccak256("1"),
                block.chainid,
                verifyingContract
            )
        );
    }

    // ============ Allocate Signatures ============

    function signAllocateAttestation(
        Allocate allocate,
        IERC7579Account master,
        uint256 sharePrice,
        uint256 masterAmount,
        address[] memory puppetList,
        uint256[] memory amountList,
        uint256 blockNumber,
        uint256 blockTimestamp,
        uint256 nonce,
        uint256 deadline
    ) external view returns (Allocate.AllocateAttestation memory) {
        bytes32 puppetListHash = keccak256(abi.encodePacked(puppetList));
        bytes32 amountListHash = keccak256(abi.encodePacked(amountList));

        bytes32 structHash = keccak256(
            abi.encode(
                allocate.ALLOCATE_ATTESTATION_TYPEHASH(),
                master,
                sharePrice,
                masterAmount,
                puppetListHash,
                amountListHash,
                blockNumber,
                blockTimestamp,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = _computeDomainSeparator(address(allocate));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return Allocate.AllocateAttestation({
            master: master,
            sharePrice: sharePrice,
            masterAmount: masterAmount,
            puppetListHash: puppetListHash,
            amountListHash: amountListHash,
            blockNumber: blockNumber,
            blockTimestamp: blockTimestamp,
            nonce: nonce,
            deadline: deadline,
            signature: signature
        });
    }

    /// @dev Compute EIP-712 domain separator for Allocate contract
    function _computeDomainSeparator(address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Allocate"),
                keccak256("1"),
                block.chainid,
                verifyingContract
            )
        );
    }
}
