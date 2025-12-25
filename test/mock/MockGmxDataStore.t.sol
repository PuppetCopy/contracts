// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";

contract MockGmxDataStore is IGmxReadDataStore {
    mapping(bytes32 => uint) public uintValues;
    mapping(bytes32 => int) public intValues;
    mapping(bytes32 => address) public addressValues;
    mapping(bytes32 => bool) public boolValues;
    mapping(bytes32 => string) public stringValues;
    mapping(bytes32 => bytes32) public bytes32Values;

    function setUint(bytes32 key, uint value) external {
        uintValues[key] = value;
    }

    function getUint(bytes32 key) external view override returns (uint) {
        return uintValues[key];
    }

    function getInt(bytes32 key) external view override returns (int) {
        return intValues[key];
    }

    function getAddress(bytes32 key) external view override returns (address) {
        return addressValues[key];
    }

    function getBool(bytes32 key) external view override returns (bool) {
        return boolValues[key];
    }

    function getString(bytes32 key) external view override returns (string memory) {
        return stringValues[key];
    }

    function getBytes32(bytes32 key) external view override returns (bytes32) {
        return bytes32Values[key];
    }

    function getUintArray(bytes32) external pure override returns (uint[] memory) {
        return new uint[](0);
    }

    function getIntArray(bytes32) external pure override returns (int[] memory) {
        return new int[](0);
    }

    function getAddressArray(bytes32) external pure override returns (address[] memory) {
        return new address[](0);
    }

    function getBoolArray(bytes32) external pure override returns (bool[] memory) {
        return new bool[](0);
    }

    function getStringArray(bytes32) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getBytes32Array(bytes32) external pure override returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function containsBytes32(bytes32, bytes32) external pure override returns (bool) {
        return false;
    }

    function getBytes32Count(bytes32) external pure override returns (uint) {
        return 0;
    }

    function getBytes32ValuesAt(bytes32, uint, uint) external pure override returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function addBytes32(bytes32, bytes32) external pure override {}

    function removeBytes32(bytes32, bytes32) external pure override {}

    function containsAddress(bytes32, address) external pure override returns (bool) {
        return false;
    }

    function getAddressCount(bytes32) external pure override returns (uint) {
        return 0;
    }

    function getAddressValuesAt(bytes32, uint, uint) external pure override returns (address[] memory) {
        return new address[](0);
    }

    function addAddress(bytes32, address) external pure override {}

    function containsUint(bytes32, uint) external pure override returns (bool) {
        return false;
    }

    function getUintCount(bytes32) external pure override returns (uint) {
        return 0;
    }

    function getUintValuesAt(bytes32, uint, uint) external pure override returns (uint[] memory) {
        return new uint[](0);
    }

    function addUint(bytes32, uint) external pure override {}
}
