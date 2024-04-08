// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";

contract CugarStore is StoreController {
    mapping(bytes32 cugarKey => uint) public cugarAmountMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function get(bytes32 _key) external view returns (uint) {
        return cugarAmountMap[_key];
    }

    function set(bytes32 _key, uint _value) external isSetter {
        cugarAmountMap[_key] = _value;
    }

    function increase(bytes32 _key, uint _amount) external isSetter {
        cugarAmountMap[_key] += _amount;
    }

    function decrease(bytes32 _key, uint _amount) external isSetter {
        cugarAmountMap[_key] -= _amount;
    }

    function getList(bytes32[] calldata _keyList) external view returns (uint[] memory) {
        uint[] memory _revenueList = new uint[](_keyList.length);

        for (uint i = 0; i < _keyList.length; i++) {
            _revenueList[i] = cugarAmountMap[_keyList[i]];
        }

        return _revenueList;
    }

    function setList(bytes32[] calldata _keyList, uint[] calldata _valueList) external isSetter {
        if (_keyList.length != _valueList.length) revert CugarStore__InvalidInputLength();

        for (uint i = 0; i < _keyList.length; i++) {
            cugarAmountMap[_keyList[i]] = _valueList[i];
        }
    }

    function increaseList(bytes32[] calldata _keyList, uint[] calldata _amountList) external isSetter {
        if (_keyList.length != _amountList.length) revert CugarStore__InvalidInputLength();

        for (uint i = 0; i < _keyList.length; i++) {
            cugarAmountMap[_keyList[i]] += _amountList[i];
        }
    }

    function decreaseList(bytes32[] calldata _keyList, uint[] calldata _amountList) external isSetter {
        for (uint i = 0; i < _keyList.length; i++) {
            cugarAmountMap[_keyList[i]] -= _amountList[i];
        }
    }

    error CugarStore__InvalidInputLength();
}
