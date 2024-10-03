// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

interface IAccess {
    function canCall(address user) external view returns (bool);
}
