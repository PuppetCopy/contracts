// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

interface IReferralStorage {
    function setCodeOwner(bytes32 _codeHash, address _owner) external;
}
