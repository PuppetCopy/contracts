// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./Router.sol";
import {StoreController} from "./StoreController.sol";

// @title Bank
// @dev Contract to handle storing and transferring of tokens
abstract contract BankStore is StoreController {
    mapping(IERC20 => uint) public tokenBalanceMap;

    Router router;

    constructor(Authority _authority, Router _router, address _initSetter) StoreController(_authority, _initSetter) {
        router = _router;
    }

    function syncTokenBalance(IERC20 _token) external isSetter {
        _syncTokenBalance(_token);
    }

    function recordTransferIn(IERC20 _token) external isSetter {
        _recordTransferIn(_token);
    }

    function transferIn(IERC20 _token, address _user, uint _amount) internal {
        router.transfer(_token, _user, address(this), _amount);
        tokenBalanceMap[_token] += _amount;
    }

    function transferOut(IERC20 _token, address _receiver, uint _amount) internal {
        router.transfer(_token, address(this), _receiver, _amount);
        tokenBalanceMap[_token] -= _amount;
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
