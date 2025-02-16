// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @title WNT
// @dev similar implementation as WETH but since some networks
// might have a different native token we use WNT for a more general reference name
interface IWNT is IERC20 {
    error TransferFailed(address account, uint amount);

    // @dev mint WNT by depositing the native token
    function deposit() external payable;

    // @dev withdraw the native token by burning WNT
    // @param amount the amount to withdraw
    function withdraw(uint amount) external;

    // @dev mint tokens to an account
    // @param account the account to mint to
    // @param amount the amount of tokens to mint
    function mint(address account, uint amount) external;

    // @dev burn tokens from an account
    // @param account the account to burn tokens for
    // @param amount the amount of tokens to burn
    function burn(address account, uint amount) external;
}
