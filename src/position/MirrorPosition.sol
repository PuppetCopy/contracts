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
import {IGmxDatastore} from "./interface/IGmxDatastore.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract MirrorPosition is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
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

    struct UnhandledCallback {
        GmxPositionUtils.Props order;
        address operator;
        bytes eventData;
        bytes32 key;
    }

    Config public config;

    SubaccountStore immutable subaccountStore;
    MatchRule immutable matchRule;
    FeeMarketplace immutable feeMarket;

    mapping(bytes32 matchKey => mapping(address puppet => uint)) public activityThrottleMap;
    mapping(bytes32 allocationKey => mapping(address puppet => uint amount)) public userAllocationMap;
    mapping(bytes32 allocationKey => Allocation) public allocationMap;

    // PositionStore state variables
    mapping(bytes32 matchKey => Subaccount) public routeSubaccountMap;
    mapping(bytes32 matchKey => IERC20) public routeTokenMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    uint public unhandledCallbackListId = 0;
    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

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

    // PositionStore functions
    function getRequestAdjustment(
        bytes32 _key
    ) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_key];
    }

    function setRequestAdjustment(bytes32 _key, RequestAdjustment calldata _ra) external auth {
        requestAdjustmentMap[_key] = _ra;
    }

    function removeRequestAdjustment(
        bytes32 _key
    ) external auth {
        delete requestAdjustmentMap[_key];
    }

    function removeRequestDecrease(
        bytes32 _key
    ) external auth {
        delete requestAdjustmentMap[_key];
    }

    function setUnhandledCallbackList(
        GmxPositionUtils.Props calldata _order,
        address _operator,
        bytes32 _key,
        bytes calldata _eventData
    ) external auth returns (uint) {
        UnhandledCallback memory callbackResponse =
            UnhandledCallback({order: _order, operator: _operator, eventData: _eventData, key: _key});

        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = callbackResponse;

        return id;
    }

    function getUnhandledCallback(
        uint _id
    ) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_id];
    }

    function removeUnhandledCallback(
        uint _id
    ) external auth {
        delete unhandledCallbackMap[_id];
    }

    function getSubaccount(
        bytes32 _key
    ) external view returns (Subaccount) {
        return routeSubaccountMap[_key];
    }

    function createSubaccount(bytes32 _key, address _account) public auth returns (Subaccount) {
        return routeSubaccountMap[_key] = new Subaccount(subaccountStore, _account);
    }

    // MirrorPosition functions
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

    function allocate(
        IERC20 _collateralToken,
        bytes32 _sourceRequestKey,
        bytes32 _matchKey,
        bytes32 _positionKey,
        address[] calldata _puppetList
    ) external auth returns (bytes32 allocationKey) {
        uint startGas = gasleft();

        allocationKey = PositionUtils.getAllocationKey(_matchKey, _positionKey);

        Allocation storage allocation = allocationMap[allocationKey];

        require(allocation.size == 0, Error.MirrorPosition__AllocationAlreadyExists());

        uint puppetListLength = _puppetList.length;

        require(puppetListLength <= config.limitAllocationListLength, Error.MirrorPosition__PuppetListLimit());

        if (allocation.matchKey == 0) {
            allocation.matchKey = _matchKey;
            allocation.collateralToken = _collateralToken;
        }

        allocation.listHash = keccak256(abi.encode(_puppetList));

        MatchRule.Rule[] memory ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        uint[] memory _nextActivityThrottleList = new uint[](puppetListLength);
        uint[] memory _nextBalanceList = subaccountStore.getBalanceList(_collateralToken, _puppetList);

        for (uint i = 0; i < puppetListLength; i++) {
            MatchRule.Rule memory rule = ruleList[i];

            uint _nextAtivityThrottle = block.timestamp + rule.throttleActivity;
            _nextActivityThrottleList[i] = _nextAtivityThrottle;

            uint _nextAllocationDelta = _nextBalanceList[i];

            activityThrottleMap[_matchKey][_puppetList[i]] = _nextAtivityThrottle;
            // Throttle user allocation if the current time is between the rule's expiry and the activity throttle time
            if (rule.expiry > block.timestamp && block.timestamp > _nextAtivityThrottle) {
                _nextAllocationDelta += Precision.applyBasisPoints(rule.allowanceRate, _nextAllocationDelta);

                _nextBalanceList[i] = _nextAllocationDelta;
                allocation.allocated += _nextAllocationDelta;
            }

            _nextBalanceList[i] = _nextAllocationDelta;
        }

        subaccountStore.setBalanceList(_collateralToken, _puppetList, _nextBalanceList);

        allocation.transactionCost += (startGas - gasleft()) * tx.gasprice;

        _logEvent(
            "Allocate",
            abi.encode(
                _collateralToken,
                _sourceRequestKey,
                _matchKey,
                _positionKey,
                allocationKey,
                allocation.listHash,
                _puppetList,
                _nextActivityThrottleList,
                _nextBalanceList,
                allocation.allocated,
                allocation.transactionCost
            )
        );
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

    function increase(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
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
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
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

    function mirror(
        MirrorPositionParams calldata params
    ) external payable auth returns (bytes32 requestKey) {
        uint startGas = gasleft();

        Allocation memory allocation = allocationMap[params.allocationKey];

        Subaccount subaccount = routeSubaccountMap[allocation.matchKey];
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            subaccount = createSubaccount(allocation.matchKey, params.trader);
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

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
