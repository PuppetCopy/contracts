// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/src/Script.sol";
import {Config} from "forge-std/src/Config.sol";
import {LibVariable} from "forge-std/src/LibVariable.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {GmxStage} from "src/position/stage/GmxStage.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";
import {IUserRouter} from "src/utils/interfaces/IUserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {CoreContract} from "src/utils/CoreContract.sol";

import {Const} from "./Const.sol";

/// @title DeployPosition
/// @notice Deploys core position/allocation contracts with proper permission setup
/// @dev Roles:
///   - ADMIN (DEPLOYER): Contract owner, can setConfig, setCodeHash, setTokenCap, setStage
///   - KEEPER: Settles orders via Position.settleOrders (off-chain service)
///   - ATTESTOR: Signs attestations for share prices (separate key, ideally in HSM)
///   - USERS: Call allocate/withdraw via ProxyUserRouter (masters initiate allocations, puppets withdraw)
contract DeployPosition is Script, Config {
    using LibVariable for *;

    function run() public {
        _loadConfig("./deployments.toml", true);

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address keeperAddress = vm.envOr("KEEPER_ADDRESS", deployerAddress);
        address attestorAddress = vm.envOr("ATTESTOR_ADDRESS", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // =========================================================================
        // Deploy contracts (config.set after each for resume support)
        // =========================================================================

        Dictatorship dictatorship = new Dictatorship(deployerAddress);
        config.set("Dictatorship", address(dictatorship));

        TokenRouter tokenRouter = new TokenRouter(dictatorship, TokenRouter.Config({transferGasLimit: 100_000}));
        config.set("TokenRouter", address(tokenRouter));

        ProxyUserRouter proxyUserRouter = new ProxyUserRouter(dictatorship);
        config.set("ProxyUserRouter", address(proxyUserRouter));

        MasterHook masterHook = new MasterHook(IUserRouter(address(proxyUserRouter)));
        config.set("MasterHook", address(masterHook));

        Position position = new Position(dictatorship);
        config.set("Position", address(position));

        Match matcher = new Match(dictatorship, Match.Config({minThrottlePeriod: 6 hours}));
        config.set("Match", address(matcher));

        Allocate allocate = new Allocate(
            dictatorship,
            Allocate.Config({
                attestor: attestorAddress,
                maxBlockStaleness: 240,
                maxTimestampAge: 60
            })
        );
        config.set("Allocate", address(allocate));

        UserRouter userRouterImpl = new UserRouter(
            dictatorship,
            UserRouter.Config({
                allocation: allocate,
                matcher: matcher,
                position: position,
                tokenRouter: tokenRouter,
                masterHook: address(masterHook)
            })
        );
        config.set("UserRouter", address(userRouterImpl));

        GmxStage gmxStage = new GmxStage(Const.gmxDataStore, Const.gmxExchangeRouter, Const.gmxOrderVault, Const.wnt);
        config.set("GmxStage", address(gmxStage));

        // =========================================================================
        // Register contracts with Dictatorship
        // =========================================================================

        dictatorship.registerContract(address(tokenRouter));
        dictatorship.registerContract(address(proxyUserRouter));
        dictatorship.registerContract(address(position));
        dictatorship.registerContract(address(matcher));
        dictatorship.registerContract(address(allocate));

        // =========================================================================
        // Internal contract-to-contract permissions
        // =========================================================================

        // Position: called by ProxyUserRouter (via MasterHook -> UserRouter)
        dictatorship.setPermission(position, position.processPostCall.selector, address(proxyUserRouter));

        // Match: setFilter/setPolicy called by ProxyUserRouter, recordMatch called by Allocate
        dictatorship.setPermission(matcher, matcher.setFilter.selector, address(proxyUserRouter));
        dictatorship.setPermission(matcher, matcher.setPolicy.selector, address(proxyUserRouter));
        dictatorship.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));

        // TokenRouter: transfer called by Allocate (puppets approve TokenRouter)
        dictatorship.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocate));

        // Allocate: called by ProxyUserRouter
        dictatorship.setPermission(allocate, allocate.createMaster.selector, address(proxyUserRouter));
        dictatorship.setPermission(allocate, allocate.disposeMaster.selector, address(proxyUserRouter));
        dictatorship.setPermission(allocate, allocate.allocate.selector, address(proxyUserRouter));

        // =========================================================================
        // KEEPER permissions (off-chain service that settles orders)
        // =========================================================================

        dictatorship.setPermission(position, position.settleOrders.selector, keeperAddress);

        // =========================================================================
        // ADMIN permissions (deployer - for configuration)
        // =========================================================================

        // Position: setStage (configure venue handlers)
        dictatorship.setPermission(position, position.setStage.selector, deployerAddress);

        // Allocate: setCodeHash, setTokenCap (configure allowed accounts and token caps)
        dictatorship.setPermission(allocate, allocate.setCodeHash.selector, deployerAddress);
        dictatorship.setPermission(allocate, allocate.setTokenCap.selector, deployerAddress);

        // =========================================================================
        // Initial configuration
        // =========================================================================

        // Set GMX handler
        position.setStage(Const.gmxExchangeRouter, IStage(address(gmxStage)));

        // Allow Rhinestone Nexus accounts
        allocate.setCodeHash(Const.latestAccount7579CodeHash, true);

        // Set initial token cap (100 USDC for testing, increase for production)
        allocate.setTokenCap(IERC20(Const.usdc), 100e6);

        // Enable ProxyUserRouter upgrades by admin
        dictatorship.setAccess(proxyUserRouter, deployerAddress);
        proxyUserRouter.update(address(userRouterImpl));

        vm.stopBroadcast();
    }
}
