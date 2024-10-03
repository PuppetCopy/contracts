// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

interface IPermission {
    function canCall(bytes4 signatureHash, address user) external view returns (bool);
}
