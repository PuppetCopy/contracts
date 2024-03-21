// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {PositionLogic} from "src/position/PositionLogic.sol";
import {PositionRouter} from "src/PositionRouter.sol";
import {SubaccountLogic} from "src/position/util/SubaccountLogic.sol";
import {SubaccountStore} from "src/position/store/SubaccountStore.sol";
import {PositionStore} from "src/position/store/PositionStore.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "src/position/interface/IGmxDatastore.sol";
import {GmxOrder} from "src/position/logic/GmxOrder.sol";
import {RequestIncreasePosition} from "src/position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "src/position/logic/RequestDecreasePosition.sol";
import {ExecutePosition} from "src/position/logic/ExecutePosition.sol";

import {PuppetRouter, PuppetLogic, PuppetStore} from "src/PuppetRouter.sol";

import {Const} from "script/Const.s.sol";
import {Subaccount} from "./../../src/position/util/Subaccount.sol";

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
        // arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        // vm.selectFork(arbitrumFork);
        // vm.rollFork(192052508);
        // assertEq(vm.activeFork(), arbitrumFork, "arbitrum fork not selected");
        // assertEq(block.number, 192052508);

        super.setUp();

        puppetLogic = new PuppetLogic(dictator);
        dictator.setRoleCapability(PUPPET_LOGIC, address(puppetLogic), puppetLogic.setRule.selector, true);
        dictator.setRoleCapability(PUPPET_LOGIC, address(puppetLogic), puppetLogic.setRouteActivityList.selector, true);
        positionLogic = new PositionLogic(dictator);
        dictator.setRoleCapability(POSITION_LOGIC, address(positionLogic), positionLogic.requestIncreasePosition.selector, true);
        subaccountLogic = new SubaccountLogic(dictator);
        dictator.setRoleCapability(SUBACCOUNT_LOGIC, address(subaccountLogic), subaccountLogic.createSubaccount.selector, true);

        subaccountStore = new SubaccountStore(dictator, address(positionLogic), address(subaccountLogic));
        puppetStore = new PuppetStore(dictator, address(puppetLogic));
        positionStore = new PositionStore(dictator, address(positionLogic));

        puppetRouter = new PuppetRouter(
            dictator,
            puppetLogic,
            PuppetLogic.CallSetRuleConfig({router: router, store: puppetStore, minExpiryDuration: 0, minAllowanceRate: 100, maxAllowanceRate: 5000})
        );

        IGmxDatastore gmxDatastore = IGmxDatastore(Const.gmxDatastore);
        IGmxExchangeRouter gmxExchangeRouter = IGmxExchangeRouter(Const.gmxExchangeRouter);

        positionRouter = new PositionRouter(
            dictator,
            positionLogic,
            RequestIncreasePosition.CallConfig({
                router: router,
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                subaccountLogic: subaccountLogic,
                gmxExchangeRouter: gmxExchangeRouter,
                wnt: IWNT(Const.wnt),
                dao: Const.dao,
                gmxRouter: Const.gmxRouter,
                gmxOrderVault: Const.gmxOrderVault,
                feeReceiver: Const.dao,
                referralCode: Const.referralCode,
                callbackGasLimit: 0,
                puppetLogic: puppetLogic,
                puppetStore: puppetStore,
                limitPuppetList: 100,
                minMatchTokenAmount: 1e6
            }),
            RequestDecreasePosition.CallConfig({
                wnt: IWNT(Const.wnt),
                gmxExchangeRouter: gmxExchangeRouter,
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                gmxOrderVault: Const.gmxOrderVault,
                feeReceiver: Const.dao,
                referralCode: Const.referralCode,
                callbackGasLimit: 0
            }),
            ExecutePosition.CallConfig({
                router: router,
                positionStore: positionStore,
                puppetStore: puppetStore,
                puppetLogic: puppetLogic,
                gmxOrderHandler: Const.gmxOrderHandler
            })
        );

        dictator.setUserRole(address(puppetRouter), PUPPET_LOGIC, true);
        dictator.setUserRole(address(positionRouter), POSITION_LOGIC, true);
        dictator.setUserRole(address(positionLogic), TOKEN_ROUTER_ROLE, true);
        dictator.setUserRole(address(positionLogic), PUPPET_LOGIC, true);
        dictator.setUserRole(address(positionLogic), SUBACCOUNT_LOGIC, true);
    }

    function testIncreaseRequest() public {
        address trader = users.bob;
        address puppet = users.alice;
        address collateralToken = Const.usdc;

        IERC20 usdc = IERC20(Const.usdc);
        _dealERC20(Const.usdc, msg.sender, 1_000e6);
        // usdc.approve(Const.gmxOrderVault, type(uint).max);
        // usdc.approve(Const.gmxExchangeRouter, type(uint).max);
        // IGmxExchangeRouter(Const.gmxExchangeRouter).sendWnt{value: tx.gasprice}(Const.gmxOrderVault, tx.gasprice);
        // IGmxExchangeRouter(Const.gmxExchangeRouter).sendTokens(collateralToken, Const.gmxOrderVault, 1e6);

        // _dealERC20(Const.usdc, msg.sender, 100e6);
        // Subaccount subaccount = new Subaccount(subaccountStore, msg.sender);

        // vm.deal(address(subaccount), 100 ether);

        // (bool _success, bytes memory _returnData) = subaccount.execute{value: tx.gasprice}(
        //     address(Const.gmxExchangeRouter),
        //     abi.encodeWithSelector(IGmxExchangeRouter(Const.gmxExchangeRouter).sendWnt.selector, Const.gmxOrderVault, 1e6)
        // );

        vm.startPrank(puppet);
        _dealERC20(collateralToken, puppet, 100e6);
        IERC20(collateralToken).approve(address(router), 100e6);

        puppetRouter.setRule(
            PuppetStore.Rule({
                trader: trader,
                collateralToken: collateralToken,
                throttleActivity: 0,
                allowance: 100,
                allowanceRate: 100,
                expiry: block.timestamp + 100
            })
        );

        vm.startPrank(trader);
        _dealERC20(collateralToken, trader, 100e6);
        IERC20(collateralToken).approve(address(router), 100e6);

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        positionRouter.request{value: executionFee}(
            GmxOrder.CallParams({
                market: Const.gmxEthUsdcMarket,
                collateralToken: collateralToken,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDelta: 1000e30,
                acceptablePrice: 3320e30,
                triggerPrice: 3420e30,
                puppetList: new address[](0)
            })
        );
    }
}
