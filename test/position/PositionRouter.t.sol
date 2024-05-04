// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";

import {PositionUtils} from "src/position/util/PositionUtils.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {RewardStore} from "src/token/store/RewardStore.sol";

import {PuppetLogic} from "src/puppet/logic/PuppetLogic.sol";

import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";

import {RequestIncreasePosition} from "src/position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "src/position/logic/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "src/position/logic/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "src/position/logic/ExecuteDecreasePosition.sol";

import {SubaccountStore} from "src/shared/store/SubaccountStore.sol";

import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {PuppetRouter} from "src/puppet/PuppetRouter.sol";

import {PositionStore} from "src/position/store/PositionStore.sol";
import {PositionRouter} from "src/position/PositionRouter.sol";

import {Address} from "script/Const.sol";

contract PositionRouterTest is BasicSetup {
    uint arbitrumFork;

    PuppetStore puppetStore;
    PositionStore positionStore;

    PuppetRouter puppetRouter;
    PositionRouter positionRouter;
    IGmxExchangeRouter gmxExchangeRouter;

    RewardStore rewardStore;

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

        rewardStore = new RewardStore(dictator, router);

        puppetStore = new PuppetStore(dictator, router, _tokenAllowanceCapList, _tokenAllowanceCapAmountList);
        puppetRouter = new PuppetRouter(
            dictator,
            puppetStore,
            PuppetRouter.CallConfig({
                setRule: PuppetLogic.CallSetRuleConfig({
                    router: router, //
                    minExpiryDuration: 0,
                    minAllowanceRate: 100,
                    maxAllowanceRate: 5000
                })
            })
        );
        dictator.setAccess(puppetStore, address(puppetRouter));
        dictator.setPermission(router, address(puppetStore), router.transfer.selector);

        subaccountStore = new SubaccountStore(dictator, computeCreateAddress(users.owner, vm.getNonce(users.owner) + 2));
        positionStore = new PositionStore(dictator, router);
        positionRouter = new PositionRouter(
            dictator,
            PositionRouter.CallConfig({
                increase: RequestIncreasePosition.CallConfig({
                    wnt: wnt,
                    router: router,
                    positionStore: positionStore,
                    gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                    subaccountStore: subaccountStore,
                    gmxOrderReciever: address(positionStore),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    callbackGasLimit: 2_000_000,
                    puppetStore: puppetStore,
                    limitPuppetList: 20,
                    minimumMatchAmount: 100e30,
                    tokenTransferGasLimit: 200_000
                }),
                decrease: RequestDecreasePosition.CallConfig({
                    wnt: IWNT(Address.wnt),
                    gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                    positionStore: positionStore,
                    subaccountStore: subaccountStore,
                    gmxOrderReciever: address(positionStore),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    callbackGasLimit: 2_000_000
                }),
                executeIncrease: ExecuteIncreasePosition.CallConfig({
                    positionStore: positionStore, //
                    gmxOrderHandler: Address.gmxOrderHandler
                }),
                executeDecrease: ExecuteDecreasePosition.CallConfig({
                    router: router,
                    positionStore: positionStore,
                    puppetStore: puppetStore,
                    rewardStore: rewardStore,
                    gmxOrderReciever: address(positionStore),
                    performanceFeeRate: 0.1e30, // 10%
                    traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
                })
            })
        );

        dictator.setAccess(subaccountStore, address(positionRouter));
        dictator.setAccess(positionStore, address(positionRouter));
        dictator.setAccess(rewardStore, address(positionRouter));
        dictator.setAccess(puppetStore, address(positionRouter));
        dictator.setPermission(router, address(positionRouter), router.transfer.selector);

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
