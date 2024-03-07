// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface IGMXV2Route {
    function claimFundingFees(address[] memory _markets, address[] memory _tokens) external;
}