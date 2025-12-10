// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Error} from "../utils/Error.sol";
import {Access} from "./../utils/auth/Access.sol";

/**
 * @notice A minimal proxy contract that enables identity-preserving delegated execution
 * @dev Designed for EIP-1167 minimal proxies. Only authorized contracts can execute calls.
 */
contract AllocationAccount {
    Access internal immutable store;

    /**
     * @notice Initialize the implementation contract with store reference
     */
    constructor(
        Access _store
    ) {
        store = _store;
    }

    /**
     * @notice Execute a call to target contract with optional ETH value
     * @dev Requires authorization via store.canCall(). Calling contracts handle validation and logging.
     */
    function execute(
        address _contract,
        bytes calldata _data,
        uint _ethAmount,
        uint _gasLimit
    ) public payable returns (bool _success, bytes memory _returnData) {
        if (!store.canCall(msg.sender)) revert Error.AllocationAccount__UnauthorizedOperator();
        if (address(this).balance < _ethAmount) revert Error.AllocationAccount__InsufficientBalance();
        if (_gasLimit == 0) revert("Gas limit must be greater than 0");

        return _contract.call{value: _ethAmount, gas: _gasLimit}(_data);
    }

    /**
     * @notice Execute a call to target contract without ETH value
     */
    function execute(
        address _contract,
        bytes calldata _data,
        uint _gasLimit
    ) external returns (bool _success, bytes memory _returnData) {
        return execute(_contract, _data, 0, _gasLimit);
    }
}
