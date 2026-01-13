// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseScript} from "../shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {RouterProxy} from "src/utils/RouterProxy.sol";
import {MasterRouter} from "src/account/MasterRouter.sol";
import {Registry} from "src/account/Registry.sol";
import {Position} from "src/position/Position.sol";

/// @title UpdateMasterRouter
/// @notice Deploys MasterRouter implementation and sets it on RouterProxy
/// @dev Run after DeployMasterBase. Re-run to upgrade MasterRouter with new Registry/Position.
contract UpdateMasterRouter is BaseScript {
    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Registry registry = Registry(_getUniversalAddress("Registry"));
        Position position = Position(_getUniversalAddress("Position"));
        RouterProxy routerProxy = RouterProxy(payable(_getUniversalAddress("MasterRouter")));
        address masterHook = _getUniversalAddress("MasterHook");

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        MasterRouter masterRouter = new MasterRouter(dictatorship, registry, position);
        _setChainAddress("__MasterRouter", address(masterRouter));

        routerProxy.update(address(masterRouter));

        dictatorship.setAccess(routerProxy, masterHook);
        dictatorship.setPermission(registry, registry.createMaster.selector, address(routerProxy));
        dictatorship.setPermission(position, position.processPreCall.selector, address(routerProxy));
        dictatorship.setPermission(position, position.processPostCall.selector, address(routerProxy));

        vm.stopBroadcast();
    }
}
