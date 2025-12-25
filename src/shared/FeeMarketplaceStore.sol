// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {BankStore} from "../utils/BankStore.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

/**
 * @notice Token storage for FeeMarketplace with burn capability
 */
contract FeeMarketplaceStore is BankStore {
    PuppetToken public immutable protocolToken;

    constructor(
        IAuthority _authority,
        PuppetToken _protocolToken
    ) BankStore(_authority) {
        protocolToken = _protocolToken;
    }

    /**
     * @notice Burn protocol tokens held by the store
     */
    function burn(
        uint _amount
    ) external auth {
        IERC20 _token = IERC20(address(protocolToken));
        if (tokenBalanceMap[_token] < _amount) revert Error.BankStore__InsufficientBalance();
        tokenBalanceMap[_token] -= _amount;
        protocolToken.burn(_amount);
    }
}
