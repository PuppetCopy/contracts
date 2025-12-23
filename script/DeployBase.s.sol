// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {UserRouterProxy} from "src/utils/UserRouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployBase is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(Const.dao);
        PuppetToken puppetToken = new PuppetToken(Const.dao);
        PuppetVoteToken puppetVoteToken = new PuppetVoteToken(dictatorship);

        FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictatorship, puppetToken);
        FeeMarketplace feeMarketplace = new FeeMarketplace(
            dictatorship,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000, unlockTimeframe: 4 days, askDecayTimeframe: 7 days, askStart: 100e18
            })
        );
        dictatorship.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictatorship.registerContract(feeMarketplace);

        UserRouterProxy userRouterProxy = new UserRouterProxy(dictatorship);
        dictatorship.setAccess(userRouterProxy, Const.dao);

        vm.stopBroadcast();
    }
}
