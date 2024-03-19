// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {PositionLogic} from "src/position/PositionLogic.sol";
import {
    SubaccountLogic,
    PositionRouter,
    IGmxExchangeRouter,
    IGmxDatastore,
    IERC20,
    Router,
    PositionStore,
    SubaccountStore,
    Subaccount
} from "src/PositionRouter.sol";

import {PuppetRouter, PuppetLogic, PuppetStore} from "src/PuppetRouter.sol";

import {Const} from "script/Const.s.sol";

// v3-periphery/contracts/libraries/OracleLibrary.sol

contract PositionRouterTest is BasicSetup {
    uint arbitrumFork;
    uint8 SUBACCOUNT_LOGIC = 2;
    uint8 PUPPET_LOGIC = 3;
    uint8 POSITION_LOGIC = 4;

    PuppetLogic puppetLogic;
    PositionLogic positionLogic;
    SubaccountLogic subaccountLogic;
    SubaccountStore subaccountStore;
    PuppetStore puppetStore;
    PositionStore positionStore;
    PuppetRouter puppetRouter;
    PositionRouter positionRouter;

    function setUp() public override {
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.selectFork(arbitrumFork);
        assertEq(vm.activeFork(), arbitrumFork, "arbitrum fork not selected");

        super.setUp();

        puppetLogic = new PuppetLogic(dictator);
        dictator.setRoleCapability(PUPPET_LOGIC, address(puppetLogic), puppetLogic.setRule.selector, true);
        positionLogic = new PositionLogic(dictator);
        dictator.setRoleCapability(POSITION_LOGIC, address(positionLogic), positionLogic.requestIncreasePosition.selector, true);
        subaccountLogic = new SubaccountLogic(dictator);
        dictator.setRoleCapability(SUBACCOUNT_LOGIC, address(subaccountLogic), subaccountLogic.createSubaccount.selector, true);

        subaccountStore = new SubaccountStore(dictator, address(0x0), address(subaccountLogic));
        puppetStore = new PuppetStore(dictator, address(puppetLogic));
        positionStore = new PositionStore(dictator, address(positionLogic));

        puppetRouter = new PuppetRouter(
            dictator,
            PuppetRouter.PuppetRouterParams({puppetStore: puppetStore, router: router, subaccountStore: subaccountStore}),
            PuppetRouter.PuppetRouterConfig({
                puppetLogic: puppetLogic,
                subaccountLogic: subaccountLogic,
                dao: address(0x0),
                minExpiryDuration: 0,
                minAllowanceRate: 0,
                maxAllowanceRate: 0
            })
        );

        positionRouter = new PositionRouter(
            dictator,
            PositionRouter.PositionRouterParams({
                dictator: dictator,
                router: router,
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                puppetStore: puppetStore
            }),
            PositionRouter.PositionRouterConfig({
                router: router,
                positionLogic: positionLogic,
                puppetLogic: puppetLogic,
                subaccountLogic: subaccountLogic,
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxDatastore: IGmxDatastore(Const.gmxDatastore),
                gmxRouter: address(0x0),
                dao: address(0x0),
                feeReceiver: address(0x0),
                gmxCallbackCaller: Const.gmxOrderHandler,
                limitPuppetList: 100,
                adjustmentFeeFactor: 0,
                minExecutionFee: 0,
                callbackGasLimit: 0,
                minMatchTokenAmount: 10e6, // 10 USDC
                referralCode: bytes32(0x5055505045540000000000000000000000000000000000000000000000000000)
            })
        );

        dictator.setUserRole(address(positionLogic), SUBACCOUNT_LOGIC, true);
        dictator.setUserRole(address(puppetRouter), PUPPET_LOGIC, true);
    }

    function testIncreaseRequest() public {
        vm.startPrank(users.alice);

        address collateralToken = address(0x0);
        address trader = address(0x0);

        PuppetStore.Rule memory rule = PuppetStore.Rule({throttleActivity: 0, allowance: 1000, allowanceRate: 100, expiry: block.timestamp + 1000});

        puppetRouter.setRule(rule, collateralToken, trader);

        // positionRouter.setConfig(
        //     PositionRouter.PositionRouterConfig({
        //         router: router,
        //         positionLogic: positionLogic,
        //         subaccountLogic: SubaccountLogic(address(0x0)),
        //         gmxExchangeRouter: IGmxExchangeRouter(address(0x0)),
        //         gmxDatastore: IGmxDatastore(address(0x0)),
        //         gmxRouter: address(0x0),
        //         dao: address(0x0),
        //         feeReceiver: address(0x0),
        //         gmxCallbackCaller: address(0x0),
        //         limitPuppetList: 0,
        //         adjustmentFeeFactor: 0,
        //         minExecutionFee: 0,
        //         callbackGasLimit: 0,
        //         minMatchTokenAmount: 0,
        //         referralCode: bytes32(0x0)
        //     })
        // );
    }
}
