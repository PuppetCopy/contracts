// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Registry} from "src/account/Registry.sol";

contract DeployRegistry is BaseScript {
    bytes32 constant REGISTRY_SALT = bytes32(uint(1));

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));

        bytes32[] memory codeList = new bytes32[](1);
        codeList[0] = _latestAccount7579CodeHash();

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address registryAddr = FACTORY.safeCreate2(
            REGISTRY_SALT,
            abi.encodePacked(
                type(Registry).creationCode, abi.encode(dictatorship, Registry.Config({account7579CodeList: codeList}))
            )
        );
        _setUniversalAddress("Registry", registryAddr);

        dictatorship.registerContract(registryAddr);

        Registry registry = Registry(registryAddr);
        dictatorship.setPermission(registry, registry.setTokenCap.selector, _dao());

        vm.stopBroadcast();
    }
}
