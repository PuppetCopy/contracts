// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {FeeMarketplace} from "../tokenomics/FeeMarketplace.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchRule} from "./../position/MatchRule.sol";
import {Error} from "./../shared/Error.sol";
import {Subaccount} from "./../shared/Subaccount.sol";
import {SubaccountStore} from "./../shared/SubaccountStore.sol";
import {TokenRouter} from "./../shared/TokenRouter.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract MirrorPosition is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        uint limitAllocationListLength;
        uint performanceContributionRate;
        uint traderPerformanceContributionShare;
    }

    struct Allocation {
        bytes32 matchKey;
        bytes32 listHash;
        IERC20 collateralToken;
        uint allocated;
        uint collateral;
        uint size;
        uint settled;
        uint profit;
        uint transactionCost;
    }

    struct MirrorPositionParams {
        IERC20 collateralToken;
        bytes32 sourceRequestKey;
        bytes32 allocationKey;
        address trader;
        address market;
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
    }

    struct RequestAdjustment {
        bytes32 allocationKey;
        bytes32 sourceRequestKey;
        bytes32 matchKey;
        uint sizeDelta;
        uint transactionCost;
    }

    Config public config;

    SubaccountStore immutable subaccountStore;
    MatchRule immutable matchRule;
    FeeMarketplace immutable feeMarket;

    mapping(bytes32 matchKey => mapping(address puppet => uint)) public activityThrottleMap;
    mapping(bytes32 allocationKey => Allocation) public allocationMap;
    mapping(bytes32 matchKey => Subaccount) public routeSubaccountMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    constructor(
        IAuthority _authority,
        SubaccountStore _puppetStore,
        MatchRule _matchRule,
        FeeMarketplace _feeMarket
    ) CoreContract("MirrorPosition", "1", _authority) {
        subaccountStore = _puppetStore;
        matchRule = _matchRule;
        feeMarket = _feeMarket;
    }

    function allocate(
        IERC20 _collateralToken,
        bytes32 _sourceRequestKey,
        bytes32 _matchKey,
        bytes32 _positionKey,
        address[] calldata _puppetList
    ) external auth returns (bytes32) {
        uint _startGas = gasleft();
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_matchKey, _positionKey);

        Allocation storage allocation = allocationMap[_allocationKey];
        require(allocation.size == 0, Error.MirrorPosition__AllocationAlreadyExists());
        require(_puppetList.length <= config.limitAllocationListLength, Error.MirrorPosition__PuppetListLimit());

        if (allocation.matchKey == 0) {
            allocation.matchKey = _matchKey;
            allocation.collateralToken = _collateralToken;
        }

        allocation.listHash = keccak256(abi.encode(_puppetList));

        uint[] memory _balanceList = subaccountStore.getBalanceList(_collateralToken, _puppetList);
        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);

        allocation.allocated = _processPuppetList(_matchKey, _puppetList, _balanceList, _ruleList);

        subaccountStore.setBalanceList(_collateralToken, _puppetList, _balanceList);

        allocation.transactionCost += (_startGas - gasleft()) * tx.gasprice;

        _logEvent(
            "Allocate",
            abi.encode(
                _allocationKey,
                _matchKey,
                _sourceRequestKey,
                _collateralToken,
                allocation.listHash,
                allocation.allocated,
                allocation.transactionCost,
                _puppetList,
                _balanceList
            )
        );

        return _allocationKey;
    }

    function _processPuppetList(
        bytes32 _matchKey,
        address[] calldata _puppetList,
        uint[] memory _balanceList,
        MatchRule.Rule[] memory _ruleList
    ) internal returns (uint allocated) {
        for (uint i = 0; i < _puppetList.length; i++) {
            MatchRule.Rule memory rule = _ruleList[i];

            // Only process if within time window
            if (rule.expiry > block.timestamp && block.timestamp > activityThrottleMap[_matchKey][_puppetList[i]]) {
                _balanceList[i] += Precision.applyBasisPoints(rule.allowanceRate, _balanceList[i]);
                allocated += _balanceList[i];
            }

            activityThrottleMap[_matchKey][_puppetList[i]] = block.timestamp + rule.throttleActivity;
        }
    }

    function settle(bytes32 allocationKey, address[] calldata puppetList) external auth {
        uint startGas = gasleft();

        Allocation storage allocation = allocationMap[allocationKey];

        require(allocation.matchKey != bytes32(0), Error.MirrorPosition__AllocationDoesNotExist());
        require(allocation.collateral == 0, Error.MirrorPosition__PendingSettlement());

        bytes32 puppetListHash = keccak256(abi.encode(puppetList));

        require(allocation.listHash == puppetListHash, Error.MirrorPosition__InvalidPuppetListIntegrity());

        allocation.listHash = puppetListHash;

        uint[] memory _nextBalanceList = new uint[](puppetList.length);
        uint[] memory allocationList = new uint[](puppetList.length);

        uint totalPuppetContribution = allocation.settled;

        if (allocation.profit > 0 && feeMarket.askPrice(allocation.collateralToken) > 0) {
            totalPuppetContribution -= Precision.applyFactor(config.performanceContributionRate, allocation.profit);

            feeMarket.deposit(allocation.collateralToken, address(this), allocation.settled - totalPuppetContribution);
        }

        if (totalPuppetContribution > 0) {
            for (uint i = 0; i < allocationList.length; i++) {
                uint puppetAllocation = allocationList[i];
                if (puppetAllocation == 0) continue;

                _nextBalanceList[i] += puppetAllocation * totalPuppetContribution / allocation.allocated;
            }
        }

        if (allocation.size > 0) {
            allocation.profit = 0;
            allocation.allocated -= allocation.settled;

            allocationMap[allocationKey] = allocation;
        } else {
            delete allocationMap[allocationKey];
        }

        allocation.transactionCost += (startGas - gasleft()) * tx.gasprice;

        _logEvent(
            "Settle",
            abi.encode(
                allocation.collateralToken,
                allocation.matchKey,
                allocationKey,
                puppetListHash,
                puppetList,
                allocationList,
                totalPuppetContribution,
                allocation.allocated,
                allocation.settled,
                allocation.profit,
                allocation.transactionCost
            )
        );
    }

    function mirror(
        MirrorPositionParams calldata params
    ) external payable auth returns (bytes32 requestKey) {
        uint startGas = gasleft();

        Allocation memory allocation = allocationMap[params.allocationKey];

        Subaccount subaccount = routeSubaccountMap[allocation.matchKey];
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            subaccount = routeSubaccountMap[allocation.matchKey] = new Subaccount(subaccountStore, params.trader);
        }

        RequestAdjustment memory request = RequestAdjustment({
            matchKey: allocation.matchKey,
            allocationKey: params.allocationKey,
            sourceRequestKey: params.sourceRequestKey,
            sizeDelta: 0,
            transactionCost: startGas
        });

        uint leverage;
        uint targetLeverage;

        if (allocation.size == 0) {
            require(allocation.allocated > 0, Error.MirrorPosition__NoAllocation());
            require(allocation.collateral == 0, Error.MirrorPosition__PendingExecution());

            allocation.collateral = allocation.allocated;

            subaccountStore.transferOut(params.collateralToken, config.gmxOrderVault, allocation.allocated);
            allocationMap[params.allocationKey] = allocation;
            requestKey = submitOrder(
                params,
                subaccount,
                request,
                GmxPositionUtils.OrderType.MarketIncrease,
                allocation.allocated,
                config.increaseCallbackGasLimit
            );

            request.sizeDelta = params.sizeDeltaInUsd;
        } else {
            leverage = Precision.toBasisPoints(allocation.size, allocation.collateral);
            targetLeverage = params.isIncrease
                ? Precision.toBasisPoints(
                    allocation.size + params.sizeDeltaInUsd, allocation.collateral + params.collateralDelta
                )
                : params.sizeDeltaInUsd < allocation.size
                    ? Precision.toBasisPoints(
                        allocation.size - params.sizeDeltaInUsd, allocation.collateral - params.collateralDelta
                    )
                    : 0;

            uint deltaLeverage;

            if (targetLeverage > leverage) {
                deltaLeverage = targetLeverage - leverage;
                requestKey = submitOrder(
                    params,
                    subaccount,
                    request,
                    GmxPositionUtils.OrderType.MarketIncrease,
                    0,
                    config.increaseCallbackGasLimit
                );
                request.sizeDelta = allocation.size * deltaLeverage / targetLeverage;
            } else {
                deltaLeverage = leverage - targetLeverage;
                requestKey = submitOrder(
                    params,
                    subaccount,
                    request,
                    GmxPositionUtils.OrderType.MarketDecrease,
                    0,
                    config.decreaseCallbackGasLimit
                );
                request.sizeDelta = allocation.size * deltaLeverage / leverage;
            }
        }

        request.transactionCost += (startGas - gasleft()) * tx.gasprice + params.executionFee;
        requestAdjustmentMap[requestKey] = request;

        _logEvent(
            targetLeverage > leverage ? "RequestIncrease" : "RequestDecrease",
            abi.encode(
                subaccount,
                params.trader,
                params.allocationKey,
                params.sourceRequestKey,
                requestKey,
                request.matchKey,
                request.sizeDelta
            )
        );
    }

    function increase(
        bytes32 requestKey
    ) external auth {
        RequestAdjustment memory request = requestAdjustmentMap[requestKey];

        require(request.matchKey != 0, Error.MirrorPosition__RequestDoesNotMatchExecution());

        Allocation storage allocation = allocationMap[request.allocationKey];

        allocation.size += request.sizeDelta;

        delete requestAdjustmentMap[requestKey];

        _logEvent(
            "ExecuteIncrease",
            abi.encode(
                requestKey,
                request.sourceRequestKey,
                request.allocationKey,
                request.matchKey,
                request.sizeDelta,
                request.transactionCost,
                allocation.size
            )
        );
    }

    function decrease(
        bytes32 requestKey
    ) external auth {
        RequestAdjustment memory request = requestAdjustmentMap[requestKey];

        require(request.matchKey != 0, Error.MirrorPosition__RequestDoesNotMatchExecution());

        Allocation storage allocation = allocationMap[request.allocationKey];

        require(allocation.size > 0, Error.MirrorPosition__PositionDoesNotExist());

        uint recordedAmountIn = subaccountStore.recordTransferIn(allocation.collateralToken);
        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (request.sizeDelta < allocation.size) {
            uint adjustedAllocation = allocation.allocated * request.sizeDelta / allocation.size;
            uint profit = recordedAmountIn > adjustedAllocation ? recordedAmountIn - adjustedAllocation : 0;

            allocation.profit += profit;
            allocation.settled += recordedAmountIn;
            allocation.size -= request.sizeDelta;
        } else {
            allocation.profit = recordedAmountIn > allocation.allocated ? recordedAmountIn - allocation.allocated : 0;
            allocation.settled += recordedAmountIn;
            allocation.size = 0;
        }

        delete requestAdjustmentMap[requestKey];
        allocationMap[request.allocationKey] = allocation;

        _logEvent(
            "ExecuteDecrease",
            abi.encode(
                requestKey,
                request.sourceRequestKey,
                request.allocationKey,
                request.matchKey,
                request.sizeDelta,
                request.transactionCost,
                recordedAmountIn,
                allocation.settled
            )
        );
    }

    function submitOrder(
        MirrorPositionParams calldata order,
        Subaccount subaccount,
        RequestAdjustment memory request,
        GmxPositionUtils.OrderType orderType,
        uint collateralDelta,
        uint callbackGasLimit
    ) internal returns (bytes32 requestKey) {
        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(
                config.gmxExchangeRouter.createOrder.selector,
                GmxPositionUtils.CreateOrderParams({
                    addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                        receiver: address(this),
                        callbackContract: config.callbackHandler,
                        uiFeeReceiver: address(0),
                        market: order.market,
                        initialCollateralToken: order.collateralToken,
                        swapPath: new address[](0)
                    }),
                    numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                        sizeDeltaUsd: request.sizeDelta,
                        initialCollateralDeltaAmount: collateralDelta,
                        triggerPrice: order.triggerPrice,
                        acceptablePrice: order.acceptablePrice,
                        executionFee: order.executionFee,
                        callbackGasLimit: callbackGasLimit,
                        minOutputAmount: 0
                    }),
                    orderType: orderType,
                    decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
                    isLong: order.isLong,
                    shouldUnwrapNativeToken: false,
                    referralCode: config.referralCode
                })
            )
        );

        if (!orderSuccess) {
            ErrorUtils.revertWithParsedMessage(orderReturnData);
        }

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
