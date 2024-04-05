// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";

contract CugarStore is StoreController {
    mapping(bytes32 cugarKey => uint) public cugarAmountMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getCugar(bytes32 _key) external view returns (uint) {
        return cugarAmountMap[_key];
    }

    function setCugar(bytes32 _key, uint _ugr) external isSetter {
        cugarAmountMap[_key] = _ugr;
    }

    function increaseCugar(bytes32 _key, uint _ugr) external isSetter {
        cugarAmountMap[_key] += _ugr;
    }

    function resetCugar(bytes32 _key) external isSetter {
        delete cugarAmountMap[_key];
    }

    function getCugarList(bytes32[] calldata _keyList) external view returns (uint[] memory) {
        uint[] memory _revenueList = new uint[](_keyList.length);

        for (uint i = 0; i < _keyList.length; i++) {
            _revenueList[i] = cugarAmountMap[_keyList[i]];
        }

        return _revenueList;
    }

    function setCugarList(bytes32[] calldata _keyList, uint[] calldata _revenueList) external isSetter {
        if (_keyList.length != _revenueList.length) revert CugarStore__InvalidInputLength();

        for (uint i = 0; i < _keyList.length; i++) {
            cugarAmountMap[_keyList[i]] = _revenueList[i];
        }
    }

    function increaseList(bytes32[] calldata _keyList, uint[] calldata _revenueList) external isSetter {
        if (_keyList.length != _revenueList.length) revert CugarStore__InvalidInputLength();

        for (uint i = 0; i < _keyList.length; i++) {
            cugarAmountMap[_keyList[i]] += _revenueList[i];
        }
    }

    function resetCugarList(bytes32[] calldata _keyList) external isSetter {
        for (uint i = 0; i < _keyList.length; i++) {
            delete cugarAmountMap[_keyList[i]];
        }
    }

    error CugarStore__InvalidInputLength();
}
