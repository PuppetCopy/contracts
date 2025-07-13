// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenRouter} from "../shared/TokenRouter.sol";

import {Error} from "./../utils/Error.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {TransferUtils} from "./TransferUtils.sol";
import {Access} from "./auth/Access.sol";

/**
 * @title BankStore
 * @notice Base contract for safely storing and managing ERC20 tokens with internal accounting
 * @dev Provides functionality for token balance tracking, transfers between contracts,
 *      and secure token operations with access control
 */
abstract contract BankStore is Access {
    /// @notice Maps each ERC20 token to its internally tracked balance
    mapping(IERC20 => uint) public tokenBalanceMap;

    /// @notice Immutable reference to the token router for safe token transfers
    TokenRouter immutable router;

    /**
     * @notice Initializes the BankStore with authority and router
     * @param _authority The authority contract for permission management
     * @param _router The token router for safe token transfers
     */
    constructor(IAuthority _authority, TokenRouter _router) Access(_authority) {
        router = _router;
    }

    /**
     * @notice Returns the internally tracked balance of a token
     * @param _token The ERC20 token address to query
     * @return The current balance recorded for the token
     */
    function getTokenBalance(
        IERC20 _token
    ) external view returns (uint) {
        return tokenBalanceMap[_token];
    }

    /**
     * @notice Records tokens that were directly transferred to this contract
     * @dev Updates the internal balance map based on actual token balance change
     * @param _token The ERC20 token address to record
     * @return The amount of tokens that were added to the contract
     */
    function recordTransferIn(
        IERC20 _token
    ) external auth returns (uint) {
        uint _prevBalance = tokenBalanceMap[_token];
        uint _currentBalance = _token.balanceOf(address(this));
        tokenBalanceMap[_token] = _currentBalance;

        return _currentBalance - _prevBalance;
    }

    /**
     * @notice Transfers tokens from this contract to another address
     * @dev Requires sufficient balance in the tokenBalanceMap
     * @param gasLimit The maximum amount of gas that the transfer can consume
     * @param _token The ERC20 token address to transfer
     * @param _receiver The address to receive the tokens
     * @param _value The amount of tokens to transfer
     */
    function transferOut(uint gasLimit, IERC20 _token, address _receiver, uint _value) public auth {
        require(tokenBalanceMap[_token] >= _value, Error.BankStore__InsufficientBalance());

        tokenBalanceMap[_token] -= _value;

        TransferUtils.transferStrictly(gasLimit, _token, _receiver, _value);
    }

    /**
     * @notice Transfers tokens from a user to this contract using the router
     * @param _token The ERC20 token address to transfer
     * @param _depositor The address to transfer tokens from
     * @param _value The amount of tokens to transfer
     */
    function transferIn(IERC20 _token, address _depositor, uint _value) public auth {
        router.transfer(_token, _depositor, address(this), _value);
        tokenBalanceMap[_token] += _value;
    }

    /**
     * @notice Syncs the internal balance tracking with the actual token balance
     * @dev Used to correct any discrepancies between tracked and actual balance
     * @param _token The ERC20 token address to sync
     */
    function syncTokenBalance(
        IERC20 _token
    ) external auth {
        tokenBalanceMap[_token] = _token.balanceOf(address(this));
    }
}
