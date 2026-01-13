// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Registry} from "src/account/Registry.sol";

contract DeployRegistry is BaseScript {
    bytes32 constant REGISTRY_SALT = bytes32(uint(1));
    bytes32 constant USDC_ID = keccak256("USDC");

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));

        // ERC-7579 account runtime code hashes (keccak256 of deployed bytecode)
        bytes32[] memory codeList = new bytes32[](2);
        codeList[0] = 0x37f47513090b87acd09e20f11f5536ac41e0a4403b6d782f4073e3cebfb263ab; // Nexus
        codeList[1] = 0xaaa52c8cc8a0e3fd27ce756cc6b4e70c51423e9b597b11f32d3e49f8b1fc890d; // Kernel v3.3

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
        registry.setTokenCap(_getChainToken("USDC"), 100e6);

        dictatorship.setPermission(registry, registry.setToken.selector, _dao());
        registry.setToken(USDC_ID, _getChainToken("USDC"));

        vm.stopBroadcast();
    }
}
