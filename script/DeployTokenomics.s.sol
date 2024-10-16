// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";

import {RewardRouter} from "src/RewardRouter.sol";
import {Router} from "src/shared/Router.sol";
import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {RewardStore} from "src/tokenomics/store/RewardStore.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployTokenomics is BaseScript {
    Dictator dictator = Dictator(Address.Dictator);
    PuppetToken puppetToken = PuppetToken(Address.PuppetToken);
    PuppetVoteToken vPuppetToken = PuppetVoteToken(Address.PuppetVoteToken);
    Router router = Router(Address.Router);

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        // deployStores();
        // deployContributeLogic();
        // deployVotingEscrowLogic();
        // deployRewardLogic();

        // deployRewardRouter(
        //     ContributeLogic(Address.ContributeLogic),
        //     RewardLogic(Address.RewardLogic),
        //     VotingEscrowLogic(Address.VotingEscrowLogic)
        // );

        swapContributeLogic(RewardRouter(Address.RewardRouter));
        // swapVotingEscrowLogic(RewardRouter(Address.RewardRouter));
        // swapRewardLogic(RewardRouter(Address.RewardRouter));

        vm.stopBroadcast();
    }

    function deployStores() internal {
        VotingEscrowStore veStore = new VotingEscrowStore(dictator, router);
        ContributeStore contributeStore = new ContributeStore(dictator, router);
        RewardStore rewardStore = new RewardStore(dictator, router);
        dictator.setAccess(contributeStore, address(rewardStore));
        dictator.setPermission(router, router.transfer.selector, address(contributeStore));
        dictator.setPermission(router, router.transfer.selector, address(rewardStore));
        dictator.setPermission(router, router.transfer.selector, address(veStore));

        // dao settings setup
        dictator.setPermission(puppetToken, puppetToken.mintCore.selector, Address.dao);
    }

    function deployContributeLogic() internal returns (ContributeLogic contributeLogic) {
        ContributeStore contributeStore = ContributeStore(Address.ContributeStore);

        contributeLogic = new ContributeLogic(dictator, puppetToken, contributeStore);
        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(contributeLogic));
        dictator.setAccess(contributeStore, address(contributeLogic));

        dictator.setPermission(contributeLogic, contributeLogic.setBuybackQuote.selector, Address.dao);
        contributeLogic.setBuybackQuote(IERC20(Address.wnt), 100e18);
        contributeLogic.setBuybackQuote(IERC20(Address.usdc), 100e18);

        dictator.initContract(contributeLogic, abi.encode(ContributeLogic.Config({baselineEmissionRate: 0.5e30})));
    }

    function deployVotingEscrowLogic() internal returns (VotingEscrowLogic veLogic) {
        VotingEscrowStore veStore = VotingEscrowStore(Address.VotingEscrowStore);
        veLogic = new VotingEscrowLogic(dictator, veStore, puppetToken, vPuppetToken);
        dictator.setAccess(veStore, address(veLogic));
        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.burn.selector, address(veLogic));

        dictator.initContract(veLogic, abi.encode(VotingEscrowLogic.Config({baseMultiplier: 0.3e30})));
    }

    function deployRewardLogic() internal returns (RewardLogic rewardLogic) {
        RewardStore rewardStore = RewardStore(Address.RewardStore);
        ContributeStore contributeStore = ContributeStore(Address.ContributeStore);

        rewardLogic = new RewardLogic(dictator, puppetToken, vPuppetToken, rewardStore);
        dictator.setAccess(rewardStore, address(rewardLogic));

        dictator.initContract(
            rewardLogic,
            abi.encode(RewardLogic.Config({distributionStore: contributeStore, distributionTimeframe: 1 weeks}))
        );
    }

    function swapContributeLogic(
        RewardRouter rewardRouter
    ) internal {
        ContributeLogic contributeLogic = deployContributeLogic();
        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(rewardRouter));

        dictator.initContract(
            rewardRouter,
            abi.encode(
                RewardRouter.Config({
                    contributeLogic: contributeLogic,
                    veLogic: VotingEscrowLogic(Address.VotingEscrowLogic),
                    rewardLogic: RewardLogic(Address.RewardLogic)
                })
            )
        );
    }

    function swapVotingEscrowLogic(
        RewardRouter rewardRouter
    ) internal {
        VotingEscrowLogic veLogic = deployVotingEscrowLogic();
        dictator.setPermission(veLogic, veLogic.lock.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(rewardRouter));

        dictator.initContract(
            rewardRouter,
            abi.encode(
                RewardRouter.Config({
                    veLogic: veLogic,
                    contributeLogic: ContributeLogic(Address.ContributeLogic),
                    rewardLogic: RewardLogic(Address.RewardLogic)
                })
            )
        );
    }

    function swapRewardLogic(
        RewardRouter rewardRouter
    ) internal returns (RewardLogic rewardLogic) {
        rewardLogic = deployRewardLogic();
        dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.distribute.selector, address(rewardRouter));

        dictator.initContract(
            rewardRouter,
            abi.encode(
                RewardRouter.Config({
                    contributeLogic: ContributeLogic(Address.ContributeLogic),
                    veLogic: VotingEscrowLogic(Address.VotingEscrowLogic),
                    rewardLogic: rewardLogic
                })
            )
        );
    }

    function deployRewardRouter(
        ContributeLogic contributeLogic,
        RewardLogic rewardLogic,
        VotingEscrowLogic veLogic
    ) internal returns (RewardRouter rewardRouter) {
        rewardRouter = new RewardRouter(dictator);

        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(rewardRouter));

        dictator.setPermission(veLogic, veLogic.lock.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(rewardRouter));

        dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.distribute.selector, address(rewardRouter));

        dictator.initContract(
            rewardRouter,
            abi.encode(
                RewardRouter.Config({contributeLogic: contributeLogic, rewardLogic: rewardLogic, veLogic: veLogic})
            )
        );
    }
}
