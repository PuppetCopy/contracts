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
 * @notice Token storage with internal balance tracking and controlled transfers
 */
abstract contract BankStore is Access {
    mapping(IERC20 => uint) public tokenBalanceMap;

    TokenRouter immutable router;

    constructor(IAuthority _authority, TokenRouter _router) Access(_authority) {
        router = _router;
    }

    /**
     * @notice Get tracked balance for a token
     */
    function getTokenBalance(
        IERC20 _token
    ) external view returns (uint) {
        return tokenBalanceMap[_token];
    }

    /**
     * @notice Account for tokens transferred directly to contract
     * @return Amount of new tokens detected
     */
    function recordTransferIn(
        IERC20 _token
    ) external auth returns (uint) {
        uint _prevBalance = tokenBalanceMap[_token];
        uint _currentBalance = _token.balanceOf(address(this));

        if (_currentBalance == _prevBalance) return 0;

        tokenBalanceMap[_token] = _currentBalance;

        return _currentBalance - _prevBalance;
    }

    /**
     * @notice Transfer tokens out with gas limit
     */
    function transferOut(uint gasLimit, IERC20 _token, address _receiver, uint _value) public auth {
        require(tokenBalanceMap[_token] >= _value, Error.BankStore__InsufficientBalance());

        tokenBalanceMap[_token] -= _value;

        TransferUtils.transferStrictly(gasLimit, _token, _receiver, _value);
    }

    /**
     * @notice Pull tokens from user via router
     */
    function transferIn(IERC20 _token, address _depositor, uint _value) public auth {
        router.transfer(_token, _depositor, address(this), _value);
        tokenBalanceMap[_token] += _value;
    }

    /**
     * @notice Reset tracked balance to actual balance
     */
    function syncTokenBalance(
        IERC20 _token
    ) external auth {
        tokenBalanceMap[_token] = _token.balanceOf(address(this));
    }
}
