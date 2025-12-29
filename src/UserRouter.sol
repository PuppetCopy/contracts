// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Allocation} from "./position/Allocation.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

/**
 * @title UserRouter
 */
contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    /**
     * @notice Register a master subaccount for trading
     * @dev Caller becomes the account owner. Subaccount must have Allocation installed as executor.
     * @param _signer Session signer authorized to sign intents on behalf of owner
     * @param _subaccount The ERC7579 smart account holding collateral
     * @param _token Collateral token for this subaccount
     * @param _subaccountName Unique identifier for this subaccount
     */
    function createMasterSubaccount(
        address _signer,
        IERC7579Account _subaccount,
        IERC20 _token,
        bytes32 _subaccountName
    ) external {
        allocation.createMasterSubaccount(msg.sender, _signer, _subaccount, _token, _subaccountName);
    }
}
