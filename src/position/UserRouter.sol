// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Allocation} from "./Allocation.sol";

contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    function createSubaccount(
        address _signer,
        address _subaccount,
        address _token,
        uint _amount
    ) external {
        allocation.createSubaccount(msg.sender, _signer, _subaccount, _token, _amount);
    }
}
