// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Script} from "forge-std/src/Script.sol";

import {Address} from "./Const.sol";

abstract contract BaseScript is Script {
    address DEPLOYER_ADDRESS = vm.envAddress("DEPLOYER_ADDRESS");
    uint DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
}
