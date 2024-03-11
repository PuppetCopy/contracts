// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGMXExchangeRouter} from "./../integrations/GMXV2/interfaces/IGMXExchangeRouter.sol";
import {GmxOrder} from "./utils/GmxOrder.sol";

import {Router} from "../utilities/Router.sol";
import {PositionKey} from "./utils/PositionKey.sol";
import {TraderSubAccount} from "./utils/TraderSubAccount.sol";

import {PuppetStore} from "./store/PuppetStore.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubAccount(address trader, address subAccount);
    event PositionLogic__RequestIncreasePosition(
        address subAccount, bytes32 requestKey, address[] puppetList, uint[] puppetDepositDeltaList, uint depositDelta, uint sizeDelta
    );

    uint private constant BASIS_DIVISOR = 10000;

    struct RequestMatchPositionParams {
        address[] puppetList;
        address trader;
        address receiver;
        address market;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
    }

    struct AdjustPositionParams {
        address trader;
        address receiver;
        address market;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
    }

    struct PositionConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        Router router;
        address feeReceiver;
        IGMXExchangeRouter gmxExchangeRouter;
        IERC20 depositCollateralToken;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint minExecutionFee;
        uint maxCallbackGasLimit;
        uint minMatchTokenAmount;
        bytes32 referralCode;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createTraderProxy(PositionStore store, address trader) external requiresAuth {
        if (address(store.traderSubAccountMap(trader)) != address(0)) revert PositionLogic__TraderProxyAlreadyExists();

        TraderSubAccount proxy = new TraderSubAccount(store, trader);
        store.setTraderProxy(trader, proxy);

        emit PositionLogic__CreateTraderSubAccount(trader, address(proxy));
    }

    function requestMatchPosition(PositionConfig calldata config, RequestMatchPositionParams calldata reqMatchCallParams) external requiresAuth {
        PositionStore.MirrorPosition memory matchMp = config.positionStore.getMirrorPosition(
            getPositionKey(reqMatchCallParams.trader, reqMatchCallParams.market, address(config.depositCollateralToken), reqMatchCallParams.isLong)
        );

        if (matchMp.deposit > 0) {
            revert PositionLogic__PositionAlreadyExists();
        }

        if (reqMatchCallParams.puppetList.length > config.limitPuppetList) {
            revert PositionLogic__PuppetListLimitExceeded();
        }

        address subAccount = address(this);

        config.router.pluginTransfer(config.depositCollateralToken, reqMatchCallParams.trader, subAccount, reqMatchCallParams.collateralDelta);
        // SafeERC20.safeTransfer(config.depositCollateralToken, proxyAccount, reqMatchCallParams.collateralDelta);

        matchMp.deposit = reqMatchCallParams.collateralDelta;
        matchMp.leverage = reqMatchCallParams.sizeDelta * BASIS_DIVISOR / reqMatchCallParams.collateralDelta;

        for (uint i = 0; i < reqMatchCallParams.puppetList.length; i++) {
            address puppet = reqMatchCallParams.puppetList[i];
            PuppetStore.PuppetAccount memory puppetAccount = config.puppetStore.getPuppetAccount(puppet);
            PuppetStore.PuppetTraderSubscription memory subscription = config.puppetStore.getPuppetTraderSubscription(
                PositionKey.getSubscriptionsKey(puppet, reqMatchCallParams.trader, reqMatchCallParams.market, reqMatchCallParams.isLong)
            );

            uint amountIn = Math.min(puppetAccount.deposit * subscription.allowanceFactor / BASIS_DIVISOR, reqMatchCallParams.collateralDelta);
            bool isValidMatch = amountIn > config.minMatchTokenAmount && subscription.expiry > block.timestamp + 1 days
                || block.timestamp > puppetAccount.latestMatchTimestamp + puppetAccount.throttleMatchingPeriod;

            if (isValidMatch) {
                matchMp.puppetList[i] = puppet;
                matchMp.puppetDepositList[i] = amountIn;

                puppetAccount.deposit -= amountIn;
                puppetAccount.latestMatchTimestamp = block.timestamp;
                config.puppetStore.setPuppetAccount(puppet, puppetAccount);
            } else {
                matchMp.puppetList[i] = puppet;
                matchMp.puppetDepositList[i] = 0;
            }
        }

        SafeERC20.forceApprove(config.depositCollateralToken, address(config.gmxExchangeRouter), reqMatchCallParams.collateralDelta);

        bytes32 requestKey = config.gmxExchangeRouter.createOrder(
            GmxOrder.CreateOrderParams(
                GmxOrder.CreateOrderParamsAddresses(
                    reqMatchCallParams.receiver,
                    subAccount, // callbackContract
                    config.feeReceiver,
                    reqMatchCallParams.market,
                    address(config.depositCollateralToken),
                    new address[](0) // swapPath
                ),
                GmxOrder.CreateOrderParamsNumbers(
                    matchMp.size,
                    matchMp.deposit,
                    reqMatchCallParams.triggerPrice,
                    reqMatchCallParams.acceptablePrice,
                    reqMatchCallParams.executionFee,
                    config.maxCallbackGasLimit,
                    0 // _minOut - 0 since we are not swapping
                ),
                GmxOrder.MarketIncrease,
                GmxOrder.DecreasePositionSwapType.NoSwap,
                reqMatchCallParams.isLong,
                false, // shouldUnwrapNativeToken
                config.referralCode
            )
        );

        emit PositionLogic__RequestIncreasePosition(
            subAccount, requestKey, matchMp.puppetList, matchMp.puppetDepositList, matchMp.deposit, matchMp.size
        );
    }

    // increase position accounting

    // increase has more complex accounting than decrease, it requires to match the leverage of the position which may require additional funds
    // case scenario where a trader performs opening and adjusting a position which goes through a matching engine that selects Puppets,
    // this creates a Mirrored Position (MP) that combines Both trader and multiple matched puppets
    // based on portfolio rules a portion of puppets's deposit is used to match trader (collateral / size) ratio of the Mirrored Position

    // Glossary
    // MP: Mirror Position
    // DS: Delta Size
    // DC: Delta Collateral
    // PS: Position Size
    // PC: Position Collateral

    // Leverage Target (LT) = delta(Target Ratio, Current Ratio)
    // Puppet Size Target: LT * Position Size / Position Collateral

    // User                  DS      / DC         PS     / PC

    // 1. Open position at size: 1000 collateral: 100 (10x)
    // Trader                +1000   / +100       1000   / 100
    // Puppet A              +100    / +10        100    / 10
    // Puppet B              +100    / +10        100    / 10
    // MP                    +1200   / +120       1200   / 120

    // in the following cases Puppet B cannot add any funds (due to insolvency or expiry rule), to match MP leverage only size will be adjusted to
    // maintain the same leverage

    // 2.A Increase size: 100% Collateral: 50% (13.33x)
    // Trader                +1000   / +50        2000   / 150
    // Puppet A              +100    / +5         200    / 15
    // Puppet B (Reduce)     +33.3   / 0          133.3  / 10
    // MP                    +1100   / +55        2333.3 / 175

    // shift size from Puppet B to others

    // 2.B Increase size: 50%, Collateral: 100% 7.5x
    // Trader                +500    / +100       1500   / 200
    // Puppet A              +50     / +10        150    / 20
    // Puppet B (Reduce)     -25     / 0          75     / 10
    // MP                    +525    / +110       1725   / 230

    // size reduction is require in separated transaction

    // 2.C Increase size: 0, Collateral: 100% 5x
    // Trader                0       / +100       1000   / 200
    // Puppet A              0       / +10        100    / 20
    // Puppet B (Reduce)     -50*    / 0          50     / 10
    // MP                    -50*    / +110       1150   / 230

    function requestIncreasePosition(PositionConfig calldata config, AdjustPositionParams calldata reqIncreaseCallParams) external requiresAuth {
        PositionStore.MirrorPosition memory matchMp = config.positionStore.getMirrorPosition(
            getPositionKey(
                reqIncreaseCallParams.trader, reqIncreaseCallParams.market, address(config.depositCollateralToken), reqIncreaseCallParams.isLong
            )
        );

        if (matchMp.deposit == 0) {
            revert PositionLogic__PositionDoesNotExists();
        }

        address subAccount = address(this);

        config.router.pluginTransfer(config.depositCollateralToken, reqIncreaseCallParams.trader, subAccount, reqIncreaseCallParams.collateralDelta);
        // SafeERC20.safeTransfer(config.depositCollateralToken, proxyAccount, reqMatchCallParams.collateralDelta);

        matchMp.deposit = reqIncreaseCallParams.collateralDelta;
        matchMp.leverage = reqIncreaseCallParams.sizeDelta * BASIS_DIVISOR / reqIncreaseCallParams.collateralDelta;

        for (uint i = 0; i < matchMp.puppetList.length; i++) {
            address puppet = matchMp.puppetList[i];
            PuppetStore.PuppetAccount memory puppetAccount = config.puppetStore.getPuppetAccount(puppet);
            PuppetStore.PuppetTraderSubscription memory subscription = config.puppetStore.getPuppetTraderSubscription(
                PositionKey.getSubscriptionsKey(puppet, reqIncreaseCallParams.trader, reqIncreaseCallParams.market, reqIncreaseCallParams.isLong)
            );

            uint amountIn = matchMp.puppetDepositList[i];
            bool isValidIncrease = subscription.expiry > block.timestamp + 1 days;

            if (isValidIncrease) {
                matchMp.puppetList[i] = puppet;
                matchMp.puppetDepositList[i] = amountIn;
                // matchMp.deposit += amountIn;
                // matchMp.size += amountIn * matchMp.leverage / BASIS_DIVISOR;

                puppetAccount.deposit -= amountIn;
                puppetAccount.latestMatchTimestamp = block.timestamp;
                config.puppetStore.setPuppetAccount(puppet, puppetAccount);
            } else {
                matchMp.puppetList[i] = puppet;
                matchMp.puppetDepositList[i] = 0;
            }
        }

        SafeERC20.forceApprove(config.depositCollateralToken, address(config.gmxExchangeRouter), reqIncreaseCallParams.collateralDelta);

        bytes32 requestKey = config.gmxExchangeRouter.createOrder(
            GmxOrder.CreateOrderParams(
                GmxOrder.CreateOrderParamsAddresses(
                    reqIncreaseCallParams.receiver,
                    subAccount, // callbackContract
                    config.feeReceiver,
                    reqIncreaseCallParams.market,
                    address(config.depositCollateralToken),
                    new address[](0) // swapPath
                ),
                GmxOrder.CreateOrderParamsNumbers(
                    matchMp.size,
                    matchMp.deposit,
                    reqIncreaseCallParams.triggerPrice,
                    reqIncreaseCallParams.acceptablePrice,
                    reqIncreaseCallParams.executionFee,
                    config.maxCallbackGasLimit,
                    0 // _minOut - 0 since we are not swapping
                ),
                GmxOrder.OrderType.MarketIncrease,
                GmxOrder.DecreasePositionSwapType.NoSwap,
                reqIncreaseCallParams.isLong,
                false, // shouldUnwrapNativeToken
                config.referralCode
            )
        );

        emit PositionLogic__RequestIncreasePosition(
            subAccount, requestKey, new address[](0), matchMp.puppetDepositList, matchMp.deposit, matchMp.size
        );
    }

    function claimFundingFees(IGMXExchangeRouter gmxExchangeRouter, address[] memory _markets, address[] memory _tokens) external requiresAuth {
        gmxExchangeRouter.claimFundingFees(_markets, _tokens, address(this));
    }

    // function _proxyExeuctionCall(bytes32 requestKey, bool isSuccessful, bool isIncrease) internal {
    //     (address positionLogic, address callbackCaller) = store.mediator();

    //     if (msg.sender != callbackCaller) {
    //         revert SubAccountProxy__UnauthorizedCaller();
    //     }

    //     (bool success, bytes memory data) = positionLogic.call(abi.encodeWithSignature("callbackCaller()"));

    //     // It's important to check if the call was successful.
    //     require(success, "Call failed");

    //     // Decode the returned bytes data into an address.
    //     address res;
    //     assembly {
    //         res := mload(add(data, 20)) // Address is 20 bytes, data starts with 32 bytes length prefix
    //     }
    // }

    function getPositionKey(address account, address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }

    // function _getCreateOrderParams(
    //     EnvParams calldata envParams,
    //     AdjustPositionParams calldata adjustmentCallParams,
    //     PositionStore.MirrorPosition memory mirrorPosition,
    //     uint _executionFee,
    //     bool _isIncrease
    // ) internal view returns (GmxOrder.CreateOrderParams memory _params) {
    //     GmxOrder.CreateOrderParamsAddresses memory _addressesParams = GmxOrder.CreateOrderParamsAddresses(
    //         adjustmentCallParams.receiver, // receiver
    //         address(this), // callbackContract
    //         envParams.feeReceiver, // uiFeeReceiver
    //         adjustmentCallParams.market, // marketToken
    //         address(envParams.depositCollateralToken), // initialCollateralToken
    //         new address[](0) // swapPath
    //     );

    //     GmxOrder.CreateOrderParamsNumbers memory _numbersParams = GmxOrder.CreateOrderParamsNumbers(
    //         adjustmentCallParams.sizeDelta,
    //         mirrorPosition.deposit,
    //         adjustmentCallParams.triggerPrice,
    //         adjustmentCallParams.acceptablePrice,
    //         _executionFee,
    //         envParams.maxCallbackGasLimit,
    //         0 // _minOut - can be 0 since we are not swapping
    //     );

    //     _params = GmxOrder.CreateOrderParams(
    //         _addressesParams,
    //         _numbersParams,
    //         adjustmentCallParams.orderType,
    //         _isIncrease ? IGMXOrder.DecreasePositionSwapType.NoSwap : IGMXOrder.DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
    //         adjustmentCallParams.isLong,
    //         false, // shouldUnwrapNativeToken
    //         envParams.referralCode
    //     );
    // }

    error PositionLogic__PositionAlreadyExists();
    error PositionLogic__PositionDoesNotExists();
    error PositionLogic__PuppetListLimitExceeded();
    error PositionLogic__TraderProxyAlreadyExists();
}
