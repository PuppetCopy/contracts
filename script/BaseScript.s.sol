// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Script} from "forge-std/src/Script.sol";
import {stdJson} from "forge-std/src/StdJson.sol";

import {Const} from "./Const.sol";

abstract contract BaseScript is Script {
    uint DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address DEPLOYER_ADDRESS = vm.addr(DEPLOYER_PRIVATE_KEY);
    string ADDRESSES = vm.readFile(string.concat(vm.projectRoot(), "/deployments.json"));

    function getDeployedAddress(
        string memory name
    ) internal view returns (address) {
        string memory chainIdStr = vm.toString(block.chainid);
        address addr = stdJson.readAddress(ADDRESSES, string.concat(".", chainIdStr, ".", name));
        require(addr != address(0), string.concat("Deployed address not found: ", name));
        return addr;
    }

    function getNextCreateAddress(
        uint count
    ) public view returns (address) {
        return vm.computeCreateAddress(DEPLOYER_ADDRESS, vm.getNonce(DEPLOYER_ADDRESS) + count);
    }

    function getNextCreateAddress() public view returns (address) {
        return getNextCreateAddress(1);
    }
}
