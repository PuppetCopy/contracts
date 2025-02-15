// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccess} from "../utils/interfaces/IAccess.sol";
import {Error} from "./Error.sol";

contract Subaccount {
    IAccess store;
    address public account;

    constructor(IAccess _store, address _account) {
        store = _store;
        account = _account;
    }

    function execute(
        address _contract,
        bytes calldata _data
    ) external payable returns (bool _success, bytes memory _returnData) {
        require(store.canCall(msg.sender), Error.Subaccount__UnauthorizedOperator());

        return _contract.call{value: msg.value, gas: gasleft()}(_data);
    }
}
