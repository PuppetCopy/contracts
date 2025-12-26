// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

interface INpvReader {
    function getPositionNetValue(bytes32 _positionKey) external view returns (int256 netValue);
    function parsePositionKey(address _account, bytes calldata _callData) external pure returns (bytes32);
}
