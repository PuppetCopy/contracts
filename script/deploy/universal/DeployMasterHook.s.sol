// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Registry} from "src/account/Registry.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {Position} from "src/position/Position.sol";

contract DeployMasterHook is BaseScript {
    bytes32 constant MASTER_HOOK_SALT = bytes32(uint(1));

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Position position = Position(_getUniversalAddress("Position"));
        Registry registry = Registry(_getUniversalAddress("Registry"));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address masterHookAddr = FACTORY.safeCreate2(
            MASTER_HOOK_SALT,
            abi.encodePacked(type(MasterHook).creationCode, abi.encode(position, registry))
        );
        _setUniversalAddress("MasterHook", masterHookAddr);

        dictatorship.registerContract(masterHookAddr);

        dictatorship.setPermission(registry, registry.createMaster.selector, masterHookAddr);
        dictatorship.setPermission(position, position.processPreCall.selector, masterHookAddr);
        dictatorship.setPermission(position, position.processPostCall.selector, masterHookAddr);

        vm.stopBroadcast();
    }
}
