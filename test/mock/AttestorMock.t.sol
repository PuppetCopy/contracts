// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/src/Test.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {Allocate} from "src/position/Allocate.sol";

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

    /// @notice Sign an AllocateAttestation
    function signAllocateAttestation(
        Allocate allocate,
        IERC7579Account master,
        uint256 sharePrice,
        address[] memory puppetList,
        uint256[] memory amountList,
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
                puppetListHash,
                amountListHash,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = _computeDomainSeparator(address(allocate));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return Allocate.AllocateAttestation({
            sharePrice: sharePrice,
            puppetListHash: puppetListHash,
            amountListHash: amountListHash,
            nonce: nonce,
            deadline: deadline,
            signature: signature
        });
    }

    /// @notice Sign a WithdrawAttestation
    function signWithdrawAttestation(
        Allocate allocate,
        address user,
        IERC7579Account master,
        uint256 amount,
        uint256 sharePrice,
        uint256 nonce,
        uint256 deadline
    ) external view returns (Allocate.WithdrawAttestation memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                allocate.WITHDRAW_ATTESTATION_TYPEHASH(),
                user,
                master,
                amount,
                sharePrice,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = _computeDomainSeparator(address(allocate));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return Allocate.WithdrawAttestation({
            user: user,
            master: master,
            amount: amount,
            sharePrice: sharePrice,
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
