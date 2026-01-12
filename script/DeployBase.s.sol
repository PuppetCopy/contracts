// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Script} from "forge-std/src/Script.sol";
import {Config} from "forge-std/src/Config.sol";
import {LibVariable} from "forge-std/src/LibVariable.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";

import {Const} from "./Const.sol";

/// @title DeployBase
/// @notice Deploys base tokenomics contracts (PuppetToken, FeeMarketplace, etc.)
contract DeployBase is Script, Config {
    using LibVariable for *;

    function run() public {
        _loadConfig("./deployments.toml", true);

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Dictatorship dictatorship = new Dictatorship(Const.dao);
        config.set("Dictatorship", address(dictatorship));

        PuppetToken puppetToken = new PuppetToken(Const.dao);
        config.set("PuppetToken", address(puppetToken));

        PuppetVoteToken puppetVoteToken = new PuppetVoteToken(dictatorship);
        config.set("PuppetVoteToken", address(puppetVoteToken));

        FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictatorship, puppetToken);
        config.set("FeeMarketplaceStore", address(feeMarketplaceStore));

        FeeMarketplace feeMarketplace = new FeeMarketplace(
            dictatorship,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000, unlockTimeframe: 4 days, askDecayTimeframe: 7 days, askStart: 100e18
            })
        );
        config.set("FeeMarketplace", address(feeMarketplace));

        dictatorship.setAccess(feeMarketplaceStore, address(feeMarketplace));

        ProxyUserRouter proxyUserRouter = new ProxyUserRouter(dictatorship);
        config.set("ProxyUserRouter", address(proxyUserRouter));

        dictatorship.setAccess(proxyUserRouter, Const.dao);

        vm.stopBroadcast();
    }
}
