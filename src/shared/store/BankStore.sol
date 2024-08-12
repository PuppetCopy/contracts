// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {Auth} from "./../../utils/access/Auth.sol";

import {Router} from "../Router.sol";

// @title Bank
// @dev Contract to handle storing and transferring of tokens
abstract contract BankStore is Auth {
    mapping(IERC20 => uint) public tokenBalanceMap;

    Router router;

    constructor(IAuthority _authority, Router _router) Auth(_authority) {
        router = _router;
    }

    function getTokenBalance(IERC20 _token) external view returns (uint) {
        return tokenBalanceMap[_token];
    }

    function recordedTransferIn(IERC20 _token) public returns (uint) {
        return _recordTransferIn(_token);
    }

    function syncTokenBalance(IERC20 _token) external auth {
        tokenBalanceMap[_token] = _token.balanceOf(address(this));
    }

    function _transferOut(IERC20 _token, address _receiver, uint _value) internal {
        _token.transfer(_receiver, _value);
        tokenBalanceMap[_token] -= _value;
    }

    function _transferIn(IERC20 _token, address _depositor, uint _value) internal {
        router.transfer(_token, _depositor, address(this), _value);
        tokenBalanceMap[_token] += _value;
    }

    function _recordTransferIn(IERC20 _token) internal returns (uint) {
        uint prevBalance = tokenBalanceMap[_token];
        uint currentBalance = _syncTokenBalance(_token);

        return currentBalance - prevBalance;
    }

    function _syncTokenBalance(IERC20 _token) internal returns (uint) {
        uint currentBalance = _token.balanceOf(address(this));
        tokenBalanceMap[_token] = currentBalance;
        return currentBalance;
    }
}
