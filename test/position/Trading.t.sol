// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PositionRouter} from "src/PositionRouter.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";
import {ExecuteDecreasePositionLogic} from "src/position/ExecuteDecreasePositionLogic.sol";
import {ExecuteIncreasePositionLogic} from "src/position/ExecuteIncreasePositionLogic.sol";
import {ExecuteRevertedAdjustmentLogic} from "src/position/ExecuteRevertedAdjustmentLogic.sol";
import {RequestPositionLogic} from "src/position/RequestPositionLogic.sol";
import {SettleLogic} from "src/position/SettleLogic.sol";
import {IGmxDatastore} from "src/position/interface/IGmxDatastore.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";
import {MirrorPositionStore} from "src/position/store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";

import {Address} from "script/Const.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";

contract TradingTest is BasicSetup {
    PuppetStore puppetStore;
    PuppetLogic puppetLogic;
    MirrorPositionStore positionStore;
    ContributeStore contributeStore;
    PuppetRouter puppetRouter;
    PositionRouter positionRouter;
    IGmxExchangeRouter gmxExchangeRouter;
    MockGmxExchangeRouter mockGmxExchangeRouter;

    RequestPositionLogic requestLogic;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        contributeStore = new ContributeStore(dictator, router);

        puppetStore = new PuppetStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(puppetStore));
        positionStore = new MirrorPositionStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(positionStore));

        puppetLogic = new PuppetLogic(dictator, eventEmitter, puppetStore);
        dictator.setAccess(eventEmitter, address(puppetLogic));
        dictator.setAccess(puppetStore, address(puppetLogic));

        positionRouter = new PositionRouter(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(positionRouter));

        puppetRouter = new PuppetRouter(dictator, eventEmitter);
        dictator.setAccess(eventEmitter, address(puppetRouter));

        dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setAllocationRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setAllocationRuleList.selector, address(puppetRouter));

        requestLogic = new RequestPositionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(requestLogic));
        dictator.setAccess(puppetStore, address(requestLogic));
        dictator.setAccess(positionStore, address(requestLogic));

        ExecuteIncreasePositionLogic executeIncreaseLogic =
            new ExecuteIncreasePositionLogic(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(executeIncreaseLogic));
        dictator.setAccess(positionStore, address(executeIncreaseLogic));
        ExecuteDecreasePositionLogic executeDecreaseLogic =
            new ExecuteDecreasePositionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executeDecreaseLogic));
        dictator.setAccess(positionStore, address(executeDecreaseLogic));

        ExecuteRevertedAdjustmentLogic executeRevertedAdjustment =
            new ExecuteRevertedAdjustmentLogic(dictator, eventEmitter);
        dictator.setAccess(eventEmitter, address(executeRevertedAdjustment));

        // config

        dictator.setPermission(puppetLogic, puppetLogic.setConfig.selector, users.owner);
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = wnt;
        tokenAllowanceCapList[1] = usdc;
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        puppetLogic.setConfig(
            PuppetLogic.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 1000,
                maxAllowanceRate: 10000,
                tokenAllowanceList: tokenAllowanceCapList,
                tokenAllowanceAmountList: tokenAllowanceCapAmountList
            })
        );

        dictator.setPermission(requestLogic, requestLogic.setConfig.selector, users.owner);
        requestLogic.setConfig(
            RequestPositionLogic.Config({
                gmxExchangeRouter: mockGmxExchangeRouter,
                gmxDatastore: IGmxDatastore(Address.gmxDatastore),
                callbackHandler: address(positionRouter),
                gmxFundsReciever: address(positionStore),
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000,
                limitPuppetList: 100,
                minimumMatchAmount: 100e30
            })
        );

        SettleLogic settleLogic = new SettleLogic(dictator, eventEmitter, contributeStore, puppetStore);
        dictator.setAccess(eventEmitter, address(executeDecreaseLogic));
        dictator.setAccess(contributeStore, address(executeDecreaseLogic));
        dictator.setAccess(puppetStore, address(executeDecreaseLogic));
        dictator.setPermission(settleLogic, settleLogic.setConfig.selector, Address.dao);
        settleLogic.setConfig(
            SettleLogic.Config({performanceContributionRate: 0.1e30, traderPerformanceContributionShare: 0})
        );

        dictator.setPermission(puppetRouter, puppetRouter.setConfig.selector, users.owner);
        puppetRouter.setConfig(PuppetRouter.Config({logic: puppetLogic}));

        dictator.setPermission(positionRouter, positionRouter.setConfig.selector, users.owner);
        positionRouter.setConfig(
            PositionRouter.Config({
                settleLogic: settleLogic,
                executeIncrease: executeIncreaseLogic,
                executeDecrease: executeDecreaseLogic,
                executeRevertedAdjustment: executeRevertedAdjustment
            })
        );

        dictator.setPermission(positionRouter, positionRouter.afterOrderExecution.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderCancellation.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderFrozen.selector, Address.gmxOrderHandler);
        dictator.setPermission(requestLogic, requestLogic.allocate.selector, users.owner);
        dictator.setPermission(requestLogic, requestLogic.mirror.selector, users.owner);
    }

    function testIncreaseRequestInUsdc() public {
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = getGeneratePuppetList(usdc, trader, 15);

        // vm.startPrank(trader);
        vm.startPrank(users.owner);

        bytes32 routeKey = PositionUtils.getRouteKey(usdc, trader);
        bytes32 mockOriginRequestKey = keccak256(abi.encodePacked(routeKey, uint(0)));

        requestLogic.allocate(usdc, mockOriginRequestKey, PositionUtils.getRouteKey(usdc, trader), 0, 1000);
        requestLogic.mirror{value: executionFee}(
            RequestPositionLogic.RequestMirrorPosition({
                trader: trader,
                originRequestKey: mockOriginRequestKey,
                routeKey: routeKey,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                orderType: GmxPositionUtils.OrderType.MarketIncrease,
                collateralDelta: 1e18,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );
    }

    function getGeneratePuppetList(
        IERC20 collateralToken,
        address trader,
        uint _length
    ) internal returns (address[] memory) {
        address[] memory puppetList = new address[](_length);
        for (uint i; i < _length; i++) {
            puppetList[i] =
                createPuppet(collateralToken, trader, string(abi.encodePacked("puppet:", Strings.toString(i))), 100e6);
        }
        return sortAddresses(puppetList);
    }

    function createPuppet(
        IERC20 collateralToken,
        address trader,
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        _dealERC20(address(collateralToken), user, fundValue);
        vm.startPrank(user);

        IERC20(collateralToken).approve(address(router), fundValue);

        puppetRouter.deposit(collateralToken, fundValue);
        puppetRouter.setAllocationRule(
            collateralToken, //
            trader,
            PuppetStore.RouteAllocationRule({
                throttleActivity: 0,
                allowanceRate: 1000,
                expiry: block.timestamp + 28 days
            })
        );

        return user;
    }

    function sortAddresses(address[] memory addresses) public pure returns (address[] memory) {
        uint length = addresses.length;
        for (uint i = 0; i < length; i++) {
            for (uint j = 0; j < length - i - 1; j++) {
                if (addresses[j] > addresses[j + 1]) {
                    // Swap addresses[j] and addresses[j + 1]
                    (addresses[j], addresses[j + 1]) = (addresses[j + 1], addresses[j]);
                }
            }
        }
        return addresses;
    }
}
