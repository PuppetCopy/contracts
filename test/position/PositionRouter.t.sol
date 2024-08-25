// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";

import {PositionUtils} from "src/position/utils/PositionUtils.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {RevenueStore} from "src/tokenomics/store/RevenueStore.sol";

import {ExecuteDecreasePositionLogic} from "src/position/ExecuteDecreasePositionLogic.sol";
import {ExecuteIncreasePositionLogic} from "src/position/ExecuteIncreasePositionLogic.sol";
import {ExecuteRevertedAdjustmentLogic} from "src/position/ExecuteRevertedAdjustmentLogic.sol";
import {RequestDecreasePositionLogic} from "src/position/RequestDecreasePositionLogic.sol";
import {RequestIncreasePositionLogic} from "src/position/RequestIncreasePositionLogic.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";

import {SubaccountStore} from "src/shared/store/SubaccountStore.sol";

import {PuppetRouter} from "src/PuppetRouter.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";

import {PositionRouter} from "src/PositionRouter.sol";
import {PositionStore} from "src/position/store/PositionStore.sol";

import {Address} from "script/Const.sol";

contract PositionRouterTest is BasicSetup {
    uint arbitrumFork;

    PuppetStore puppetStore;
    PuppetLogic puppetLogic;
    PositionStore positionStore;

    PuppetRouter puppetRouter;
    PositionRouter positionRouter;
    IGmxExchangeRouter gmxExchangeRouter;

    RevenueStore revenueStore;

    SubaccountStore subaccountStore;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        usdc = IERC20(Address.usdc);
        wnt = IWNT(Address.wnt);

        super.setUp();

        IERC20[] memory _tokenAllowanceCapList = new IERC20[](2);
        _tokenAllowanceCapList[0] = wnt;
        _tokenAllowanceCapList[1] = usdc;

        uint[] memory _tokenAllowanceCapAmountList = new uint[](2);
        _tokenAllowanceCapAmountList[0] = 0.2e18;
        _tokenAllowanceCapAmountList[1] = 500e30;

        IERC20[] memory _tokenBuybackThresholdList = new IERC20[](2);
        _tokenBuybackThresholdList[0] = wnt;
        _tokenBuybackThresholdList[1] = usdc;

        uint[] memory _tokenBuybackThresholdAmountList = new uint[](2);
        _tokenBuybackThresholdAmountList[0] = 0.2e18;
        _tokenBuybackThresholdAmountList[1] = 500e30;

        revenueStore = new RevenueStore(dictator, router, _tokenBuybackThresholdList, _tokenBuybackThresholdAmountList);

        puppetStore = new PuppetStore(dictator, router, _tokenAllowanceCapList, _tokenAllowanceCapAmountList);
        puppetLogic = new PuppetLogic(
            dictator,
            eventEmitter,
            puppetStore,
            PuppetLogic.Config({minExpiryDuration: 0, minAllowanceRate: 100, maxAllowanceRate: 5000})
        );
        puppetRouter = new PuppetRouter(dictator, eventEmitter, PuppetRouter.Config({logic: puppetLogic}));

        dictator.setAccess(puppetStore, address(puppetRouter));
        dictator.setAccess(router, address(puppetStore));

        subaccountStore = new SubaccountStore(dictator, computeCreateAddress(users.owner, vm.getNonce(users.owner) + 2));
        positionStore = new PositionStore(dictator, router);

        RequestIncreasePositionLogic requestIncrease = new RequestIncreasePositionLogic(
            dictator,
            eventEmitter,
            RequestIncreasePositionLogic.Config({
                wnt: wnt,
                gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                router: router,
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                gmxOrderReciever: address(positionStore),
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000,
                puppetStore: puppetStore,
                limitPuppetList: 20,
                minimumMatchAmount: 100e30,
                tokenTransferGasLimit: 200_000
            })
        );
        ExecuteIncreasePositionLogic executeIncrease = new ExecuteIncreasePositionLogic(
            dictator, eventEmitter, ExecuteIncreasePositionLogic.Config({positionStore: positionStore})
        );
        RequestDecreasePositionLogic requestDecrease = new RequestDecreasePositionLogic(
            dictator,
            eventEmitter,
            RequestDecreasePositionLogic.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                positionStore: positionStore,
                subaccountStore: subaccountStore,
                gmxOrderReciever: address(positionStore),
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000
            })
        );
        ExecuteDecreasePositionLogic executeDecrease = new ExecuteDecreasePositionLogic(
            dictator,
            eventEmitter,
            ExecuteDecreasePositionLogic.Config({
                router: router,
                positionStore: positionStore,
                puppetStore: puppetStore,
                revenueStore: revenueStore,
                gmxOrderReciever: address(positionStore),
                performanceFeeRate: 0.1e30, // 10%
                traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
            })
        );
        ExecuteRevertedAdjustmentLogic executeRevertedAdjustment = new ExecuteRevertedAdjustmentLogic(
            dictator, eventEmitter, ExecuteRevertedAdjustmentLogic.Config({handlehandle: "test"})
        );

        positionRouter = new PositionRouter(
            dictator,
            eventEmitter,
            positionStore,
            PositionRouter.Config({
                requestIncrease: requestIncrease,
                requestDecrease: requestDecrease,
                executeIncrease: executeIncrease,
                executeDecrease: executeDecrease,
                executeRevertedAdjustment: executeRevertedAdjustment
            })
        );

        dictator.setAccess(subaccountStore, address(positionRouter));
        dictator.setAccess(positionStore, address(positionRouter));
        dictator.setAccess(revenueStore, address(positionRouter));
        dictator.setAccess(puppetStore, address(positionRouter));
        dictator.setAccess(router, address(positionRouter));

        dictator.setPermission(positionRouter, Address.gmxOrderHandler, positionRouter.afterOrderExecution.selector);
        dictator.setPermission(positionRouter, Address.gmxOrderHandler, positionRouter.afterOrderCancellation.selector);
        dictator.setPermission(positionRouter, Address.gmxOrderHandler, positionRouter.afterOrderFrozen.selector);
    }

    function testIncreaseRequestInUsdc() public {
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = getGeneratePuppetList(usdc, trader, 10);

        gmxOracle.getStablePrice(Address.gmxDatastore, address(usdc));
        gmxOracle.getStablePrice(Address.gmxDatastore, Address.wnt);

        vm.startPrank(trader);
        _dealERC20(address(usdc), trader, 100e6);
        usdc.approve(address(router), 100e6);

        // positionRouter.requestIncrease{value: executionFee}(
        //     PositionUtils.TraderCallParams({
        //         account: trader,
        //         market: Address.gmxEthUsdcMarket,
        //         collateralToken: usdc,
        //         isLong: true,
        //         executionFee: executionFee,
        //         collateralDelta: 100e6,
        //         sizeDelta: 1000e30,
        //         acceptablePrice: 3320e12,
        //         triggerPrice: 3420e6
        //     }),
        //     puppetList
        // );
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

        puppetRouter.setRule(
            collateralToken, //
            trader,
            PuppetStore.Rule({throttleActivity: 0, allowanceRate: 1000, expiry: block.timestamp + 28 days})
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
