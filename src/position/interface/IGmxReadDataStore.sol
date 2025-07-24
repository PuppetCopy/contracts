// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IGmxReadDataStore
 * @dev Interface for reading data from the GMX data store.
 */
interface IGmxReadDataStore {
    // Read functions for basic types
    function getUint(
        bytes32 key
    ) external view returns (uint);
    function getInt(
        bytes32 key
    ) external view returns (int);
    function getAddress(
        bytes32 key
    ) external view returns (address);
    function getBool(
        bytes32 key
    ) external view returns (bool);
    function getString(
        bytes32 key
    ) external view returns (string memory);
    function getBytes32(
        bytes32 key
    ) external view returns (bytes32);

    // Read functions for arrays
    function getUintArray(
        bytes32 key
    ) external view returns (uint[] memory);
    function getIntArray(
        bytes32 key
    ) external view returns (int[] memory);
    function getAddressArray(
        bytes32 key
    ) external view returns (address[] memory);
    function getBoolArray(
        bytes32 key
    ) external view returns (bool[] memory);
    function getStringArray(
        bytes32 key
    ) external view returns (string[] memory);
    function getBytes32Array(
        bytes32 key
    ) external view returns (bytes32[] memory);

    // Set functions for bytes32
    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool);
    function getBytes32Count(
        bytes32 setKey
    ) external view returns (uint);
    function getBytes32ValuesAt(bytes32 setKey, uint start, uint end) external view returns (bytes32[] memory);
    function addBytes32(bytes32 setKey, bytes32 value) external;
    function removeBytes32(bytes32 setKey, bytes32 value) external;

    // Set functions for addresses
    function containsAddress(bytes32 setKey, address value) external view returns (bool);
    function getAddressCount(
        bytes32 setKey
    ) external view returns (uint);
    function getAddressValuesAt(bytes32 setKey, uint start, uint end) external view returns (address[] memory);
    function addAddress(bytes32 setKey, address value) external;

    // Set functions for uint
    function containsUint(bytes32 setKey, uint value) external view returns (bool);
    function getUintCount(
        bytes32 setKey
    ) external view returns (uint);
    function getUintValuesAt(bytes32 setKey, uint start, uint end) external view returns (uint[] memory);
    function addUint(bytes32 setKey, uint value) external;
}
