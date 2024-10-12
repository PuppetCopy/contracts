// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface IPermission {
    function canCall(bytes4 signatureHash, address user) external view returns (bool);
}
