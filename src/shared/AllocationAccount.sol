// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Access} from "./../utils/auth/Access.sol";
import {Error} from "../utils/Error.sol";

/**
 * @title Subaccount
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
        require(store.canCall(msg.sender), Error.Subaccount__UnauthorizedOperator());

        return _contract.call{value: msg.value, gas: gasleft()}(_data);
    }
}
