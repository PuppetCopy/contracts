// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "../interface/IGmxDatastore.sol";

import {Router} from "src/utils/Router.sol";
import {Calc} from "src/utils/Calc.sol";

import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {PuppetUtils} from "./../util/PuppetUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

library IncreasePosition {
    event IncreasePosition__RequestMatchPosition(address trader, address subAccount, bytes32 requestKey, address[] puppetList);
    event IncreasePosition__RequestIncreasePosition(
        address trader, address subAccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint collateralDelta, uint sizeDelta
    );

    struct CallConfig {
        Router router;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        IERC20 depositCollateralToken;
        address feeReceiver;
        address trader;
        bytes32 referralCode;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint minMatchExpiryDuration;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
    }

    struct CallbackConfig {
        PositionStore positionStore;
        address gmxCallbackOperator;
        address caller;
    }

    function requestIncreasePosition(
        IncreasePosition.CallConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callIncreaseParams
    ) external {
        bytes32 positionKey =
            PositionUtils.getPositionKey(callConfig.trader, callIncreaseParams.market, callConfig.depositCollateralToken, callIncreaseParams.isLong);

        if (callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey).requestKey != 0) {
            revert IncreasePosition__PendingRequestExists();
        }

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(callConfig.trader);

        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);

        if (matchMp.size == 0) {
            IncreasePosition.requestMatch(callConfig, callIncreaseParams, positionKey, subaccount);
        } else {
            IncreasePosition.requestAdjust(callConfig, callIncreaseParams, positionKey, subaccount);
        }
    }

    function requestMatch(
        CallConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callMatchParams,
        bytes32 positionKey,
        Subaccount subaccount
    ) internal {
        uint puppetListLength = callMatchParams.puppetList.length;

        if (puppetListLength > callConfig.limitPuppetList) revert IncreasePosition__PuppetListLimitExceeded();

        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            sizeDelta: int(callMatchParams.sizeDelta),
            collateralDelta: callMatchParams.collateralDelta,
            targetLeverage: callMatchParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / callMatchParams.collateralDelta,
            puppetCollateralDeltaList: new uint[](puppetListLength)
        });

        bytes32[] memory ruleKeyList = new bytes32[](callMatchParams.puppetList.length);

        for (uint i = 0; i < callMatchParams.puppetList.length; i++) {
            ruleKeyList[i] = PuppetUtils.getRuleKey(callMatchParams.puppetList[i], callConfig.trader);
        }
        PuppetStore.Account[] memory accountList = callConfig.puppetStore.getAccountList(callMatchParams.puppetList);
        PuppetStore.Rule[] memory ruleList = callConfig.puppetStore.getRuleList(ruleKeyList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Account memory account = accountList[i];
            PuppetStore.Rule memory rule = ruleList[i];

            uint amountIn = rule.expiry < block.timestamp + callConfig.minMatchExpiryDuration // rule expired or about to expire
                || account.latestActivityTimestamp + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                ? 0
                : Math.min( // the lowest of either the allowance or the trader's deposit
                    account.deposit * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                    callMatchParams.collateralDelta // trader own deposit
                );

            if (amountIn > callConfig.minMatchTokenAmount) {
                request.puppetCollateralDeltaList[i] = amountIn;
                request.sizeDelta += int(amountIn * request.targetLeverage / Calc.BASIS_POINT_DIVISOR);
                request.collateralDelta += amountIn;

                account.deposit -= amountIn;
                account.latestActivityTimestamp = block.timestamp;
            } else {
                request.puppetCollateralDeltaList[i] = 0;
            }

            accountList[i] = account;
        }

        callConfig.puppetStore.setAccountList(callMatchParams.puppetList, accountList);

        emit IncreasePosition__RequestMatchPosition(callConfig.trader, address(subaccount), request.requestKey, callMatchParams.puppetList);

        _requestIncreasePosition(callConfig, callMatchParams, request, positionKey, subaccount);
    }

    /*

    increase adjustment case study
    increase require more complex accounting compared to decrease, matching the same leverage which may require additional funds

    Puppet Size Delta: (Position Size * (Leverage - Target Leverage) / Leverage)

    Columns: User, Size Delta / Collateral Delta, Position Size / Position Collateral

    1. Open 1000/100 10x

    Trader                +1000   / +100       1000   / 100
    -------------------------------------------------------
    Puppet A              +100    / +10        100    / 10
    Puppet B              +1000   / +100       1000   / 100
    MP 10x                +2100   / +210       2100   / 210

    in the following cases Puppet B cannot add any funds (due to insolvency, throttle or expiry), to match MP leverage only size will be adjusted
    to, if size is greater than deposit, size can be adjust to match the leverage without adding funds

    2.A Increase 100%/50%  20x, 3.33x delta
    adjust size but no collateral change

    Trader                +1000   / +50        2000   / 150
    -------------------------------------------------------
    Puppet A              +100    / +5         200    / 15
    Puppet B (Reduce)     +333.3  / 0          1333.3 / 100
    MP 13.33x             +1433.3 / +55        3533.3 / 265

    2.B Increase 50%/100% -2.5x delta
    shift size from Puppet B to others

    Trader                +500    / +100       1500   / 200
    -------------------------------------------------------
    Puppet A              +50     / +10        150    / 20
    Puppet B (Reduce)     -250    / 0          750    / 100
    MP 7.5x               +300    / +110       2400   / 320

    2.C Increase 10% / 100% 4.5x -4.5x delta
    if net size is less than deposit, MP size has to be reduced in additional transaction(*)
    requiring an additional transaction is not optimal beucase it forces adjustments to remain sequential, but it is necessary to match the leverage
    (is there a better solution?)

    Trader                +110    / +100       1100   / 200
    -------------------------------------------------------
    Puppet A              +10     / +10        110    / 20
    Puppet B (Reduce)     -450*   / 0          550   / 100
    MP 5.5x               -450*   / +110       1760  / 320


    */
    function requestAdjust(
        CallConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callIncreaseParams,
        bytes32 positionKey,
        Subaccount subaccount
    ) internal {
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);
        uint puppetListLength = matchMp.puppetList.length;

        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            sizeDelta: int(callIncreaseParams.sizeDelta),
            collateralDelta: callIncreaseParams.collateralDelta,
            targetLeverage: (matchMp.size + callIncreaseParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR
                / (matchMp.collateral + callIncreaseParams.collateralDelta),
            puppetCollateralDeltaList: new uint[](puppetListLength)
        });

        bytes32[] memory ruleKeyList = new bytes32[](puppetListLength);

        for (uint i = 0; i < puppetListLength; i++) {
            ruleKeyList[i] = PuppetUtils.getRuleKey(matchMp.puppetList[i], callConfig.trader);
        }
        PuppetStore.Account[] memory accountList = callConfig.puppetStore.getAccountList(matchMp.puppetList);
        PuppetStore.Rule[] memory ruleList = callConfig.puppetStore.getRuleList(ruleKeyList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Account memory account = accountList[i];
            PuppetStore.Rule memory rule = ruleList[i];

            uint amountIn = account.latestActivityTimestamp + rule.throttleActivity < block.timestamp // filter out frequent deposit activity
                || rule.expiry < block.timestamp // expired rule
                ? 0
                : callIncreaseParams.sizeDelta / matchMp.puppetDepositList[i];

            if (amountIn > 0) {
                request.puppetCollateralDeltaList[i] += amountIn;
                request.collateralDelta += amountIn;

                account.deposit -= Math.min(amountIn, account.deposit);
                account.latestActivityTimestamp = block.timestamp;
            } else {}

            request.sizeDelta +=
                int(amountIn * request.targetLeverage) * (int(matchMp.leverage) - int(request.targetLeverage)) / int(matchMp.leverage);

            accountList[i] = account;
        }

        callConfig.puppetStore.setAccountList(matchMp.puppetList, accountList);

        _requestIncreasePosition(callConfig, callIncreaseParams, request, positionKey, subaccount);

        // if (requestKey != request.requestKey) {
        //     revert IncreasePosition__InvalidRequestKey(requestKey, request.requestKey);
        // }
    }

    function executeIncreasePosition(
        CallbackConfig calldata callConfig,
        PositionStore.CallbackResponse calldata callbackResponse,
        PositionStore.RequestIncrease calldata request
    ) external {
        // if (callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey).requestKey != 0) {
        //     revert IncreasePosition__PendingRequestExists();
        // }
    }

    function _requestIncreasePosition(
        CallConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        PositionStore.RequestIncrease memory request,
        bytes32 positionKey,
        Subaccount subaccount
    ) internal returns (bytes32 requestKey) {
        address subaccountAddress = subaccount.getAccount();

        if (subaccountAddress != callConfig.trader) revert IncreasePosition__InvalidSubaccountCaller();

        subaccount.depositToken(callConfig.router, callConfig.depositCollateralToken, callPositionAdjustment.collateralDelta);
        SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), address(subaccount), request.collateralDelta);

        PositionUtils.CreateOrderParams memory params = PositionUtils.CreateOrderParams(
            PositionUtils.CreateOrderParamsAddresses(
                address(subaccount),
                address(this), // callbackContract
                callConfig.feeReceiver,
                callPositionAdjustment.market,
                address(callConfig.depositCollateralToken),
                new address[](0) // swapPath
            ),
            PositionUtils.CreateOrderParamsNumbers(
                request.sizeDelta > 0 ? uint(request.sizeDelta) : 0,
                request.collateralDelta,
                callPositionAdjustment.triggerPrice,
                callPositionAdjustment.acceptablePrice,
                callPositionAdjustment.executionFee,
                callConfig.callbackGasLimit,
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

        callConfig.positionStore.setPendingRequestIncreaseAdjustmentMap(positionKey, request);

        // Decrease position if sizeDelta < 0

        emit IncreasePosition__RequestIncreasePosition(
            callConfig.trader, subaccountAddress, requestKey, request.puppetCollateralDeltaList, request.collateralDelta, uint(request.sizeDelta)
        );
    }

    error IncreasePosition__PositionAlreadyExists();
    error IncreasePosition__PositionDoesNotExists();
    error IncreasePosition__PuppetListLimitExceeded();
    error IncreasePosition__InvalidRequestKey(bytes32 requestKey, bytes32 expectedRequestKey);
    error IncreasePosition__InvalidSubaccountCaller();
    error IncreasePosition__PendingRequestExists();
}
