// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface IAccess {
    function canCall(address user) external view returns (bool);
}
