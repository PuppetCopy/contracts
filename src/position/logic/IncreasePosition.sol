// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Router} from "src/utils/Router.sol";
import {Math} from "src/utils/Math.sol";

import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {PuppetUtils} from "./../util/PuppetUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

library IncreasePosition {
    event IncreasePosition__CreateTraderSubaccount(address trader, address subAccount);
    event IncreasePosition__RequestMatchPosition(address subAccount, bytes32 requestKey, address[] puppetList);
    event IncreasePosition__RequestIncreasePosition(
        address subAccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint collateralDelta, uint sizeDelta
    );

    function requestMatchPosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        address[] calldata puppetList
    ) external {
        uint puppetListLength = puppetList.length;

        if (callConfig.positionStore.getPendingTraderRequest(callPositionAdjustment.trader).requestKey != 0) {
            revert IncreasePosition__PendingRequestExists();
        }

        bytes32[] memory ruleKeyList = new bytes32[](puppetListLength);

        for (uint i = 0; i < puppetListLength; i++) {
            ruleKeyList[i] = PuppetUtils.getRuleKey(puppetList[i], callPositionAdjustment.trader);
        }

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            ruleKeyList: ruleKeyList,
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            positionKey: PositionUtils.getPositionKey(
                callPositionAdjustment.trader, callPositionAdjustment.market, callConfig.depositCollateralToken, callPositionAdjustment.isLong
                ),
            puppetList: puppetList,
            puppetCollateralDeltaList: new uint[](puppetListLength),
            collateralDelta: 0,
            sizeDelta: 0,
            leverage: callPositionAdjustment.sizeDelta * Math.BASIS_POINT_DIVISOR / callPositionAdjustment.collateralDelta
        });

        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(request.positionKey);

        if (matchMp.deposit > 0) {
            revert IncreasePosition__PositionAlreadyExists();
        }

        if (puppetListLength > callConfig.limitPuppetList) {
            revert IncreasePosition__PuppetListLimitExceeded();
        }

        PuppetStore.Account[] memory accountList = callConfig.puppetStore.getAccountList(puppetList);
        PuppetStore.Rule[] memory ruleList = callConfig.puppetStore.getRuleList(ruleKeyList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Account memory account = accountList[i];
            PuppetStore.Rule memory rule = ruleList[i];

            uint allowanceRate = account.deposit * rule.allowanceRate / Math.BASIS_POINT_DIVISOR;

            // the lowest of allowance or trader own deposit
            uint amountIn = Math.min(allowanceRate, callPositionAdjustment.collateralDelta);

            if ( // invalid match
                amountIn < callConfig.minMatchTokenAmount // minimum deposit
                    || rule.expiry < block.timestamp + callConfig.minMatchExpiryDuration // rule expired or about to expire
                    || account.latestMatchTimestamp + rule.throttle > block.timestamp // throttle in case of frequent matching
            ) {
                request.puppetCollateralDeltaList[i] = 0;
            } else {
                request.puppetCollateralDeltaList[i] = amountIn;
                request.sizeDelta += amountIn * request.leverage / Math.BASIS_POINT_DIVISOR;
                request.collateralDelta += amountIn;

                account.deposit -= amountIn;
                account.latestMatchTimestamp = block.timestamp;
            }

            accountList[i] = account;
        }

        callConfig.puppetStore.setAccountList(puppetList, accountList);

        emit IncreasePosition__RequestMatchPosition(address(this), request.requestKey, puppetList);

        _requestIncreasePosition(callConfig, callPositionAdjustment, request);
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

    in the following cases Puppet B cannot add any funds (due to insolvency, throttle or expiry rule), to match MP leverage only size will be adjusted
    to
    if size i greater than deposit, size can be adjust to match the leverage without adding funds

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
        if (callConfig.positionStore.getPendingTraderRequest(callPositionAdjustment.trader).requestKey != 0) {
            revert IncreasePosition__PendingRequestExists();
        }

        bytes32 positionKey = PositionUtils.getPositionKey(
            callPositionAdjustment.trader, callPositionAdjustment.market, callConfig.depositCollateralToken, callPositionAdjustment.isLong
        );
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);
        uint puppetListLength = matchMp.puppetList.length;

        bytes32[] memory ruleKeyList = new bytes32[](puppetListLength);

        for (uint i = 0; i < puppetListLength; i++) {
            ruleKeyList[i] = PuppetUtils.getRuleKey(matchMp.puppetList[i], callPositionAdjustment.trader);
        }

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            ruleKeyList: ruleKeyList,
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            positionKey: positionKey,
            puppetList: matchMp.puppetList,
            puppetCollateralDeltaList: new uint[](puppetListLength),
            collateralDelta: 0,
            sizeDelta: 0,
            leverage: callPositionAdjustment.sizeDelta * Math.BASIS_POINT_DIVISOR / callPositionAdjustment.collateralDelta
        });

        if (matchMp.deposit == 0) {
            revert IncreasePosition__PositionDoesNotExists();
        }

        PuppetStore.Account[] memory accountList = callConfig.puppetStore.getAccountList(matchMp.puppetList);
        PuppetStore.Rule[] memory ruleList = callConfig.puppetStore.getRuleList(ruleKeyList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Account memory account = accountList[i];
            PuppetStore.Rule memory rule = ruleList[i];

            uint amountIn = callPositionAdjustment.sizeDelta / matchMp.puppetDepositList[i];

            if ( // reduce mode
                amountIn > account.deposit // deposit is greater than required
                    || block.timestamp > rule.expiry // rule expired or about to expire
                    || account.latestMatchTimestamp + rule.throttle > block.timestamp // throttle in case of frequent matching
            ) {
                // request.puppetCollateralDeltaList[i] = 0;
                // continue;
            } else {
                request.puppetCollateralDeltaList[i] += amountIn;

                request.sizeDelta += amountIn * request.leverage / Math.BASIS_POINT_DIVISOR;
                request.collateralDelta += amountIn;

                account.deposit -= amountIn;
            }

            accountList[i] = account;
        }

        callConfig.puppetStore.setAccountList(matchMp.puppetList, accountList);

        _requestIncreasePosition(callConfig, callPositionAdjustment, request);

        // if (requestKey != request.requestKey) {
        //     revert IncreasePosition__InvalidRequestKey(requestKey, request.requestKey);
        // }
    }

    function _requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        PositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(callPositionAdjustment.trader);
        address subaccountAddress = subaccount.getAccount();

        if (subaccountAddress != callPositionAdjustment.trader) revert IncreasePosition__InvalidSubaccountCaller();

        subaccount.depositToken(callConfig.router, callConfig.depositCollateralToken, callPositionAdjustment.collateralDelta);
        SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subaccountAddress, request.collateralDelta);

        PositionUtils.CreateOrderParams memory params = PositionUtils.CreateOrderParams(
            PositionUtils.CreateOrderParamsAddresses(
                subaccountAddress,
                address(this), // callbackContract
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
        );

        bytes memory data = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params);

        (bool success, bytes memory returnData) = subaccount.execute(address(callConfig.gmxExchangeRouter), data);

        if (!success) {
            ErrorUtils.revertWithParsedMessage(returnData);
        }

        requestKey = abi.decode(returnData, (bytes32));

        callConfig.positionStore.setPendingTraderRequest(callPositionAdjustment.trader, request);

        emit IncreasePosition__RequestIncreasePosition(
            address(this), requestKey, request.puppetCollateralDeltaList, callPositionAdjustment.collateralDelta, callPositionAdjustment.sizeDelta
        );
    }

    error IncreasePosition__PositionAlreadyExists();
    error IncreasePosition__PositionDoesNotExists();
    error IncreasePosition__PuppetListLimitExceeded();
    error IncreasePosition__InvalidRequestKey(bytes32 requestKey, bytes32 expectedRequestKey);
    error IncreasePosition__InvalidSubaccountCaller();
    error IncreasePosition__PendingRequestExists();
}
