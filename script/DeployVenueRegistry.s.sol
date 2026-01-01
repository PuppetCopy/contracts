// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {VenueRegistry} from "src/position/VenueRegistry.sol";
import {SubscriptionPolicy} from "src/position/policies/SubscriptionPolicy.sol";
import {GmxVenueValidator} from "src/position/validator/GmxVenueValidator.sol";
import {MasterHook} from "src/hooks/MasterHook.sol";
import {UserRouter} from "src/UserRouter.sol";
import {IUserRouter} from "src/utils/interfaces/IUserRouter.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Permission} from "src/utils/auth/Permission.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployVenueRegistry is BaseScript {
    bytes32 constant GMX_VENUE_KEY = keccak256("GMX_V2");

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(DEPLOYER_ADDRESS);
        VenueRegistry venueRegistry = new VenueRegistry(dictatorship);

        // Deploy Allocation with placeholder masterHook (will update after MasterHook deployment)
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({venueRegistry: venueRegistry, masterHook: address(1), maxPuppetList: 100, transferOutGasLimit: 200_000})
        );

        // Deploy UserRouter and MasterHook
        UserRouter userRouter = new UserRouter(
            dictatorship,
            UserRouter.Config({allocation: allocation, venueRegistry: venueRegistry})
        );
        MasterHook masterHook = new MasterHook(IUserRouter(address(userRouter)));

        // Update Allocation config with actual MasterHook address
        dictatorship.setPermission(Permission(address(allocation)), allocation.setConfig.selector, DEPLOYER_ADDRESS);
        allocation.setConfig(abi.encode(Allocation.Config({
            venueRegistry: venueRegistry,
            masterHook: address(masterHook),
            maxPuppetList: 100,
            transferOutGasLimit: 200_000
        })));

        // Set allowed account code hash (Kernel v3.3 proxy bytecode hash)
        dictatorship.setPermission(Permission(address(allocation)), allocation.setCodeHash.selector, DEPLOYER_ADDRESS);
        allocation.setCodeHash(Const.account7579CodeHash, true);

        SubscriptionPolicy subscriptionPolicy = new SubscriptionPolicy(
            IAuthority(address(dictatorship)),
            abi.encode(SubscriptionPolicy.Config({version: 1}))
        );
        GmxVenueValidator gmxValidator =
            new GmxVenueValidator(Const.gmxDataStore, Const.gmxReader, Const.gmxReferralStorage, Const.gmxRouter);

        dictatorship.setPermission(Permission(address(venueRegistry)), VenueRegistry.setVenue.selector, DEPLOYER_ADDRESS);
        address[] memory gmxEntrypoints = new address[](2);
        gmxEntrypoints[0] = Const.gmxExchangeRouter;
        gmxEntrypoints[1] = Const.usdc;
        venueRegistry.setVenue(GMX_VENUE_KEY, gmxValidator, gmxEntrypoints);

        dictatorship.setPermission(Permission(address(venueRegistry)), VenueRegistry.updatePosition.selector, address(allocation));
        dictatorship.setPermission(Permission(address(allocation)), Allocation.setTokenCap.selector, DEPLOYER_ADDRESS);
        allocation.setTokenCap(IERC20(Const.usdc), 100e6);

        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeAllocate.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeWithdraw.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(Permission(address(allocation)), Allocation.executeOrder.selector, DEPLOYER_ADDRESS);

        // Permission for UserRouter to call registerMasterSubaccount
        dictatorship.setPermission(Permission(address(allocation)), allocation.registerMasterSubaccount.selector, address(userRouter));

        vm.stopBroadcast();
    }
}
