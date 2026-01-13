// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {stdToml} from "forge-std/src/StdToml.sol";

import {BaseScript} from "./shared/BaseScript.s.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {GmxStage} from "src/position/stage/GmxStage.sol";
import {Registry} from "src/account/Registry.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";

contract DeployChain is BaseScript {
    using stdToml for string;

    function run() public {
        address keeperAddress = vm.envOr("KEEPER_ADDRESS", DEPLOYER_ADDRESS);

        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Position position = Position(_getUniversalAddress("Position"));
        Registry registry = Registry(_getUniversalAddress("Registry"));
        IERC20 usdc = _getChainToken("USDC");

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        TokenRouter tokenRouter = new TokenRouter(dictatorship, TokenRouter.Config({transferGasLimit: 100_000}));
        _setChainAddress("TokenRouter", address(tokenRouter));

        ProxyUserRouter proxyUserRouter = new ProxyUserRouter(dictatorship);
        _setChainAddress("ProxyUserRouter", address(proxyUserRouter));

        Match matcher = new Match(dictatorship, Match.Config({minThrottlePeriod: 6 hours}));
        _setChainAddress("Match", address(matcher));

        Allocate allocate = new Allocate(
            dictatorship,
            Allocate.Config({
                attestor: ATTESTOR_ADDRESS,
                maxBlockStaleness: 240,
                maxTimestampAge: 60
            })
        );
        _setChainAddress("Allocate", address(allocate));

        UserRouter userRouterImpl = new UserRouter(
            dictatorship,
            UserRouter.Config({
                allocation: allocate,
                matcher: matcher,
                tokenRouter: tokenRouter,
                registry: registry
            })
        );
        _setChainAddress("UserRouter", address(userRouterImpl));

        address gmxExchangeRouter = _const.readAddress(".gmx.exchangeRouter");
        address gmxRouter = _const.readAddress(".gmx.router");

        GmxStage gmxStage = new GmxStage(
            _const.readAddress(".gmx.dataStore"),
            gmxExchangeRouter,
            gmxRouter,
            _const.readAddress(".gmx.orderVault"),
            _getChainToken("WETH")
        );
        _setChainAddress("GmxStage", address(gmxStage));
        // Register exchangeRouter for order/multicall validation
        position.setStage(gmxExchangeRouter, IStage(address(gmxStage)));
        // Register router for approve spender validation (Position extracts spender from approve calls)
        position.setStage(gmxRouter, IStage(address(gmxStage)));

        dictatorship.registerContract(address(tokenRouter));
        dictatorship.registerContract(address(proxyUserRouter));
        dictatorship.registerContract(address(matcher));
        dictatorship.registerContract(address(allocate));

        dictatorship.setPermission(matcher, matcher.setFilter.selector, address(proxyUserRouter));
        dictatorship.setPermission(matcher, matcher.setPolicy.selector, address(proxyUserRouter));
        dictatorship.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));
        dictatorship.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocate));
        dictatorship.setPermission(allocate, allocate.allocate.selector, address(proxyUserRouter));

        dictatorship.setAccess(proxyUserRouter, DEPLOYER_ADDRESS);
        proxyUserRouter.update(address(userRouterImpl));

        vm.stopBroadcast();
    }
}
