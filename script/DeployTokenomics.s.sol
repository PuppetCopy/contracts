// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.28;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {TokenomicsRouter} from "src/TokenomicsRouter.sol";
// import {Dictatorship} from "src/shared/Dictatorship.sol";
// import {TokenRouter} from "src/shared/TokenRouter.sol";
// import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
// import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
// import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
// import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
// import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
// import {ContributeStore} from "src/tokenomics/ContributeStore.sol";
// import {RewardStore} from "src/tokenomics/RewardStore.sol";
// import {VotingEscrowStore} from "src/tokenomics/VotingEscrowStore.sol";

// import {BaseScript} from "./BaseScript.s.sol";
// import {Address} from "./Const.sol";

// contract DeployTokenomics is BaseScript {
//     Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
//     PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
//     PuppetVoteToken puppetVoteToken = PuppetVoteToken(getDeployedAddress("PuppetVoteToken"));
//     Router router = Router(getDeployedAddress("Router"));

//     function run() public {
//         vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
//         deployContracts();
//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         VotingEscrowStore veStore = new VotingEscrowStore(dictator, router);
//         ContributeStore contributeStore = new ContributeStore(dictator, router);
//         RewardStore rewardStore = new RewardStore(dictator, router);
//         dictator.setAccess(contributeStore, address(rewardStore));
//         dictator.setPermission(router, router.transfer.selector, address(contributeStore));
//         dictator.setPermission(router, router.transfer.selector, address(rewardStore));
//         dictator.setPermission(router, router.transfer.selector, address(veStore));

//         // ContributeStore contributeStore = ContributeStore(getDeployedAddress("ContributeStore"));
//         // VotingEscrowStore veStore = VotingEscrowStore(getDeployedAddress("VotingEscrowStore"));
//         // RewardStore rewardStore = RewardStore(getDeployedAddress("RewardStore"));
//         // ContributeStore contributeStore = ContributeStore(getDeployedAddress("ContributeStore"));

//         // dao settings setup
//         dictator.setPermission(puppetToken, puppetToken.mintCore.selector, Address.dao);

//         ContributeLogic contributeLogic = new ContributeLogic(dictator, puppetToken, contributeStore);
//         dictator.setPermission(puppetToken, puppetToken.mint.selector, address(contributeLogic));
//         dictator.setAccess(contributeStore, address(contributeLogic));
//         dictator.setPermission(contributeLogic, contributeLogic.setBuybackQuote.selector, Address.dao);
//         contributeLogic.setBuybackQuote(IERC20(Address.wnt), 100e18);
//         contributeLogic.setBuybackQuote(IERC20(Address.usdc), 100e18);
//         dictator.initContract(contributeLogic, abi.encode(ContributeLogic.Config({baselineEmissionRate: 0.5e30})));

//         VotingEscrowLogic veLogic = new VotingEscrowLogic(dictator, veStore, puppetToken, puppetVoteToken);
//         dictator.setAccess(veStore, address(veLogic));
//         dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));
//         dictator.setPermission(puppetVoteToken, puppetVoteToken.mint.selector, address(veLogic));
//         dictator.setPermission(puppetVoteToken, puppetVoteToken.burn.selector, address(veLogic));
//         dictator.initContract(veLogic, abi.encode(VotingEscrowLogic.Config({baseMultiplier: 0.3e30})));

//         RewardLogic rewardLogic = new RewardLogic(dictator, puppetToken, puppetVoteToken, rewardStore);
//         dictator.setAccess(rewardStore, address(rewardLogic));
//         dictator.initContract(
//             rewardLogic,
//             abi.encode(RewardLogic.Config({distributionStore: contributeStore, distributionTimeframe: 1 weeks}))
//         );

//         TokenomicsRouter tokenomicsRouter = new TokenomicsRouter(dictator);
//         dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(tokenomicsRouter));
//         dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(tokenomicsRouter));
//         dictator.setPermission(veLogic, veLogic.lock.selector, address(tokenomicsRouter));
//         dictator.setPermission(veLogic, veLogic.vest.selector, address(tokenomicsRouter));
//         dictator.setPermission(veLogic, veLogic.claim.selector, address(tokenomicsRouter));
//         dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(tokenomicsRouter));
//         dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(tokenomicsRouter));
//         dictator.setPermission(rewardLogic, rewardLogic.distribute.selector, address(tokenomicsRouter));
//         dictator.initContract(
//             tokenomicsRouter,
//             abi.encode(
//                 TokenomicsRouter.Config({contributeLogic: contributeLogic, rewardLogic: rewardLogic, veLogic: veLogic})
//             )
//         );
//     }
// }
