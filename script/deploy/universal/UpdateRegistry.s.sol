// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Registry} from "src/account/Registry.sol";

/// @title UpdateRegistry
/// @notice Updates Registry config with new account code hashes
/// @dev Run this to add new supported 7579 account implementations
contract UpdateRegistry is BaseScript {
    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Registry registry = Registry(_getUniversalAddress("Registry"));

        // ERC-7579 account runtime code hashes (keccak256 of deployed bytecode)
        bytes32[] memory codeList = new bytes32[](2);
        codeList[0] = 0x37f47513090b87acd09e20f11f5536ac41e0a4403b6d782f4073e3cebfb263ab; // Nexus
        codeList[1] = 0xaaa52c8cc8a0e3fd27ce756cc6b4e70c51423e9b597b11f32d3e49f8b1fc890d; // Kernel v3.3

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        dictatorship.setConfig(registry, abi.encode(Registry.Config({account7579CodeList: codeList})));

        vm.stopBroadcast();
    }
}
