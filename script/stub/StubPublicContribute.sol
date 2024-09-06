// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";

contract StubPublicContribute {
    ContributeStore public store = ContributeStore(0xD8f35E3F2F58579d0AFC937913539c06932Ca13D);

    function contribute(IERC20 _token, uint _amount) public {
        store.contribute(_token, msg.sender, msg.sender, _amount);
    }
}
