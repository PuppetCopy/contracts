// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

interface INpvReader {
    struct PositionCallInfo {
        bytes32 positionKey;
        address collateralToken;
        bool isIncrease;
        uint256 sizeDelta;
        uint256 collateralDelta;
    }

    function getPositionNetValue(bytes32 _positionKey) external view returns (uint256 netValue);
    function parsePositionCall(address _account, bytes calldata _callData) external pure returns (PositionCallInfo memory);
}
