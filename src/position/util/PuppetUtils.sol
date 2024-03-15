// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Router} from "./../../utils/Router.sol";
import {Dictator} from "./../../utils/Dictator.sol";
import {PuppetLogic} from "./../PuppetLogic.sol";
import {PuppetStore} from "./../store/PuppetStore.sol";
import {WNT} from "./../../utils/WNT.sol";

library PuppetUtils {


    function getRuleKey(address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader));
    }
}