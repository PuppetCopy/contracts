// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Registry} from "src/account/Registry.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {Position} from "src/position/Position.sol";

import {Const} from "../shared/Const.sol";

contract DeployRegistry is BaseScript {
    bytes32 constant REGISTRY_SALT = bytes32(uint256(1));
    bytes32 constant MASTER_HOOK_SALT = bytes32(uint256(2));

    function run() public {
        _loadDeployments();
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Position position = Position(_getUniversalAddress("Position"));

        bytes32[] memory codeList = new bytes32[](1);
        codeList[0] = Const.latestAccount7579CodeHash;

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address registryAddr = FACTORY.safeCreate2(
            REGISTRY_SALT,
            abi.encodePacked(
                type(Registry).creationCode,
                abi.encode(dictatorship, Registry.Config({
                    masterHook: address(0),
                    account7579CodeList: codeList
                }))
            )
        );
        _setUniversalAddress("Registry", registryAddr);
        Registry registry = Registry(registryAddr);

        address masterHookAddr = FACTORY.safeCreate2(
            MASTER_HOOK_SALT,
            abi.encodePacked(
                type(MasterHook).creationCode,
                abi.encode(position, registryAddr)
            )
        );
        _setUniversalAddress("MasterHook", masterHookAddr);

        registry.setConfig(abi.encode(Registry.Config({
            masterHook: masterHookAddr,
            account7579CodeList: codeList
        })));

        dictatorship.registerContract(registryAddr);
        dictatorship.registerContract(masterHookAddr);
        dictatorship.setPermission(registry, registry.setTokenCap.selector, Const.dao);

        vm.stopBroadcast();
    }
}
