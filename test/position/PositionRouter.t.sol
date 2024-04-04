// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {PositionUtils} from "src/position/util/PositionUtils.sol";

import {SubaccountFactory} from "src/shared/SubaccountFactory.sol";
import {Cugar} from "src/shared/Cugar.sol";
import {CugarStore} from "src/shared/store/CugarStore.sol";
import {SubaccountStore} from "src/shared/store/SubaccountStore.sol";
import {Subaccount} from "src/shared/Subaccount.sol";

import {PuppetLogic} from "src/position/logic/PuppetLogic.sol";
import {PositionRouter} from "src/PositionRouter.sol";

import {PositionStore} from "src/position/store/PositionStore.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "./../../src/position/interface/IGmxOracle.sol";

import {RequestIncreasePosition} from "src/position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "src/position/logic/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "src/position/logic/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "src/position/logic/ExecuteDecreasePosition.sol";

import {PuppetStore} from "src/position/store/PuppetStore.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";

import {Const} from "script/Const.s.sol";

contract PositionRouterTest is BasicSetup {
    uint arbitrumFork;
    uint8 SUBACCOUNT_LOGIC = 2;
    uint8 SET_MATCHING_ACTIVITY = 3;
    uint8 EXECUTE_ORDER = 4;

    SubaccountFactory subaccountFactory;

    SubaccountStore subaccountStore;
    PuppetStore puppetStore;
    PositionStore positionStore;

    PuppetRouter puppetRouter;
    PositionRouter positionRouter;
    IGmxExchangeRouter gmxExchangeRouter;
    CugarStore cugarStore;
    Cugar cugar;

    PositionRouter.CallConfig callConfig;

    function setUp() public override {
        // arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        // vm.selectFork(arbitrumFork);
        // vm.rollFork(192052508);
        // assertEq(vm.activeFork(), arbitrumFork, "arbitrum fork not selected");
        // assertEq(block.number, 192052508);

        super.setUp();

        subaccountFactory = new SubaccountFactory(dictator);
        dictator.setRoleCapability(SUBACCOUNT_LOGIC, address(subaccountFactory), subaccountFactory.createSubaccount.selector, true);

        address positionRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 5);
        address puppetRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 4);

        subaccountStore = new SubaccountStore(dictator, positionRouterAddress, address(subaccountFactory));
        puppetStore = new PuppetStore(dictator, puppetRouterAddress);
        positionStore = new PositionStore(dictator, positionRouterAddress);

        cugar = new Cugar(dictator);
        cugarStore = new CugarStore(dictator, address(cugar));

        puppetRouter = new PuppetRouter(
            dictator,
            PuppetRouter.CallConfig({
                setRule: PuppetLogic.CallSetRuleConfig({
                    router: router,
                    // positionRouterAddress: positionRouterAddress,
                    store: puppetStore,
                    minExpiryDuration: 0,
                    minAllowanceRate: 100,
                    maxAllowanceRate: 5000
                }),
                createSubaccount: PuppetLogic.CallCreateSubaccountConfig({factory: subaccountFactory, store: subaccountStore}),
                setBalance: PuppetLogic.CallSetBalanceConfig({router: router, store: puppetStore, positionRouterAddress: positionRouterAddress})
            })
        );
        dictator.setRoleCapability(ADMIN_ROLE, address(puppetRouter), puppetRouter.setTokenAllowanceCap.selector, true);
        dictator.setRoleCapability(SET_MATCHING_ACTIVITY, address(puppetRouter), puppetRouter.setBalanceAndActivityList.selector, true);

        // routerConfig = Router.CallConfig({
        //     positionStore: positionStore,
        //     gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
        //     puppetStore: puppetStore,
        //     subaccountStore: subaccountStore,
        //     subaccountFactory: subaccountFactory,
        //     positionRouterAddress: positionRouterAddress,
        //     gmxOrderVault: Const.gmxOrderVault,
        //     referralCode: Const.referralCode,
        //     callbackGasLimit: 2_000_000,
        //     tokenTransferGasLimit: 200_000
        // });

        callConfig = PositionRouter.CallConfig({
            increase: RequestIncreasePosition.CallConfig({
                wnt: wnt,
                router: router,
                positionStore: positionStore,
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxOracle: IGmxOracle(Const.gmxOracle),
                subaccountStore: subaccountStore,
                subaccountFactory: subaccountFactory,
                positionRouterAddress: positionRouterAddress,
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                callbackGasLimit: 2_000_000,
                puppetStore: puppetStore,
                puppetRouter: puppetRouter,
                limitPuppetList: 100,
                minimumMatchAmount: 100e30,
                tokenTransferGasLimit: 200_000
            }),
            decrease: RequestDecreasePosition.CallConfig({
                wnt: IWNT(Const.wnt),
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                positionRouterAddress: positionRouterAddress,
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                callbackGasLimit: 2_000_000,
                tokenTransferGasLimit: 200_000
            }),
            executeIncrease: ExecuteIncreasePosition.CallConfig({
                positionStore: positionStore, //
                gmxOrderHandler: Const.gmxOrderHandler
            }),
            executeDecrease: ExecuteDecreasePosition.CallConfig({
                router: router,
                positionStore: positionStore,
                puppetStore: puppetStore,
                cugarStore: cugarStore,
                cugar: cugar,
                positionRouterAddress: positionRouterAddress,
                gmxOrderHandler: Const.gmxOrderHandler,
                tokenTransferGasLimit: 200_000,
                performanceFeeRate: 0.1e30, // 10%
                traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
            })
        });

        positionRouter = new PositionRouter(dictator, callConfig);
        dictator.setRoleCapability(EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderExecution.selector, true);
        dictator.setRoleCapability(EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderCancellation.selector, true);
        dictator.setRoleCapability(EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderFrozen.selector, true);

        dictator.setUserRole(address(positionRouter), TRANSFER_TOKEN_ROLE, true);
        dictator.setUserRole(address(positionRouter), SUBACCOUNT_LOGIC, true);
        dictator.setUserRole(address(positionRouter), SET_MATCHING_ACTIVITY, true);
        dictator.setUserRole(address(positionRouter), SET_MATCHING_ACTIVITY, true);

        puppetRouter.setTokenAllowanceCap(wnt, 100e30);
        puppetRouter.setTokenAllowanceCap(usdc, 100e30);
    }

    function testIncreaseRequest() public {
        address puppet = users.alice;
        address trader = users.bob;

        IERC20 collateralToken = usdc;
        // _dealERC20(Const.usdc, msg.sender, 1_000e6);
        // usdc.approve(Const.gmxOrderVault, type(uint).max);
        // usdc.approve(Const.gmxExchangeRouter, type(uint).max);
        // IGmxExchangeRouter(Const.gmxExchangeRouter).sendWnt{value: tx.gasprice}(Const.gmxOrderVault, tx.gasprice);
        // IGdmxExchangeRouter(Const.gmxExchangeRouter).sendTokens(collateralToken, Const.gmxOrderVault, 1e6);

        // _dealERC20(Const.usdc, msg.sender, 100e6);
        // Subaccount subaccount = new Subaccount(subaccountStore, msg.sender);

        // vm.deal(address(subaccount), 100 ether);

        // (bool _success, bytes memory _returnData) = subaccount.execute{value: tx.gasprice}(
        //     address(Const.gmxExchangeRouter),
        //     abi.encodeWithSelector(IGmxExchangeRouter(Const.gmxExchangeRouter).sendWnt.selector, Const.gmxOrderVault, 1e6)
        // );

        vm.startPrank(puppet);
        _dealERC20(address(collateralToken), puppet, 100e6);
        IERC20(collateralToken).approve(address(router), 100e6);

        puppetRouter.deposit(collateralToken, 100e6);

        puppetRouter.setRule(
            collateralToken, //
            trader,
            PuppetStore.Rule({throttleActivity: 0, allowanceRate: 100, expiry: block.timestamp + 28 days})
        );

        vm.startPrank(trader);
        _dealERC20(address(collateralToken), trader, 100e6);
        collateralToken.approve(address(router), 100e6);

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = new address[](3);
        puppetList[0] = users.bob;
        puppetList[1] = users.yossi;
        puppetList[2] = puppet;

        callConfig.increase.gmxOracle.getStablePrice(Const.gmxDatastore, address(collateralToken));
        callConfig.increase.gmxOracle.getStablePrice(Const.gmxDatastore, Const.wnt);

        positionRouter.requestIncrease{value: executionFee}(
            PositionUtils.TraderCallParams({
                account: trader,
                market: Const.gmxEthUsdcMarket,
                collateralToken: collateralToken,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDelta: 1000e30,
                acceptablePrice: 3320e12,
                triggerPrice: 3420e6
            }),
            puppetList
        );
    }
}
