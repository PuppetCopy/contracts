// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script} from "forge-std/src/Script.sol";

import {Address} from "./Const.sol";

abstract contract BaseScript is Script {
    address DEPLOYER_ADDRESS = vm.envAddress("DEPLOYER_ADDRESS");

    function getNextCreateAddress() public view returns (address) {
        return vm.computeCreateAddress(DEPLOYER_ADDRESS, vm.getNonce(DEPLOYER_ADDRESS) + 1);
    }
}
