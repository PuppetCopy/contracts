// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "../Router.sol";
import {Access} from "./../../utils/auth/Access.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

// @title Bank
// @dev Contract to handle storing and transferring of tokens
abstract contract BankStore is Access {
    mapping(IERC20 => uint) public tokenBalanceMap;

    Router immutable router;

    constructor(IAuthority _authority, Router _router) Access(_authority) {
        router = _router;
    }

    function getTokenBalance(IERC20 _token) external view returns (uint) {
        return tokenBalanceMap[_token];
    }

    function recordTransferIn(IERC20 _token) public auth returns (uint) {
        uint prevBalance = tokenBalanceMap[_token];
        uint currentBalance = _syncTokenBalance(_token);

        return currentBalance - prevBalance;
    }

    function interTransferIn(IERC20 _token, BankStore _bank, uint _value) public auth {
        _bank.transferOut(_token, address(this), _value);
        tokenBalanceMap[_token] += _value;
    }

    function transferOut(IERC20 _token, address _receiver, uint _value) public auth {
        _token.transfer(_receiver, _value);
        tokenBalanceMap[_token] -= _value;
    }

    function transferIn(IERC20 _token, address _depositor, uint _value) public auth {
        router.transfer(_token, _depositor, address(this), _value);
        tokenBalanceMap[_token] += _value;
    }

    function syncTokenBalance(IERC20 _token) external auth {
        tokenBalanceMap[_token] = _token.balanceOf(address(this));
    }

    function _syncTokenBalance(IERC20 _token) internal returns (uint) {
        uint currentBalance = _token.balanceOf(address(this));
        tokenBalanceMap[_token] = currentBalance;
        return currentBalance;
    }
}
