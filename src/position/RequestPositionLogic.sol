// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetStore} from "./../puppet/store/PuppetStore.sol";
import {Subaccount} from "./../shared/Subaccount.sol";
import {SubaccountStore} from "./../shared/store/SubaccountStore.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxDatastore} from "./interface/IGmxDataStore.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract RequestPositionLogic is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxOrderReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minimumMatchAmount;
        uint tokenTransferGasLimit;
    }

    SubaccountStore subaccountStore;
    PuppetStore puppetStore;
    PositionStore positionStore;
    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        SubaccountStore _subaccountStore,
        PuppetStore _puppetStore,
        PositionStore _positionStore,
        Config memory _config
    ) CoreContract("RequestPositionLogic", "1", _authority, _eventEmitter) {
        subaccountStore = _subaccountStore;
        puppetStore = _puppetStore;
        positionStore = _positionStore;

        _setConfig(_config);
    }

    function submitOrder(
        Subaccount subaccount,
        PositionStore.RequestAdjustment memory request,
        PositionUtils.OrderMirrorPosition calldata order,
        GmxPositionUtils.OrderType orderType
    ) internal returns (bytes32 requestKey) {
        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(
                config.gmxExchangeRouter.createOrder.selector,
                GmxPositionUtils.CreateOrderParams({
                    addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                        receiver: config.gmxOrderReciever,
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
        PositionStore.MirrorPosition memory mirrorPosition,
        PositionUtils.OrderMirrorPosition calldata order,
        PositionStore.RequestAdjustment memory request,
        Subaccount subaccount
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

            requestKey = submitOrder(subaccount, request, order, GmxPositionUtils.OrderType.MarketIncrease);
            logEvent("increase", abi.encode(order.trader, requestKey, request));
        } else {
            uint deltaLeverage = leverage - targetLeverage;
            request.puppetSizeDelta = mirrorPosition.traderSize * deltaLeverage / leverage;

            requestKey = submitOrder(subaccount, request, order, GmxPositionUtils.OrderType.MarketDecrease);
            logEvent("decrease", abi.encode(order.trader, requestKey, request));
        }
    }

    function matchUp(
        PositionStore.MirrorPosition memory mirrorPosition,
        PositionUtils.OrderMirrorPosition calldata order,
        PositionStore.RequestAdjustment memory request,
        Subaccount subaccount
    ) internal returns (bytes32 requestKey) {
        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory balanceList) =
            puppetStore.getBalanceAndActivityList(order.collateralToken, order.trader, mirrorPosition.puppetList);

        if (mirrorPosition.puppetList.length > config.limitPuppetList) {
            revert RequestPositionLogic__PuppetListLimitExceeded();
        }

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            // validate that puppet list calldata is sorted and has no duplicates
            if (i > 0) {
                if (mirrorPosition.puppetList[i - 1] > mirrorPosition.puppetList[i]) {
                    revert RequestPositionLogic__UnsortedPuppetList();
                }
                if (mirrorPosition.puppetList[i - 1] == mirrorPosition.puppetList[i]) {
                    revert RequestPositionLogic__DuplicatesInPuppetList();
                }
            }

            PuppetStore.Rule memory rule = ruleList[i];

            // puppet rule expired or not set
            if (
                rule.expiry > block.timestamp
                // current time is greater than  throttle activity period
                || activityList[i] + rule.throttleActivity < block.timestamp
                // has enough allowance or token allowance cap exists
                || balanceList[i] > config.minimumMatchAmount
            ) {
                // the lowest of either the allowance or the trader's deposit
                uint collateralDelta = Math.min(
                    Precision.applyBasisPoints(rule.allowanceRate, balanceList[i]),
                    order.collateralDelta // trader own deposit
                );
                mirrorPosition.puppetCollateral += collateralDelta;
                mirrorPosition.puppetSize += collateralDelta * order.sizeDelta / order.collateralDelta;

                balanceList[i] = collateralDelta;
            } else {
                balanceList[i] = 0;
            }

            activityList[i] = block.timestamp;
        }

        puppetStore.transferOutAndUpdateActivityList(
            order.collateralToken,
            config.gmxOrderVault,
            order.trader,
            block.timestamp,
            mirrorPosition.puppetList,
            balanceList
        );

        requestKey = submitOrder(subaccount, request, order, GmxPositionUtils.OrderType.MarketIncrease);
        positionStore.setMirrorPosition(requestKey, mirrorPosition);

        logEvent("match", abi.encode(order.trader, requestKey, request.positionKey, mirrorPosition));
    }

    function orderMirrorPosition(
        PositionUtils.OrderMirrorPosition calldata order,
        address[] calldata puppetList
    ) external payable auth returns (bytes32) {
        uint startGas = gasleft();
        Subaccount subaccount = subaccountStore.getSubaccount(order.trader);

        if (address(subaccount) == address(0)) {
            subaccount = subaccountStore.createSubaccount(order.trader);
        }

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            positionKey: GmxPositionUtils.getPositionKey(subaccount, order.market, order.collateralToken, order.isLong),
            traderSizeDelta: order.sizeDelta,
            traderCollateralDelta: order.collateralDelta,
            puppetSizeDelta: 0,
            puppetCollateralDelta: 0,
            transactionCost: startGas
        });

        PositionStore.MirrorPosition memory mirrorPosition = positionStore.getMirrorPosition(request.positionKey);

        if (mirrorPosition.puppetSize == 0) {
            if (mirrorPosition.trader != address(0)) {
                revert RequestPositionLogic__PendingRequestMatch();
            }

            mirrorPosition.trader = order.trader;
            mirrorPosition.puppetList = puppetList;
            mirrorPosition.collateralList = new uint[](puppetList.length);

            return matchUp(mirrorPosition, order, request, subaccount);
        } else {
            return adjust(mirrorPosition, order, request, subaccount);
        }
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }

    error RequestPositionLogic__PuppetListLimitExceeded();
    error RequestPositionLogic__PendingRequestMatch();
    error RequestPositionLogic__UnsortedPuppetList();
    error RequestPositionLogic__DuplicatesInPuppetList();
}
