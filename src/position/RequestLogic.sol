// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

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

contract RequestLogic is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address callbackHandler;
        address gmxFundsReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
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

    PuppetStore immutable puppetStore;
    MirrorPositionStore immutable positionStore;

    Config public config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("RequestLogic", "1", _authority, _eventEmitter) {
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function submitOrder(
        MirrorPositionParams calldata order,
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

    function getTargetLeverage(
        uint size,
        uint collateral,
        uint sizeDeltaInUsd,
        uint collateralDelta,
        bool isIncrease
    ) internal pure returns (uint) {
        return isIncrease
            ? Precision.toBasisPoints(size + sizeDeltaInUsd, collateral + collateralDelta)
            : sizeDeltaInUsd < size ? Precision.toBasisPoints(size - sizeDeltaInUsd, collateral - collateralDelta) : 0;
    }

    function adjust(
        MirrorPositionParams calldata params,
        MirrorPositionStore.RequestAdjustment memory request,
        PuppetStore.Allocation memory allocation,
        Subaccount subaccount
    ) internal returns (bytes32 requestKey) {
        uint leverage = Precision.toBasisPoints(allocation.size, allocation.collateral);
        uint targetLeverage = getTargetLeverage(
            allocation.size, allocation.collateral, params.sizeDeltaInUsd, params.collateralDelta, params.isIncrease
        );

        uint deltaLeverage;

        if (targetLeverage > leverage) {
            deltaLeverage = targetLeverage - leverage;
            requestKey = submitOrder(params, subaccount, request, GmxPositionUtils.OrderType.MarketIncrease, 0);
            request.sizeDelta = allocation.size * deltaLeverage / targetLeverage;
        } else {
            deltaLeverage = leverage - targetLeverage;
            requestKey = submitOrder(params, subaccount, request, GmxPositionUtils.OrderType.MarketDecrease, 0);
            request.sizeDelta = allocation.size * deltaLeverage / leverage;
        }

        positionStore.setRequestAdjustment(requestKey, request);
        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + params.executionFee;

        logEvent(
            targetLeverage > leverage ? "RequestDecrease" : "RequestIncrease",
            abi.encode(
                subaccount,
                params.trader,
                params.allocationKey,
                params.sourceRequestKey,
                requestKey,
                request.matchKey,
                request.sizeDelta,
                request.transactionCost,
                deltaLeverage
            )
        );
    }

    function mirror(
        MirrorPositionParams calldata params
    ) external payable auth returns (bytes32 requestKey) {
        uint startGas = gasleft();

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(params.allocationKey);

        Subaccount subaccount = positionStore.getSubaccount(allocation.matchKey);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            subaccount = positionStore.createSubaccount(allocation.matchKey, params.trader);
        }

        MirrorPositionStore.RequestAdjustment memory request = MirrorPositionStore.RequestAdjustment({
            matchKey: allocation.matchKey,
            allocationKey: params.allocationKey,
            sourceRequestKey: params.sourceRequestKey,
            sizeDelta: 0,
            transactionCost: startGas
        });

        if (allocation.size == 0) {
            if (allocation.allocated == 0) {
                revert Error.RequestLogic__NoAllocation();
            }

            if (allocation.collateral > 0) revert Error.RequestLogic__PendingExecution();

            allocation.collateral = allocation.allocated;

            puppetStore.transferOut(params.collateralToken, config.gmxOrderVault, allocation.allocated);
            puppetStore.setAllocation(params.allocationKey, allocation);

            requestKey = submitOrder(
                params, subaccount, request, GmxPositionUtils.OrderType.MarketIncrease, allocation.allocated
            );

            request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + params.executionFee;
            positionStore.setRequestAdjustment(requestKey, request);

            logEvent(
                "RequestIncrease",
                abi.encode(
                    subaccount,
                    params.trader,
                    params.allocationKey,
                    params.sourceRequestKey,
                    requestKey,
                    request.matchKey,
                    request.sizeDelta,
                    request.transactionCost,
                    0
                )
            );
        } else {
            requestKey = adjust(params, request, allocation, subaccount);
        }
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(
        Config calldata _config
    ) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}