// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";
import {SharedSetup} from "test/base/SharedSetup.t.sol";

import {PositionUtils} from "src/position/util/PositionUtils.sol";

import {Cugar} from "src/shared/Cugar.sol";
import {CugarStore} from "src/shared/store/CugarStore.sol";

import {PuppetLogic} from "src/position/logic/PuppetLogic.sol";
import {PositionRouter} from "src/PositionRouter.sol";

import {PositionStore} from "src/position/store/PositionStore.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";

import {RequestIncreasePosition} from "src/position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "src/position/logic/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "src/position/logic/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "src/position/logic/ExecuteDecreasePosition.sol";

import {PuppetStore} from "src/position/store/PuppetStore.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";

import {Address, Role} from "script/Const.sol";

import {GmxPositionUtils} from "./../../src/position/util/GmxPositionUtils.sol";

contract PositionRouterTest is SharedSetup {
    uint arbitrumFork;

    PuppetStore puppetStore;
    PositionStore positionStore;

    PuppetRouter puppetRouter;
    PositionRouter positionRouter;
    IGmxExchangeRouter gmxExchangeRouter;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        // IGmxExchangeRouter(Address.gmxExchangeRouter).createOrder(
        //     GmxPositionUtils.CreateOrderParams({
        //         addresses: GmxPositionUtils.CreateOrderParamsAddresses({
        //             receiver: 0x722cf21E7f95dA140B05157387547722c1Dd1553,
        //             callbackContract: address(0),
        //             uiFeeReceiver: address(0),
        //             market: 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336,
        //             initialCollateralToken: IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
        //             swapPath: new address[](0)
        //         }),
        //         numbers: GmxPositionUtils.CreateOrderParamsNumbers({
        //             sizeDeltaUsd: 9090456191220250795000000000000000,
        //             initialCollateralDeltaAmount: 0,
        //             triggerPrice: 0,
        //             acceptablePrice: 3176985489719901,
        //             executionFee: 73485302000000,
        //             callbackGasLimit: 0,
        //             minOutputAmount: 0
        //         }),
        //         orderType: GmxPositionUtils.OrderType.MarketIncrease,
        //         decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
        //         isLong: true,
        //         shouldUnwrapNativeToken: false,
        //         referralCode: bytes32(0)
        //     })
        // );

        usdc = IERC20(Address.usdc);
        wnt = IWNT(Address.wnt);

        super.setUp();

        address positionRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 7);
        address puppetRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 6);

        puppetStore = new PuppetStore(dictator, router, puppetRouterAddress);
        positionStore = new PositionStore(dictator, router, positionRouterAddress);

        IERC20[] memory _tokenAllowanceCapList = new IERC20[](2);
        _tokenAllowanceCapList[0] = wnt;
        _tokenAllowanceCapList[1] = usdc;

        uint[] memory _tokenAllowanceCapAmountList = new uint[](2);
        _tokenAllowanceCapAmountList[0] = 0.2e18;
        _tokenAllowanceCapAmountList[1] = 500e30;

        puppetRouter = new PuppetRouter(
            dictator,
            PuppetRouter.CallConfig({
                setRule: PuppetLogic.CallSetRuleConfig({
                    router: router,
                    store: puppetStore,
                    minExpiryDuration: 0,
                    minAllowanceRate: 100,
                    maxAllowanceRate: 5000
                }),
                createSubaccount: PuppetLogic.CallCreateSubaccountConfig({factory: subaccountFactory, store: subaccountStore}),
                setBalance: PuppetLogic.CallSetBalanceConfig({router: router, store: puppetStore})
            }),
            _tokenAllowanceCapList,
            _tokenAllowanceCapAmountList
        );
        dictator.setRoleCapability(
            Role.PUPPET_DECREASE_BALANCE_AND_SET_ACTIVITY, address(puppetRouter), puppetRouter.decreaseBalanceAndSetActivityList.selector, true
        );

        positionRouter = new PositionRouter(
            dictator,
            PositionRouter.CallConfig({
                increase: RequestIncreasePosition.CallConfig({
                    wnt: wnt,
                    router: router,
                    positionStore: positionStore,
                    gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                    subaccountStore: subaccountStore,
                    subaccountFactory: subaccountFactory,
                    gmxOrderCallbackHandler: positionRouterAddress,
                    gmxOrderReciever: address(positionStore),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    callbackGasLimit: 2_000_000,
                    puppetStore: puppetStore,
                    puppetRouter: puppetRouter,
                    limitPuppetList: 20,
                    minimumMatchAmount: 100e30,
                    tokenTransferGasLimit: 200_000
                }),
                decrease: RequestDecreasePosition.CallConfig({
                    wnt: IWNT(Address.wnt),
                    gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                    positionStore: positionStore,
                    subaccountStore: subaccountStore,
                    gmxOrderCallbackHandler: positionRouterAddress,
                    gmxOrderReciever: address(positionStore),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    callbackGasLimit: 2_000_000,
                    tokenTransferGasLimit: 200_000
                }),
                executeIncrease: ExecuteIncreasePosition.CallConfig({
                    positionStore: positionStore, //
                    gmxOrderHandler: Address.gmxOrderHandler
                }),
                executeDecrease: ExecuteDecreasePosition.CallConfig({
                    router: router,
                    positionStore: positionStore,
                    puppetStore: puppetStore,
                    cugar: cugar,
                    cugarStore: cugarStore,
                    gmxOrderReciever: address(positionStore),
                    tokenTransferGasLimit: 200_000,
                    performanceFeeRate: 0.1e30, // 10%
                    traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
                })
            })
        );
        dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderExecution.selector, true);
        dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderCancellation.selector, true);
        dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderFrozen.selector, true);

        dictator.setUserRole(address(puppetStore), Role.TOKEN_TRANSFER, true);
        dictator.setUserRole(address(positionRouter), Role.TOKEN_TRANSFER, true);
        dictator.setUserRole(address(positionRouter), Role.SUBACCOUNT_CREATE, true);
        dictator.setUserRole(address(positionRouter), Role.PUPPET_DECREASE_BALANCE_AND_SET_ACTIVITY, true);
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

        positionRouter.requestIncrease{value: executionFee}(
            PositionUtils.TraderCallParams({
                account: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
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

    function getGeneratePuppetList(IERC20 collateralToken, address trader, uint _length) internal returns (address[] memory) {
        address[] memory puppetList = new address[](_length);
        for (uint i; i < _length; i++) {
            puppetList[i] = createPuppet(collateralToken, trader, string(abi.encodePacked("puppet:", Strings.toString(i))), 100e6);
        }
        return sortAddresses(puppetList);
    }

    function createPuppet(IERC20 collateralToken, address trader, string memory name, uint fundValue) internal returns (address payable) {
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
