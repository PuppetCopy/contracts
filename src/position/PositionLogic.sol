// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "../utilities/Router.sol";
import {IGMXExchangeRouter} from "./../integrations/GMXV2/interfaces/IGMXExchangeRouter.sol";
import {IGMXOrder} from "./../integrations/GMXV2/interfaces/IGMXOrder.sol";
import {OrderUtils} from "./../integrations/GMXV2/libraries/OrderUtils.sol";

import {PositionKey} from "./utils/PositionKey.sol";

import {PuppetStore} from "./store/PuppetStore.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {TraderProxy} from "./TraderProxy.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderProxy(address trader, address proxy);

    struct AdjustPositionParams {
        address trader;
        address receiver;
        address market;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
        IGMXOrder.OrderType orderType;
    }

    struct EnvParams {
        PositionStore positionStore;
        PuppetStore puppetStore;
        Router router;
        address feeReceiver;
        IGMXExchangeRouter gmxExchangeRouter;
        IERC20 depositCollateralToken;
        uint puppetListLimit;
        uint adjustmentFeeFactor;
        uint minExecutionFee;
        uint maxCallbackGasLimit;
        uint minMatchTokenAmount;
        bytes32 referralCode;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createTraderProxy(PositionStore store, address trader) external requiresAuth {
        if (address(store.traderProxyMap(trader)) != address(0)) revert PositionLogic__TraderProxyAlreadyExists();

        TraderProxy proxy = new TraderProxy(store, trader);
        store.setTraderProxy(trader, proxy);

        emit PositionLogic__CreateTraderProxy(trader, address(proxy));
    }

    function requestOpenPosition(EnvParams calldata envParams, AdjustPositionParams calldata adjustmentParams, address[] calldata puppetList)
        external
        requiresAuth
    {
        address traderProxy = address(this);

        PositionStore.MirrorPosition memory mirrorPosition = envParams.positionStore.getMirrorPosition(adjustmentParams.trader);

        envParams.router.pluginTransfer(envParams.depositCollateralToken, adjustmentParams.trader, address(this), adjustmentParams.collateralDelta);

        uint proxyPostBalance = envParams.depositCollateralToken.balanceOf(traderProxy);

        address gmxExchangeRouterAddress = address(envParams.gmxExchangeRouter);
        SafeERC20.forceApprove(envParams.depositCollateralToken, gmxExchangeRouterAddress, adjustmentParams.collateralDelta);
        SafeERC20.safeTransfer(envParams.depositCollateralToken, address(this), adjustmentParams.collateralDelta);
        envParams.gmxExchangeRouter.createOrder(getCreateOrderParams(envParams, adjustmentParams, 0, true));

        uint totalAssets = envParams.depositCollateralToken.balanceOf(traderProxy);

        mirrorPosition.deposit = adjustmentParams.collateralDelta;

        uint matchCount = 0;
        for (uint i = 0; i < puppetList.length; i++) {
            address puppet = puppetList[i];
            bytes32 subscriptionKey =
                PositionKey.getSubscriptionsKey(puppet, adjustmentParams.trader, adjustmentParams.market, adjustmentParams.isLong);
            PuppetStore.PuppetTraderSubscription memory subscription = envParams.puppetStore.getPuppetTraderSubscription(subscriptionKey);

            uint amountIn = mirrorPosition.deposit * subscription.allowanceFactor / 10_000;

            if (amountIn < envParams.minMatchTokenAmount || subscription.expiry < block.timestamp + 1 days || subscription.allowanceFactor < 100) {
                continue;
            }

            mirrorPosition.puppetAccountList[matchCount] = proxyPostBalance;
            mirrorPosition.puppetCollateralList[matchCount] = amountIn;
            matchCount++;
        }

        if (puppetList.length > envParams.puppetListLimit) {
            if (mirrorPosition.deposit > 0) revert PositionLogic__PuppetListLimitExceeded();
        }
    }

    function requestIncreasePosition(PositionStore store) external requiresAuth {
        address traderProxy = address(this);
        PositionStore.MirrorPosition memory mp = store.getMirrorPosition(traderProxy);

        if (store.getMirrorPosition(traderProxy).deposit > 0) revert PositionLogic__PositionAlreadyExists();
    }

    function getCreateOrderParams(EnvParams calldata envParams, AdjustPositionParams calldata adjustmentParams, uint _executionFee, bool _isIncrease)
        internal
        view
        returns (OrderUtils.CreateOrderParams memory _params)
    {
        OrderUtils.CreateOrderParamsAddresses memory _addressesParams = OrderUtils.CreateOrderParamsAddresses(
            adjustmentParams.receiver, // receiver
            address(this), // callbackContract
            envParams.feeReceiver, // uiFeeReceiver
            adjustmentParams.market, // marketToken
            address(envParams.depositCollateralToken), // initialCollateralToken
            new address[](0) // swapPath
        );

        OrderUtils.CreateOrderParamsNumbers memory _numbersParams = OrderUtils.CreateOrderParamsNumbers(
            adjustmentParams.sizeDelta,
            adjustmentParams.collateralDelta,
            adjustmentParams.triggerPrice,
            adjustmentParams.acceptablePrice,
            _executionFee,
            envParams.maxCallbackGasLimit,
            0 // _minOut - can be 0 since we are not swapping
        );

        _params = OrderUtils.CreateOrderParams(
            _addressesParams,
            _numbersParams,
            adjustmentParams.orderType,
            _isIncrease ? IGMXOrder.DecreasePositionSwapType.NoSwap : IGMXOrder.DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
            adjustmentParams.isLong,
            false, // shouldUnwrapNativeToken
            envParams.referralCode
        );
    }

    error PositionLogic__PositionAlreadyExists();
    error PositionLogic__PuppetListLimitExceeded();
    error PositionLogic__TraderProxyAlreadyExists();
}
