// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PositionRouter} from "src/PositionRouter.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";
import {AllocationLogic} from "src/position/AllocationLogic.sol";
import {ExecutionLogic} from "src/position/ExecutionLogic.sol";

import {RequestLogic} from "src/position/RequestLogic.sol";
import {UnhandledCallbackLogic} from "src/position/UnhandledCallbackLogic.sol";
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

    RequestLogic requestLogic;
    AllocationLogic allocationLogic;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();
        contributeStore = new ContributeStore(dictator, router);

        puppetStore = new PuppetStore(dictator, router);
        dictator.setAccess(puppetStore, address(contributeStore));
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
        dictator.setPermission(puppetLogic, puppetLogic.withdraw.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRuleList.selector, address(puppetRouter));

        allocationLogic = new AllocationLogic(dictator, eventEmitter, contributeStore, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(allocationLogic));
        dictator.setAccess(contributeStore, address(allocationLogic));
        dictator.setAccess(puppetStore, address(allocationLogic));

        requestLogic = new RequestLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(requestLogic));
        dictator.setAccess(puppetStore, address(requestLogic));
        dictator.setAccess(positionStore, address(requestLogic));

        ExecutionLogic executionLogic = new ExecutionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executionLogic));
        dictator.setAccess(positionStore, address(executionLogic));

        UnhandledCallbackLogic unhandledCallbackLogic =
            new UnhandledCallbackLogic(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(unhandledCallbackLogic));

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
                minAllowanceRate: 100, // 10 basis points
                maxAllowanceRate: 10000,
                minAllocationActivity: 3600,
                maxAllocationActivity: 604800,
                tokenAllowanceList: tokenAllowanceCapList,
                tokenAllowanceAmountList: tokenAllowanceCapAmountList
            })
        );

        dictator.setPermission(requestLogic, requestLogic.setConfig.selector, users.owner);
        requestLogic.setConfig(
            RequestLogic.Config({
                gmxExchangeRouter: mockGmxExchangeRouter,
                gmxDatastore: IGmxDatastore(Address.gmxDatastore),
                callbackHandler: address(positionRouter),
                gmxFundsReciever: address(positionStore),
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000
            })
        );

        dictator.setPermission(allocationLogic, allocationLogic.setConfig.selector, users.owner);
        allocationLogic.setConfig(
            AllocationLogic.Config({
                limitAllocationListLength: 100,
                performanceContributionRate: 0.1e30,
                traderPerformanceContributionShare: 0
            })
        );
        dictator.setPermission(allocationLogic, allocationLogic.allocate.selector, users.owner);
        dictator.setPermission(allocationLogic, allocationLogic.settle.selector, users.owner);

        dictator.setPermission(puppetRouter, puppetRouter.setConfig.selector, users.owner);
        puppetRouter.setConfig(PuppetRouter.Config({logic: puppetLogic}));

        dictator.setPermission(positionRouter, positionRouter.setConfig.selector, users.owner);
        positionRouter.setConfig(
            PositionRouter.Config({
                requestLogic: requestLogic,
                allocationLogic: allocationLogic,
                executionLogic: executionLogic,
                unhandledCallbackLogic: unhandledCallbackLogic
            })
        );

        // test setup

        dictator.setPermission(requestLogic, requestLogic.mirror.selector, address(positionRouter));
        dictator.setPermission(allocationLogic, allocationLogic.allocate.selector, address(positionRouter));
        dictator.setPermission(allocationLogic, allocationLogic.settle.selector, address(positionRouter));

        dictator.setPermission(positionRouter, positionRouter.afterOrderExecution.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderCancellation.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderFrozen.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.mirror.selector, users.owner);
        dictator.setPermission(positionRouter, positionRouter.allocate.selector, users.owner);
        dictator.setPermission(positionRouter, positionRouter.settle.selector, users.owner);
    }

    function testIncreaseRequestInUsdc() public {
        skip(100);
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = getGeneratePuppetList(usdc, trader, 10);

        // vm.startPrank(trader);
        vm.startPrank(users.owner);

        bytes32 mockOriginRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));

        bytes32 allocationKey =
            allocationLogic.allocate(usdc, mockOriginRequestKey, PositionUtils.getMatchKey(usdc, trader), puppetList);

        // allocationLogic.settle(allocationKey, puppetList);

        positionRouter.mirror{value: executionFee}(
            RequestLogic.MirrorPositionParams({
                trader: trader,
                allocationKey: allocationKey,
                originRequestKey: mockOriginRequestKey,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
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

        puppetRouter.setMatchRule(
            collateralToken,
            PuppetStore.MatchRule({allowanceRate: 1000, throttleActivity: 3600, expiry: block.timestamp + 100000}),
            trader
        );

        return user;
    }

    function sortAddresses(
        address[] memory addresses
    ) public pure returns (address[] memory) {
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
