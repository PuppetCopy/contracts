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
import {IGmxDatastore} from "./interface/IGmxDatastore.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract RequestPositionLogic is CoreContract {
    // bytes32 constant GMX_DATASTORE_SIZE_IN_USD = keccak256(abi.encode("SIZE_IN_USD"));
    // bytes32 constant GMX_DATASTORE_COLLATERAL_AMOUNT = keccak256(abi.encode("COLLATERAL_AMOUNT"));

    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address callbackHandler;
        address gmxFundsReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
    }

    struct RequestMirrorPosition {
        IERC20 collateralToken;
        bytes32 originRequestKey;
        bytes32 allocationKey;
        address trader;
        address market;
        bool isIncrease;
        bool isLong;
        GmxPositionUtils.OrderType orderType;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
    }

    PuppetStore immutable puppetStore;
    MirrorPositionStore immutable positionStore;

    Config public config;

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
        RequestMirrorPosition calldata order,
        Subaccount subaccount,
        MirrorPositionStore.RequestAdjustment memory request,
        GmxPositionUtils.OrderType orderType,
        uint collateralDelta
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
                        sizeDeltaUsd: request.sizeDelta,
                        initialCollateralDeltaAmount: collateralDelta,
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
    }

    function adjust(
        RequestMirrorPosition calldata order,
        MirrorPositionStore.RequestAdjustment memory request,
        PuppetStore.Allocation memory allocation,
        Subaccount subaccount
    ) internal returns (bytes32 requestKey) {
        // uint traderSize = getDatstoreValue(request.traderPositionKey, GMX_DATASTORE_SIZE_IN_USD);
        // uint traderCollateral = getDatstoreValue(request.traderPositionKey, GMX_DATASTORE_COLLATERAL_AMOUNT);
        uint leverage = Precision.toBasisPoints(allocation.size, allocation.collateral);
        uint targetLeverage = order.isIncrease
            ? Precision.toBasisPoints(allocation.size + order.sizeDeltaInUsd, allocation.collateral + order.collateralDelta)
            : order.sizeDeltaInUsd < allocation.size
                ? Precision.toBasisPoints(allocation.size - order.sizeDeltaInUsd, allocation.collateral - order.collateralDelta)
                : 0;

        if (targetLeverage > leverage) {
            uint deltaLeverage = targetLeverage - leverage;
            request.sizeDelta = allocation.size * deltaLeverage / targetLeverage;
            requestKey = submitOrder(order, subaccount, request, GmxPositionUtils.OrderType.MarketIncrease, 0);

            request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + order.executionFee;
            positionStore.setRequestAdjustment(requestKey, request);

            logEvent(
                "RequestIncrease",
                abi.encode(
                    order.originRequestKey,
                    requestKey,
                    request.traderPositionKey,
                    request.positionKey,
                    request.sizeDelta,
                    request.transactionCost,
                    deltaLeverage
                )
            );
        } else {
            uint deltaLeverage = leverage - targetLeverage;
            request.sizeDelta = allocation.size * deltaLeverage / leverage;

            requestKey = submitOrder(order, subaccount, request, GmxPositionUtils.OrderType.MarketDecrease, 0);

            request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + order.executionFee;
            positionStore.setRequestAdjustment(requestKey, request);

            logEvent(
                "RequestDecrease",
                abi.encode(
                    order.originRequestKey,
                    requestKey,
                    request.traderPositionKey,
                    request.positionKey,
                    request.sizeDelta,
                    request.transactionCost,
                    deltaLeverage
                )
            );
        }
    }

    function mirror(RequestMirrorPosition calldata order) external payable auth returns (bytes32 requestKey) {
        uint startGas = gasleft();

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(order.allocationKey);

        Subaccount subaccount = positionStore.getSubaccount(allocation.matchKey);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            subaccount = positionStore.createSubaccount(allocation.matchKey, order.trader);
        }

        MirrorPositionStore.RequestAdjustment memory request = MirrorPositionStore.RequestAdjustment({
            matchKey: allocation.matchKey,
            positionKey: GmxPositionUtils.getPositionKey(
                subaccountAddress, order.market, order.collateralToken, order.isLong
                ),
            traderRequestKey: order.originRequestKey,
            traderPositionKey: GmxPositionUtils.getPositionKey(
                order.trader, order.market, order.collateralToken, order.isLong
                ),
            sizeDelta: 0,
            transactionCost: startGas
        });

        if (allocation.size == 0) {
            if (allocation.allocated == 0) {
                revert Error.RequestPositionLogic__NoAllocation();
            }

            if (allocation.collateral > 0) revert Error.RequestPositionLogic__PendingExecution();

            allocation.collateral = allocation.allocated;

            puppetStore.transferOut(order.collateralToken, config.gmxOrderVault, allocation.allocated);
            puppetStore.setAllocation(order.allocationKey, allocation);

            requestKey =
                submitOrder(order, subaccount, request, GmxPositionUtils.OrderType.MarketIncrease, allocation.allocated);

            request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + order.executionFee;
            positionStore.setRequestAdjustment(requestKey, request);

            logEvent(
                "RequestIncrease",
                abi.encode(
                    order.originRequestKey,
                    requestKey,
                    request.traderPositionKey,
                    request.positionKey,
                    request.sizeDelta,
                    request.transactionCost,
                    0
                )
            );
        } else {
            requestKey = adjust(order, request, allocation, subaccount);
        }
    }

    // function getDatstoreValue(bytes32 positionKey, bytes32 prop) internal view returns (uint) {
    //     return config.gmxDatastore.getUint(keccak256(abi.encode(positionKey, prop)));
    // }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
