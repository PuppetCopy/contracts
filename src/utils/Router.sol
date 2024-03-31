// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Router
 * @dev Users will approve this router for token spenditures
 */
contract Router is Auth {
    constructor(Authority _authority) Auth(address(0), _authority) {
        authority = _authority;
    }

    /**
     * @dev transfer the specified amount of tokens from the account to the receiver
     * @param token the token to transfer
     * @param from the account to transfer from
     * @param to the account to transfer to
     * @param amount the amount to transfer
     */
    function transfer(IERC20 token, address from, address to, uint amount) external requiresAuth {
        SafeERC20.safeTransferFrom(token, from, to, amount);
    }
    

    /**
     * @dev low level call to an ERC20 contract, return raw data to be handled by authorised contract
     * @param token the token to transfer
     * @param from the account to transfer from
     * @param to the account to transfer to
     * @param amount the amount to transfer
     */
    function rawTransfer(IERC20 token, address from, address to, uint amount) external requiresAuth returns (bool success, bytes memory returndata) {
        return address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
    }
}
