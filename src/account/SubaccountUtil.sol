// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

library SubaccountUtil {
    function getActionKey(address account, address subaccount, bytes32 actionType) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, subaccount, actionType));
    }
}
