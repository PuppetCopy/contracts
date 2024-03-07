// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface ISmartWalletWhitelist {
    function approveWallet(address _wallet) external;
}