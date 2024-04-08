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

    function transferOut(IERC20 _token, address _receiver, uint _amount) internal isSetter {
        if (_receiver == address(this)) {
            revert Bank__SelfTransferNotSupported(_receiver);
        }

        router.transfer(_token, address(this), _receiver, _amount);

        tokenBalanceMap[_token] = _token.balanceOf(address(this));
    }

    error Bank__SelfTransferNotSupported(address receiver);
}
