// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Const} from "../shared/Const.sol";

contract DeployDictatorship is BaseScript {
    bytes32 constant DICTATORSHIP_SALT = bytes32(uint256(1));

    function run() public {
        _loadDeployments();

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address dictatorshipAddr = FACTORY.safeCreate2(
            DICTATORSHIP_SALT,
            abi.encodePacked(
                type(Dictatorship).creationCode,
                abi.encode(Const.dao)
            )
        );
        _setUniversalAddress("Dictatorship", dictatorshipAddr);

        vm.stopBroadcast();
    }
}
