// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {Position} from "src/position/Position.sol";
import {SubscriptionPolicy} from "src/position/policies/SubscriptionPolicy.sol";
import {GmxVenueValidator} from "src/position/validator/GmxVenueValidator.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Permission} from "src/utils/auth/Permission.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {
    bytes32 constant GMX_VENUE_KEY = keccak256("GMX_V2");

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(DEPLOYER_ADDRESS);
        Position position = new Position(dictatorship);
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({position: position, maxPuppetList: 100, transferOutGasLimit: 200_000})
        );
        SubscriptionPolicy subscriptionPolicy = new SubscriptionPolicy(
            IAuthority(address(dictatorship)),
            abi.encode(SubscriptionPolicy.Config({version: 1}))
        );
        GmxVenueValidator gmxValidator =
            new GmxVenueValidator(Const.gmxDataStore, Const.gmxReader, Const.gmxReferralStorage);

        dictatorship.setPermission(Permission(address(position)), Position.setVenue.selector, DEPLOYER_ADDRESS);
        address[] memory gmxEntrypoints = new address[](1);
        gmxEntrypoints[0] = Const.gmxExchangeRouter;
        position.setVenue(GMX_VENUE_KEY, gmxValidator, gmxEntrypoints);

        dictatorship.setPermission(Permission(address(position)), Position.updatePosition.selector, address(allocation));
        dictatorship.setPermission(Permission(address(allocation)), Allocation.setTokenCap.selector, DEPLOYER_ADDRESS);
        allocation.setTokenCap(IERC20(Const.usdc), 100e6);

        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeAllocate.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeWithdraw.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeOrder.selector, DEPLOYER_ADDRESS);

        vm.stopBroadcast();
    }
}
