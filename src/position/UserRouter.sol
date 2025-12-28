// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {Allocation} from "./Allocation.sol";

contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    function createSubaccount(
        address _signer,
        IERC7579Account _subaccount,
        IERC20 _token,
        uint _amount
    ) external {
        allocation.createSubaccount(msg.sender, _signer, _subaccount, _token, _amount);
    }
}
