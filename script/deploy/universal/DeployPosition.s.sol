// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Position} from "src/position/Position.sol";

contract DeployPosition is BaseScript {
    bytes32 constant POSITION_SALT = bytes32(uint(1));

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address positionAddr = FACTORY.safeCreate2(
            POSITION_SALT,
            abi.encodePacked(type(Position).creationCode, abi.encode(dictatorship))
        );
        _setUniversalAddress("Position", positionAddr);

        dictatorship.registerContract(positionAddr);

        Position position = Position(positionAddr);
        dictatorship.setPermission(position, position.setStage.selector, _dao());

        vm.stopBroadcast();
    }
}
