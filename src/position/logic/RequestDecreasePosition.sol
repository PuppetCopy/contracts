// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";

import {Precision} from "./../../utils/Precision.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {TransferUtils} from "./../../utils/TransferUtils.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";

import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "../../shared/store/SubaccountStore.sol";

library RequestDecreasePosition {
    event RequestDecreasePosition__Request(
        PositionStore.RequestAdjustment request, address subaccount, bytes32 requestKey, uint traderSizeDelta, uint traderCollateralDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address positionRouterAddress;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint tokenTransferGasLimit;
    }

    struct TraderCallParams {
        address market;
        IERC20 collateralToken;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
    }

    struct CallParams {
        PositionStore.RequestAdjustment request;
        address subaccount;
    }

    function decrease(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address from) internal {
        uint startGas = gasleft();
        address subaccount = address(callConfig.subaccountStore.getSubaccount(from));

        if (subaccount == address(0)) revert RequestDecreasePosition__SubaccountNotFound(from);

        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(subaccount, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            trader: from,
            puppetCollateralDeltaList: new uint[](mirrorPosition.puppetList.length),
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta,
            transactionCost: startGas
        });

        CallParams memory callParams = CallParams({
            request: request, //
            subaccount: subaccount
        });

        uint reductionMultiplier = Precision.toFactor(traderCallParams.collateralDelta, mirrorPosition.collateral);

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            request.puppetCollateralDeltaList[i] -=
                request.puppetCollateralDeltaList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;
        }

        bytes32 requestKey = _decrease(callConfig, traderCallParams, callParams, request);

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;

        callConfig.positionStore.setRequestAdjustment(requestKey, request);

        emit RequestDecreasePosition__Request(request, subaccount, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta);
    }

    function _decrease(
        CallConfig memory callConfig,
        TraderCallParams calldata traderCallParams,
        CallParams memory callParams,
        PositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.positionRouterAddress,
                callbackContract: callConfig.positionRouterAddress,
                uiFeeReceiver: address(0),
                market: traderCallParams.market,
                initialCollateralToken: traderCallParams.collateralToken,
                swapPath: new address[](0)
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: request.collateralDelta,
                sizeDeltaUsd: request.sizeDelta,
                triggerPrice: traderCallParams.triggerPrice,
                acceptablePrice: traderCallParams.acceptablePrice,
                executionFee: traderCallParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        TransferUtils.depositAndSendWnt(
            callConfig.wnt,
            address(callConfig.positionStore),
            callConfig.tokenTransferGasLimit,
            callConfig.gmxOrderVault,
            traderCallParams.executionFee + traderCallParams.collateralDelta
        );

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(callParams.subaccount).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    error RequestDecreasePosition__SubaccountNotFound(address from);
}
