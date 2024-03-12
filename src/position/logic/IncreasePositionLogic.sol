// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Router} from "src/utils/Router.sol";
import {Math} from "src/utils/Math.sol";

import {PositionUtils} from "../utils/PositionUtils.sol";
import {PositionKey} from "../utils/PositionKey.sol";
import {TraderSubAccount} from "../utils/TraderSubAccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";

library IncreasePositionLogic {
    event IncreasePositionLogic__CreateTraderSubAccount(address trader, address subAccount);
    event IncreasePositionLogic__RequestMatchPosition(address subAccount, bytes32 requestKey, address[] puppetList);
    event IncreasePositionLogic__RequestIncreasePosition(
        address subAccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint collateralDelta, uint sizeDelta
    );

    function createTraderSubAccount(PositionStore store, address trader) external {
        if (address(store.traderSubAccountMap(trader)) != address(0)) revert IncreasePositionLogic__TraderProxyAlreadyExists();

        TraderSubAccount proxy = new TraderSubAccount(store, trader);
        store.setTraderProxy(trader, proxy);

        emit IncreasePositionLogic__CreateTraderSubAccount(trader, address(proxy));
    }

    function requestMatchPosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        address[] calldata puppetList
    ) external {
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(
            PositionUtils.getPositionKey(
                callPositionAdjustment.trader,
                callPositionAdjustment.market,
                address(callConfig.depositCollateralToken),
                callPositionAdjustment.isLong
            )
        );

        if (matchMp.deposit > 0) {
            revert IncreasePositionLogic__PositionAlreadyExists();
        }

        if (puppetList.length > callConfig.limitPuppetList) {
            revert IncreasePositionLogic__PuppetListLimitExceeded();
        }

        PositionStore.RequestMirrorPositionAdjustment memory request = PositionStore.RequestMirrorPositionAdjustment({
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            puppetList: puppetList,
            puppetCollateralDeltaList: new uint[](puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            leverage: callPositionAdjustment.sizeDelta * Math.BASIS_POINT_DIVISOR / callPositionAdjustment.collateralDelta
        });

        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            PuppetStore.PuppetAccount memory puppetAccount = callConfig.puppetStore.getPuppetAccount(puppet);
            PuppetStore.PuppetTraderSubscription memory subscription = callConfig.puppetStore.getPuppetTraderSubscription(
                PositionKey.getSubscriptionsKey(puppet, callPositionAdjustment.trader, callPositionAdjustment.market, callPositionAdjustment.isLong)
            );

            uint allowanceRate = puppetAccount.deposit * subscription.allowanceRate / Math.BASIS_POINT_DIVISOR;

            // the lowest of allowance or trader own deposit
            uint amountIn = Math.min(allowanceRate, callPositionAdjustment.collateralDelta);
            bool isInvalidMatch = amountIn < callConfig.minMatchTokenAmount && subscription.expiry < block.timestamp + 1 days
                || puppetAccount.latestMatchTimestamp + puppetAccount.throttleMatchingPeriod > block.timestamp;

            if (isInvalidMatch) {
                request.puppetCollateralDeltaList[i] = 0;
                continue;
            }

            request.puppetCollateralDeltaList[i] = amountIn;
            request.sizeDelta -= amountIn * request.leverage / Math.BASIS_POINT_DIVISOR;
            request.collateralDelta -= amountIn;

            puppetAccount.deposit -= amountIn;

            puppetAccount.latestMatchTimestamp = block.timestamp;
            callConfig.puppetStore.setPuppetAccount(puppet, puppetAccount);
        }

        bytes32 requestKey = _requestIncreasePosition(callConfig, callPositionAdjustment, request, address(this));

        emit IncreasePositionLogic__RequestMatchPosition(address(this), requestKey, puppetList);
        emit IncreasePositionLogic__RequestIncreasePosition(
            address(this), requestKey, request.puppetCollateralDeltaList, callPositionAdjustment.collateralDelta, callPositionAdjustment.sizeDelta
        );
    }

    /*

    increase position accounting
    increase has more complex accounting than decrease, it requires to match the leverage of the position which may require additional funds
    case scenario where a trader performs opening and adjusting a position which goes through a matching engine that selects Puppets,
    this creates a Mirrored Position (MP) that combines Both trader and multiple matched puppets
    based on portfolio rules a portion of puppets's deposit is used to match trader (collateral / size) ratio of the Mirrored Position

    Glossary
    MP: Mirror Position
    DS: Delta Size
    DC: Delta Collateral
    PS: Position Size
    PC: Position Collateral

    Leverage Target (LT) = delta(Target Ratio, Current Ratio)
    Puppet Size Target: LT * Position Size / Position Collateral

    User                  DS      / DC         PS     / PC

    1. Open position at size: 1000 collateral: 100 (10x)
    Trader                +1000   / +100       1000   / 100
    Puppet A              +100    / +10        100    / 10
    Puppet B              +100    / +10        100    / 10
    MP                    +1200   / +120       1200   / 120

    in the following cases Puppet B cannot add any funds (due to insolvency or expiry rule), to match MP leverage only size will be adjusted to
    maintain the same leverage

    2.A Increase size: 100% Collateral: 50% (13.33x)
    Trader                +1000   / +50        2000   / 150
    Puppet A              +100    / +5         200    / 15
    Puppet B (Reduce)     +33.3   / 0          133.3  / 10
    MP                    +1100   / +55        2333.3 / 175

    shift size from Puppet B to others

    2.B Increase size: 50%, Collateral: 100% 7.5x
    Trader                +500    / +100       1500   / 200
    Puppet A              +50     / +10        150    / 20
    Puppet B (Reduce)     -25     / 0          75     / 10
    MP                    +525    / +110       1725   / 230

    size reduction is require in separated transaction

    2.C Increase size: 0, Collateral: 100% 5x
    Trader                0       / +100       1000   / 200
    Puppet A              0       / +10        100    / 20
    Puppet B (Reduce)     -50*    / 0          50     / 10
    MP                    -50*    / +110       1150   / 230
    */
    function requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment
    ) external {
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(
            PositionUtils.getPositionKey(
                callPositionAdjustment.trader,
                callPositionAdjustment.market,
                address(callConfig.depositCollateralToken),
                callPositionAdjustment.isLong
            )
        );

        if (matchMp.deposit == 0) {
            revert IncreasePositionLogic__PositionDoesNotExists();
        }

        PositionStore.RequestMirrorPositionAdjustment memory request = PositionStore.RequestMirrorPositionAdjustment({
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            puppetList: matchMp.puppetList,
            puppetCollateralDeltaList: new uint[](matchMp.puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            leverage: callPositionAdjustment.sizeDelta * Math.BASIS_POINT_DIVISOR / callPositionAdjustment.collateralDelta
        });

        for (uint i = 0; i < matchMp.puppetList.length; i++) {
            address puppet = matchMp.puppetList[i];

            PuppetStore.PuppetTraderSubscription memory subscription = callConfig.puppetStore.getPuppetTraderSubscription(
                PositionKey.getSubscriptionsKey(puppet, callPositionAdjustment.trader, callPositionAdjustment.market, callPositionAdjustment.isLong)
            );

            uint positionDeposit = matchMp.puppetDepositList[i];
            uint amountIn = callPositionAdjustment.sizeDelta / positionDeposit;
            bool isReduceMode = amountIn < callConfig.minMatchTokenAmount && subscription.expiry < block.timestamp + 1 days;

            if (isReduceMode) {} else {
                request.puppetCollateralDeltaList[i] += amountIn;

                request.sizeDelta -= amountIn * request.leverage / Math.BASIS_POINT_DIVISOR;
                request.collateralDelta -= amountIn;
            }
        }

        bytes32 requestKey = _requestIncreasePosition(callConfig, callPositionAdjustment, request, address(this));

        emit IncreasePositionLogic__RequestIncreasePosition(
            address(this), requestKey, request.puppetCollateralDeltaList, callPositionAdjustment.collateralDelta, callPositionAdjustment.sizeDelta
        );
    }

    function _requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        PositionStore.RequestMirrorPositionAdjustment memory request,
        address subAccount
    ) internal returns (bytes32 requestKey) {
        // callConfig.positionStore.setRequestMirrorPositionAdjustment(
        //     ,
        //     request
        // );

        // setRequestMirrorPositionAdjustment

        SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subAccount, request.collateralDelta);
        callConfig.router.pluginTransfer(
            callConfig.depositCollateralToken, callPositionAdjustment.trader, subAccount, callPositionAdjustment.collateralDelta
        );
        SafeERC20.forceApprove(callConfig.depositCollateralToken, address(callConfig.gmxExchangeRouter), request.collateralDelta);

        requestKey = callConfig.gmxExchangeRouter.createOrder(
            PositionUtils.CreateOrderParams(
                PositionUtils.CreateOrderParamsAddresses(
                    subAccount,
                    subAccount, // callbackContract
                    callConfig.feeReceiver,
                    callPositionAdjustment.market,
                    address(callConfig.depositCollateralToken),
                    new address[](0) // swapPath
                ),
                PositionUtils.CreateOrderParamsNumbers(
                    request.sizeDelta + callPositionAdjustment.sizeDelta,
                    request.collateralDelta + callPositionAdjustment.collateralDelta,
                    callPositionAdjustment.triggerPrice,
                    callPositionAdjustment.acceptablePrice,
                    callPositionAdjustment.executionFee,
                    callConfig.maxCallbackGasLimit,
                    0 // _minOut - 0 since we are not swapping
                ),
                PositionUtils.OrderType.MarketIncrease,
                PositionUtils.DecreasePositionSwapType.NoSwap,
                callPositionAdjustment.isLong,
                false, // shouldUnwrapNativeToken
                callConfig.referralCode
            )
        );
    }

    error IncreasePositionLogic__PositionAlreadyExists();
    error IncreasePositionLogic__PositionDoesNotExists();
    error IncreasePositionLogic__PuppetListLimitExceeded();
    error IncreasePositionLogic__TraderProxyAlreadyExists();
}
