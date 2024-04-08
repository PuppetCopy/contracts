// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {PRBTest} from "@prb/test/src/PRBTest.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/vault/IBasePool.sol";

// import {IDataStore} from "./../src/integrations/utils/interfaces/IDataStore.sol";

import {PositionStore} from "./../src/position/store/PositionStore.sol";

import {Dictator} from "src/utils/Dictator.sol";
import {Router} from "src/utils/Router.sol";
import {IWNT} from "./../src/utils/interfaces/IWNT.sol";

import {Oracle} from "./../src/tokenomics/Oracle.sol";
import {OracleStore} from "src/tokenomics/store/OracleStore.sol";
import {RewardRouter} from "src/RewardRouter.sol";
// import {DataStore} from "src/integrations/utils/DataStore.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {VotingEscrow} from "src/tokenomics/VotingEscrow.sol";
// import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {VeRevenueDistributor} from "src/tokenomics/VeRevenueDistributor.sol";

import {Const} from "script/Const.s.sol";

contract DeployTokenomics is PRBTest {
    uint8 constant TOKEN_ROUTER_ROLE = 0;
    uint8 constant PUPPET_MINTER = 1;
    uint8 constant ORACLE_LOGIC_ROLE = 2;
    uint8 constant REWARD_LOGIC_ROLE = 3;
    uint8 constant ROUTER_ROLE = 4;
    uint8 constant REWARD_DISTRIBUTOR_ROLE = 5;

    function run() public {
        vm.startBroadcast(vm.envUint("GBC_DEPLOYER_PRIVATE_KEY"));
        _deployContracts();
        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        // PositionStore datastore = PositionStore(DeployerEnv.datastore);

        // Dictator dictator = Dictator(DeployerEnv.Dictator);
        // PuppetToken puppetToken = PuppetToken(DeployerEnv.PuppetToken);
        // OracleLogic oracleLogic = OracleLogic(DeployerEnv.OracleLogic);
        // Router router = Router(DeployerEnv.Router);
        // OracleStore priceStore = OracleStore(DeployerEnv.OracleStore);
        // RewardLogic rewardLogic = RewardLogic(DeployerEnv.RewardLogic);
        // VotingEscrow votingEscrow = VotingEscrow(DeployerEnv.VotingEscrow);
        // VeRevenueDistributor revenueDistributor = VeRevenueDistributor(DeployerEnv.VeRevenueDistributor);
        // RewardRouter rewardRouter = RewardRouter(DeployerEnv.RewardRouter);

        // Dictator dictator = new Dictator(DeployerEnv.governance);
        // PuppetToken puppetToken = new PuppetToken(dictator, dictator.owner());
        // dictator.setRoleCapability(PUPPET_MINTER, address(puppetToken), puppetToken.mint.selector, true);

        // Router router = new Router(dictator);
        // dictator.setRoleCapability(TOKEN_ROUTER_ROLE, address(router), router.pluginTransfer.selector, true);

        // OracleLogic oracleLogic = new OracleLogic(dictator);
        // dictator.setRoleCapability(ORACLE_LOGIC_ROLE, address(oracleLogic), oracleLogic.syncTokenPrice.selector, true);

        // IUniswapV3Pool[] memory wntUsdPoolList = new IUniswapV3Pool[](3);

        // wntUsdPoolList[0] = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0); //
        // https://arbiscan.io/address/0xc6962004f452be9203591991d15f6b388e09e8d0
        // wntUsdPoolList[1] = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443); //
        // https://arbiscan.io/address/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        // wntUsdPoolList[2] = IUniswapV3Pool(0x641C00A822e8b671738d32a431a4Fb6074E5c79d); //
        // https://arbiscan.io/address/0x641c00a822e8b671738d32a431a4fb6074e5c79d

        // IBasePoolErc20 lpPool = IBasePoolErc20(DeployerEnv.BasePool);
        // IVault vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

        // oracleLogic.getMedianWntPriceInUsd(wntUsdPoolList, 20);
        // oracleLogic.getPuppetPriceInWnt(vault, lpPool.getPoolId());
        // uint puppetExchangeRateInUsdc = oracleLogic.getPuppetExchangeRateInUsdc(wntUsdPoolList, vault, lpPool.getPoolId(), 20);

        // OracleStore priceStore = new OracleStore(dictator, address(oracleLogic), puppetExchangeRateInUsdc, 1 days);

        // RewardLogic rewardLogic = new RewardLogic(dictator);
        // dictator.setUserRole(address(rewardLogic), PUPPET_MINTER, true);
        // dictator.setUserRole(address(rewardLogic), REWARD_LOGIC_ROLE, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(rewardLogic), rewardLogic.lock.selector, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(rewardLogic), rewardLogic.exit.selector, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(rewardLogic), rewardLogic.claim.selector, true);

        // VotingEscrow votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        // dictator.setUserRole(address(votingEscrow), TRANSFER_TOKEN, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(votingEscrow), votingEscrow.depositFor.selector, true);
        // dictator.setRoleCapability(ROUTER_ROLE, address(votingEscrow), votingEscrow.withdraw.selector, true);
        // dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);

        // VeRevenueDistributor revenueDistributor = new VeRevenueDistributor(dictator, votingEscrow, router, block.timestamp + 1 weeks);
        // dictator.setUserRole(address(revenueDistributor), TRANSFER_TOKEN, true);
        // dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(revenueDistributor), revenueDistributor.claim.selector, true);
        // dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.depositToken.selector, true);

        // RewardRouter rewardRouter = new RewardRouter(
        //     RewardRouter.RewardRouterParams({
        //         dictator: dictator,
        //         puppetToken: puppetToken,
        //         lp: vault,
        //         router: router,
        //         priceStore: priceStore,
        //         votingEscrow: votingEscrow,
        //         wnt: WNT(DeployerEnv.wnt)
        //     }),
        //     RewardRouter.RewardRouterConfigParams({
        //         revenueDistributor: revenueDistributor,
        //         wntUsdPoolList: wntUsdPoolList,
        //         wntUsdTwapInterval: 20,
        //         dataStore: datastore,
        //         rewardLogic: rewardLogic,
        //         oracleLogic: oracleLogic,
        //         dao: dictator.owner(),
        //         revenueInToken: IERC20(DeployerEnv.usdc),
        //         poolId: lpPool.getPoolId(),
        //         lockRate: 6000,
        //         exitRate: 3000,
        //         treasuryLockRate: 667,
        //         treasuryExitRate: 333
        //     })
        // );
        // dictator.setUserRole(address(rewardRouter), ROUTER_ROLE, true);

        // datastore.updateOwnership(DeployerEnv.governance, true);
    }
}
