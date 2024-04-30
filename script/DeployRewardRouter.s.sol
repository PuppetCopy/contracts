// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {PRBTest} from "@prb/test/src/PRBTest.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/vault/IBasePool.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";

import {Oracle} from "src/token/Oracle.sol";
import {OracleStore} from "src/token/store/OracleStore.sol";
import {RewardLogic} from "./../src/token/logic/RewardLogic.sol";
import {RewardStore} from "./../src/token/store/RewardStore.sol";
import {RewardRouter} from "src/token/RewardRouter.sol";
import {PuppetToken} from "src/token/PuppetToken.sol";
import {VotingEscrow} from "src/token/VotingEscrow.sol";

import {Address} from "script/Const.sol";

contract DeployRewardRouter is PRBTest {
    Dictator dictator = Dictator(Address.Dictator);
    PuppetToken puppetToken = PuppetToken(Address.PuppetToken);
    Router router = Router(Address.Router);
    VotingEscrow votingEscrow = VotingEscrow(Address.VotingEscrow);

    function run() public {
        // vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        deployContracts();
        // vm.stopBroadcast();
    }

    function deployContracts() internal {
        IUniswapV3Pool[] memory wntUsdPoolList = new IUniswapV3Pool[](3);

        wntUsdPoolList[0] = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0); // https://arbiscan.io/address/0xc6962004f452be9203591991d15f6b388e09e8d0
        wntUsdPoolList[1] = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443); // https://arbiscan.io/address/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        wntUsdPoolList[2] = IUniswapV3Pool(0x641C00A822e8b671738d32a431a4Fb6074E5c79d); // https://arbiscan.io/address/0x641c00a822e8b671738d32a431a4fb6074e5c79d

        IERC20[] memory secondaryPriceConfigList = new IERC20[](1);
        secondaryPriceConfigList[0] = IERC20(Address.usdc);

        IBasePoolErc20 lpPool = IBasePoolErc20(Address.BasePool);
        IVault vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

        Oracle.SecondaryPriceConfig[] memory exchangePriceSourceList = new Oracle.SecondaryPriceConfig[](1);
        exchangePriceSourceList[0] = Oracle.SecondaryPriceConfig({
            enabled: true, //
            sourceList: wntUsdPoolList,
            twapInterval: 0,
            token1Deicmals: 6
        });

        OracleStore oracleStore = new OracleStore(dictator, 1e18);
        Oracle oracle = new Oracle(
            dictator,
            oracleStore,
            Oracle.CallConfig({token: IERC20(Address.wnt), vault: vault, poolId: lpPool.getPoolId(), updateInterval: 1 days}),
            secondaryPriceConfigList,
            exchangePriceSourceList
        );
        dictator.setAccess(oracleStore, address(oracle));

        RewardStore rewardStore = new RewardStore(dictator, router);
        dictator.setPermission(router, address(rewardStore), router.transfer.selector);
        RewardRouter rewardRouter = new RewardRouter(
            dictator,
            router,
            votingEscrow,
            rewardStore,
            RewardRouter.CallConfig({
                lock: RewardLogic.CallLockConfig({oracle: oracle, puppetToken: puppetToken, rate: 6000}),
                exit: RewardLogic.CallExitConfig({oracle: oracle, puppetToken: puppetToken, rate: 3000})
            })
        );
        dictator.setAccess(rewardStore, address(rewardRouter));

        dictator.setAccess(votingEscrow, address(rewardRouter));
        dictator.setPermission(oracle, address(rewardRouter), oracle.setPrimaryPrice.selector);
        dictator.setPermission(puppetToken, address(rewardRouter), puppetToken.mint.selector);
    }
}

interface IBasePoolErc20 is IBasePool, IERC20 {}
