// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Withdraw} from "src/withdraw/Withdraw.sol";

contract DeployWithdraw is BaseScript {
    bytes32 constant SALT = bytes32(uint256(1));
    uint256 constant GAS_LIMIT = 200_000;
    uint256 constant MAX_BLOCK_STALENESS = 60;
    uint256 constant MAX_TIMESTAMP_AGE = 120;

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address addr = FACTORY.safeCreate2(
            SALT,
            abi.encodePacked(
                type(Withdraw).creationCode,
                abi.encode(dictatorship, Withdraw.Config({
                    attestor: ATTESTOR_ADDRESS,
                    gasLimit: GAS_LIMIT,
                    maxBlockStaleness: MAX_BLOCK_STALENESS,
                    maxTimestampAge: MAX_TIMESTAMP_AGE
                }))
            )
        );
        _setUniversalAddress("Withdraw", addr);

        dictatorship.registerContract(addr);

        vm.stopBroadcast();
    }
}
