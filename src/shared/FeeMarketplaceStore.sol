// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {TokenRouter} from "./../shared/TokenRouter.sol";
import {BankStore} from "./../utils/BankStore.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

contract FeeMarketplaceStore is BankStore {
    PuppetToken public immutable protocolToken;

    constructor(
        IAuthority _authority,
        TokenRouter _router,
        PuppetToken _protocolToken
    ) BankStore(_authority, _router) {
        protocolToken = _protocolToken;
    }

    function burn(
        uint _amount
    ) external auth {
        protocolToken.burn(_amount);
    }
}
