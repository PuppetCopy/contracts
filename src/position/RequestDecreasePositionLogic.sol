// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

import {Subaccount} from "./../shared/Subaccount.sol";
import {SubaccountStore} from "./../shared/store/SubaccountStore.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract RequestDecreasePositionLogic is CoreContract {
    event RequestDecreasePositionLogic__SetConfig(uint timestamp, Config config);

    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address gmxOrderReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
    }

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("RequestDecreasePositionLogic", "1", _authority, _eventEmitter) {
        _setConfig(_config);
    }

    function traderDecrease(PositionUtils.TraderCallParams calldata traderCallParams, address user) external auth {
        uint startGas = gasleft();

        Subaccount subaccount = config.subaccountStore.getSubaccount(user);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            revert RequestDecreasePositionLogic__SubaccountNotFound(traderCallParams.account);
        }

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            subaccountAddress, //
            traderCallParams.market,
            traderCallParams.collateralToken,
            traderCallParams.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = config.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            positionKey: positionKey,
            collateralDeltaList: new uint[](mirrorPosition.puppetList.length),
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta,
            transactionCost: startGas
        });

        decrease(request, mirrorPosition, traderCallParams, subaccount, subaccountAddress);
    }

    function proxyDecrease(PositionUtils.TraderCallParams calldata traderCallParams, address user) external auth {
        uint startGas = gasleft();

        Subaccount subaccount = config.subaccountStore.getSubaccount(user);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            revert RequestDecreasePositionLogic__SubaccountNotFound(traderCallParams.account);
        }

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            subaccountAddress, //
            traderCallParams.market,
            traderCallParams.collateralToken,
            traderCallParams.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = config.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            positionKey: positionKey,
            collateralDeltaList: new uint[](mirrorPosition.puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            transactionCost: startGas
        });

        decrease(request, mirrorPosition, traderCallParams, subaccount, subaccountAddress);
    }

    function decrease(
        PositionStore.RequestAdjustment memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        PositionUtils.TraderCallParams calldata traderCallParams,
        Subaccount subaccount,
        address subaccountAddress
    ) internal {
        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            request.collateralDeltaList[i] -=
                request.collateralDeltaList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;
        }

        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: config.gmxOrderReciever,
                callbackContract: config.gmxOrderReciever,
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
                callbackGasLimit: config.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: config.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(config.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        bytes32 requestKey = abi.decode(orderReturnData, (bytes32));

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;

        config.positionStore.setRequestAdjustment(requestKey, request);

        eventEmitter.log(
            "RequestDecreasePositionLogic__Decrease",
            abi.encode(
                traderCallParams.account,
                subaccountAddress,
                requestKey,
                request.positionKey,
                traderCallParams.collateralDelta
            )
        );
    }

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit RequestDecreasePositionLogic__SetConfig(block.timestamp, _config);
    }

    error RequestDecreasePositionLogic__SubaccountNotFound(address user);
}
