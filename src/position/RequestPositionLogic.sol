// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetStore} from "./../puppet/store/PuppetStore.sol";
import {Error} from "./../shared/Error.sol";
import {Subaccount} from "./../shared/Subaccount.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxDatastore} from "./interface/IGmxDataStore.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract RequestPositionLogic is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxFundsReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minimumMatchAmount;
    }

    struct OrderMirrorPosition {
        address[] puppetList;
        address trader;
        address market;
        IERC20 collateralToken;
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
    }

    PuppetStore puppetStore;
    MirrorPositionStore positionStore;
    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("RequestPositionLogic", "1", _authority, _eventEmitter) {
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function submitOrder(
        OrderMirrorPosition calldata order,
        Subaccount subaccount,
        GmxPositionUtils.OrderType orderType,
        MirrorPositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(
                config.gmxExchangeRouter.createOrder.selector,
                GmxPositionUtils.CreateOrderParams({
                    addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                        receiver: config.gmxFundsReciever,
                        callbackContract: config.callbackHandler,
                        uiFeeReceiver: address(0),
                        market: order.market,
                        initialCollateralToken: order.collateralToken,
                        swapPath: new address[](0)
                    }),
                    numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                        sizeDeltaUsd: request.puppetSizeDelta,
                        initialCollateralDeltaAmount: request.puppetCollateralDelta,
                        triggerPrice: order.triggerPrice,
                        acceptablePrice: order.acceptablePrice,
                        executionFee: order.executionFee,
                        callbackGasLimit: config.callbackGasLimit,
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
        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + order.executionFee;
        positionStore.setRequestAdjustment(requestKey, request);
    }

    function adjust(
        OrderMirrorPosition calldata order,
        MirrorPositionStore.Position memory mirrorPosition,
        MirrorPositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        uint leverage = Precision.toBasisPoints(mirrorPosition.traderSize, mirrorPosition.traderCollateral);
        uint targetLeverage = order.isIncrease
            ? Precision.toBasisPoints(
                mirrorPosition.traderSize + order.sizeDelta, mirrorPosition.traderCollateral + order.collateralDelta
            )
            : order.sizeDelta < mirrorPosition.traderSize
                ? Precision.toBasisPoints(
                    mirrorPosition.traderSize - order.sizeDelta, mirrorPosition.traderCollateral - order.collateralDelta
                )
                : 0;

        if (targetLeverage > leverage) {
            uint deltaLeverage = targetLeverage - leverage;
            request.puppetSizeDelta = mirrorPosition.traderSize * deltaLeverage / targetLeverage;

            requestKey = submitOrder(order, request.subaccount, GmxPositionUtils.OrderType.MarketIncrease, request);
            logEvent(
                "requestIncrease",
                abi.encode(order.trader, requestKey, request.positionKey, targetLeverage, request.puppetSizeDelta)
            );
        } else {
            uint deltaLeverage = leverage - targetLeverage;
            request.puppetSizeDelta = mirrorPosition.traderSize * deltaLeverage / leverage;

            requestKey = submitOrder(order, request.subaccount, GmxPositionUtils.OrderType.MarketDecrease, request);
            logEvent(
                "requestDecrease",
                abi.encode(order.trader, requestKey, request.positionKey, targetLeverage, request.puppetSizeDelta)
            );
        }
    }

    function matchUp(
        OrderMirrorPosition calldata order,
        MirrorPositionStore.AllocationMatch memory allocation,
        MirrorPositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        (
            PuppetStore.AllocationRule[] memory ruleList,
            uint[] memory activityList,
            uint[] memory balanceToAllocationList
        ) = puppetStore.getBalanceAndActivityList(order.collateralToken, order.trader, order.puppetList);

        uint puppetListLength = order.puppetList.length;

        if (puppetListLength > config.limitPuppetList) {
            revert Error.RequestPositionLogic__PuppetListLimitExceeded();
        }

        for (uint i = 0; i < puppetListLength; i++) {
            // validate that puppet list calldata is sorted and has no duplicates
            if (i > 0) {
                if (order.puppetList[i - 1] > order.puppetList[i]) {
                    revert Error.RequestPositionLogic__UnsortedPuppetList();
                }
                if (order.puppetList[i - 1] == order.puppetList[i]) {
                    revert Error.RequestPositionLogic__DuplicatesInPuppetList();
                }
            }

            PuppetStore.AllocationRule memory rule = ruleList[i];

            // puppet rule expired or not set
            if (
                rule.expiry > block.timestamp
                // current time is greater than  throttle activity period
                || activityList[i] + rule.throttleActivity < block.timestamp
                // has enough allowance or token allowance cap exists
                || balanceToAllocationList[i] > config.minimumMatchAmount
            ) {
                // the lowest of either the allowance or the trader's deposit
                uint collateralDelta = Math.min(
                    Precision.applyBasisPoints(rule.allowanceRate, balanceToAllocationList[i]),
                    order.collateralDelta // trader own deposit
                );
                request.puppetCollateralDelta += collateralDelta;
                request.puppetSizeDelta += collateralDelta * order.sizeDelta / order.collateralDelta;

                balanceToAllocationList[i] = collateralDelta;
            } else {
                balanceToAllocationList[i] = 0;
            }

            activityList[i] = block.timestamp;
        }

        puppetStore.transferOutAndUpdateActivityList(
            order.collateralToken,
            config.gmxOrderVault,
            order.trader,
            block.timestamp,
            order.puppetList,
            balanceToAllocationList
        );

        allocation.collateralToken = order.collateralToken;
        allocation.trader = order.trader;
        allocation.puppetList = order.puppetList;
        allocation.collateralList = balanceToAllocationList;

        positionStore.setAllocationMatchMap(request.allocationKey, allocation);

        requestKey = submitOrder(order, request.subaccount, GmxPositionUtils.OrderType.MarketIncrease, request);

        logEvent("requestMatch", abi.encode(allocation, order, requestKey, request.positionKey));
    }

    function orderMirrorPosition(OrderMirrorPosition calldata order) external payable auth returns (bytes32) {
        uint startGas = gasleft();
        Subaccount subaccount = positionStore.getSubaccount(order.trader);

        if (address(subaccount) == address(0)) {
            subaccount = positionStore.createSubaccount(order.trader);
        }

        MirrorPositionStore.RequestAdjustment memory request = MirrorPositionStore.RequestAdjustment({
            subaccount: subaccount,
            allocationKey: PositionUtils.getAllocationKey(order.collateralToken, order.trader),
            positionKey: GmxPositionUtils.getPositionKey(order.trader, order.market, order.collateralToken, order.isLong),
            traderSizeDelta: order.sizeDelta,
            traderCollateralDelta: order.collateralDelta,
            puppetSizeDelta: 0,
            puppetCollateralDelta: 0,
            transactionCost: startGas
        });

        MirrorPositionStore.Position memory mirrorPosition = positionStore.getPosition(request.positionKey);

        if (mirrorPosition.puppetSize == 0) {
            // TODO: large allocations might exceed blockspace, we possibly need to handle it in a separate process
            MirrorPositionStore.AllocationMatch memory allocation =
                positionStore.getAllocationMatchMap(request.allocationKey);

            if (allocation.trader != address(0)) {
                revert Error.RequestPositionLogic__ExistingRequestPending();
            }

            return matchUp(order, allocation, request);
        } else {
            return adjust(order, mirrorPosition, request);
        }
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }
}
