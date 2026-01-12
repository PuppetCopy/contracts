// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "./BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Withdraw} from "src/withdraw/Withdraw.sol";

contract DeployWithdraw is BaseScript {
    bytes32 constant SALT = bytes32(uint256(1));
    uint256 constant GAS_LIMIT = 200_000;

    function run() public {
        _loadDeployments();
        address dictatorship = _getUniversalAddress("Dictatorship");

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address addr = FACTORY.safeCreate2(
            SALT,
            abi.encodePacked(type(Withdraw).creationCode, abi.encode(dictatorship, Withdraw.Config(ATTESTOR_ADDRESS, GAS_LIMIT)))
        );
        _setUniversalAddress("Withdraw", addr);
        Dictatorship(dictatorship).registerContract(addr);

        vm.stopBroadcast();
    }
}
