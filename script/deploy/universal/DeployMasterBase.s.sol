// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Access} from "src/utils/auth/Access.sol";
import {RouterProxy} from "src/utils/RouterProxy.sol";
import {MasterHook} from "src/account/MasterHook.sol";

/// @title DeployMasterBase
/// @notice Deploys RouterProxy and MasterHook (both deterministic via CREATE2)
/// @dev Both contracts get the same address across all chains.
contract DeployMasterBase is BaseScript {
    bytes32 constant ROUTER_PROXY_SALT = keccak256("puppet.MasterRouterProxy");
    bytes32 constant MASTER_HOOK_SALT = keccak256("puppet.MasterHook");

    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address routerProxyAddr = FACTORY.safeCreate2(
            ROUTER_PROXY_SALT,
            abi.encodePacked(type(RouterProxy).creationCode, abi.encode(dictatorship))
        );
        _setUniversalAddress("MasterRouter", routerProxyAddr);

        address masterHookAddr = FACTORY.safeCreate2(
            MASTER_HOOK_SALT,
            abi.encodePacked(type(MasterHook).creationCode, abi.encode(routerProxyAddr))
        );
        _setUniversalAddress("MasterHook", masterHookAddr);

        dictatorship.registerContract(routerProxyAddr);
        dictatorship.setAccess(Access(routerProxyAddr), DEPLOYER_ADDRESS);

        vm.stopBroadcast();
    }
}
