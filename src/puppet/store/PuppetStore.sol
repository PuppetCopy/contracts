// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../../shared/Error.sol";
import {TokenRouter} from "./../../shared/TokenRouter.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract PuppetStore is BankStore {
    mapping(IERC20 token => mapping(address user => uint)) public userBalanceMap;

    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}

    function getUserBalance(IERC20 _token, address _account) external view returns (uint) {
        return userBalanceMap[_token][_account];
    }

    function getBalanceList(IERC20 _token, address[] calldata _userList) external view returns (uint[] memory) {
        uint _accountListLength = _userList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_userList[i]];
        }
        return _balanceList;
    }

    function setUserBalance(IERC20 _token, address _account, uint _value) external auth {
        userBalanceMap[_token][_account] = _value;
    }

    function setBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _balanceList
    ) external auth {
        uint _accountListLength = _accountList.length;
        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }
}
