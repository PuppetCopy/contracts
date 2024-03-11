// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {PositionStore} from "../store/PositionStore.sol";

contract TraderSubAccount is Proxy {
    PositionStore store;
    address private _currentImplementation;
    address public trader;

    constructor(PositionStore _store, address _trader) {
        store = _store;
        trader = _trader;
    }

    function _implementation() internal view override returns (address) {
        return store.positionLogicImplementation();
    }

    // Add a receive function to handle plain ether transfers
    receive() external payable {
        // If there's no function selector (i.e., no data), we simply delegate the call to the implementation.
        // This requires the implementation to have a receive function.
        _fallback();
    }
}
