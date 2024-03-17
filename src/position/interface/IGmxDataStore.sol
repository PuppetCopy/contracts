// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

interface IGmxDatastore {
    function getUint(bytes32 key) external view returns (uint);
    function setUint(bytes32 key, uint value) external returns (uint);
    function removeUint(bytes32 key) external;
    function applyDeltaToUint(bytes32 key, int value, string memory errorMessage) external returns (uint);
    function applyDeltaToUint(bytes32 key, uint value) external returns (uint);
    function applyBoundedDeltaToUint(bytes32 key, int value) external returns (uint);
    function incrementUint(bytes32 key, uint value) external returns (uint);
    function decrementUint(bytes32 key, uint value) external returns (uint);
    function getInt(bytes32 key) external view returns (int);
    function setInt(bytes32 key, int value) external returns (int);
    function removeInt(bytes32 key) external;
    function applyDeltaToInt(bytes32 key, int value) external returns (int);
    function incrementInt(bytes32 key, int value) external returns (int);
    function decrementInt(bytes32 key, int value) external returns (int);
    function getAddress(bytes32 key) external view returns (address);
    function setAddress(bytes32 key, address value) external returns (address);
    function removeAddress(bytes32 key) external;
    function getBool(bytes32 key) external view returns (bool);
    function setBool(bytes32 key, bool value) external returns (bool);
    function removeBool(bytes32 key) external;
    function getString(bytes32 key) external view returns (string memory);
    function setString(bytes32 key, string memory value) external returns (string memory);
    function removeString(bytes32 key) external;
    function getBytes32(bytes32 key) external view returns (bytes32);
    function setBytes32(bytes32 key, bytes32 value) external returns (bytes32);
    function removeBytes32(bytes32 key) external;
    function getUintArray(bytes32 key) external view returns (uint[] memory);
    function setUintArray(bytes32 key, uint[] memory value) external;
    function removeUintArray(bytes32 key) external;
    function getIntArray(bytes32 key) external view returns (int[] memory);
    function setIntArray(bytes32 key, int[] memory value) external;
    function removeIntArray(bytes32 key) external;
    function getAddressArray(bytes32 key) external view returns (address[] memory);
    function setAddressArray(bytes32 key, address[] memory value) external;
    function removeAddressArray(bytes32 key) external;
    function getBoolArray(bytes32 key) external view returns (bool[] memory);
    function setBoolArray(bytes32 key, bool[] memory value) external;
    function removeBoolArray(bytes32 key) external;
    function getStringArray(bytes32 key) external view returns (string[] memory);
    function setStringArray(bytes32 key, string[] memory value) external;
    function removeStringArray(bytes32 key) external;
    function getBytes32Array(bytes32 key) external view returns (bytes32[] memory);
    function setBytes32Array(bytes32 key, bytes32[] memory value) external;
    function removeBytes32Array(bytes32 key) external;
    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool);
    function getBytes32Count(bytes32 setKey) external view returns (uint);
    function getBytes32ValuesAt(bytes32 setKey, uint start, uint end) external view returns (bytes32[] memory);
    function addBytes32(bytes32 setKey, bytes32 value) external;
    function removeBytes32(bytes32 setKey, bytes32 value) external;
    function containsAddress(bytes32 setKey, address value) external view returns (bool);
    function getAddressCount(bytes32 setKey) external view returns (uint);
    function getAddressValuesAt(bytes32 setKey, uint start, uint end) external view returns (address[] memory);
    function addAddress(bytes32 setKey, address value) external;
    function removeAddress(bytes32 setKey, address value) external;
    function containsUint(bytes32 setKey, uint value) external view returns (bool);
    function getUintCount(bytes32 setKey) external view returns (uint);
    function getUintValuesAt(bytes32 setKey, uint start, uint end) external view returns (uint[] memory);
    function addUint(bytes32 setKey, uint value) external;
    function removeUint(bytes32 setKey, uint value) external;
}
