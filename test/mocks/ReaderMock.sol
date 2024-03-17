// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

contract ReaderMock {

    function isRouteRegistered(address) external pure returns (bool) {
        return true;
    }
}