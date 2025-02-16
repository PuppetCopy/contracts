// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IAuthority {
    function logEvent(string memory method, string memory name, string memory version, bytes memory data) external;
}
