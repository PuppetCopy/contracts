// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

interface IAuthority {
    function logEvent(string calldata method, bytes calldata data) external;
}
