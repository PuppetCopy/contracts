// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BankStore} from "./../utils/BankStore.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {AllocationAccount} from "./AllocationAccount.sol";
import {TokenRouter} from "./TokenRouter.sol";

contract AllocationStore is BankStore {
    mapping(IERC20 token => mapping(address user => uint)) public userBalanceMap;

    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}

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
