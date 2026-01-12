// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "./BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";

contract DeployGovernance is BaseScript {
    bytes32 constant SALT = bytes32(uint256(1));

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address addr = FACTORY.safeCreate2(
            SALT,
            abi.encodePacked(type(Dictatorship).creationCode, abi.encode(DEPLOYER_ADDRESS))
        );
        _setUniversalAddress("Dictatorship", addr);

        vm.stopBroadcast();
    }
}
