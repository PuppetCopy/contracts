// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Error} from "../utils/Error.sol";
import {Access} from "./../utils/auth/Access.sol";

/**
 * @title AllocationAccount
 * @author Puppet Protocol
 * @notice A minimal proxy contract that enables identity-preserving delegated execution
 * @dev This contract has been directed to work with EIP-1167 minimal proxies.
 */
contract AllocationAccount {
    Access internal immutable store;

    /**
     * @notice Constructor for the implementation contract only
     * @dev This is only used for the implementation contract and not for proxies
     */
    constructor(
        Access _store
    ) {
        store = _store;
    }

    /**
     * @notice Executes a call to a target contract if the sender is authorized
     * @dev This function only verifies that the caller has permission via store.canCall().
     * All additional security checks, input validation, and event logging must be
     * implemented by the authorized contracts themselves.
     * @param _contract Target contract to call
     * @param _data The calldata to send to the target contract
     * @return _success Whether the call was successful
     * @return _returnData The data returned from the call
     */
    function execute(
        address _contract,
        bytes calldata _data
    ) external payable returns (bool _success, bytes memory _returnData) {
        require(store.canCall(msg.sender), Error.AllocationAccount__UnauthorizedOperator());

        return _contract.call{value: msg.value, gas: gasleft()}(_data);
    }

    function recoverETH(address payable _to, uint _amount) external returns (bool _success, bytes memory _returnData) {
        require(store.canCall(msg.sender), Error.AllocationAccount__UnauthorizedOperator());
        require(_amount <= address(this).balance, Error.AllocationAccount__InsufficientBalance());

        return _to.call{value: _amount}("");
    }
}
