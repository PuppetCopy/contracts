// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {WNT} from "./../utils/WNT.sol";

import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {PositionUtils} from "./util/PositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";

import {IncreasePosition} from "./logic/IncreasePosition.sol";
import {SubaccountStore} from "./store/SubaccountStore.sol";

contract PositionLogic is Auth, IGmxOrderCallbackReceiver {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createTraderSubaccount(WNT _wnt, SubaccountStore store, address trader) external {
        if (address(store.getSubaccount(trader)) == trader) revert PositionLogic__TraderProxyAlreadyExists();

        Subaccount subaccount = new Subaccount(_wnt, store, trader);
        store.setSubaccount(trader, subaccount);

        emit PositionLogic__CreateTraderSubaccount(trader, address(subaccount));
    }

    function requestMatchPosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        address[] calldata puppetList
    ) external requiresAuth {
        IncreasePosition.requestMatchPosition(callConfig, callPositionAdjustment, puppetList);
    }

    function requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment
    ) external requiresAuth {
        IncreasePosition.requestIncreasePosition(callConfig, callPositionAdjustment);
    }

    function afterOrderExecution(bytes32 key, PositionUtils.Props memory order, bytes memory eventData) external {
        // IncreasePosition.executedIncreasePosition(callConfig, callPositionAdjustment);
    }

    function afterOrderCancellation(bytes32 key, PositionUtils.Props memory order, bytes memory eventData) external {}

    function afterOrderFrozen(bytes32 key, PositionUtils.Props memory order, bytes memory eventData) external {}

    function claimFundingFees(IGmxExchangeRouter gmxExchangeRouter, address[] memory _markets, address[] memory _tokens) external requiresAuth {
        gmxExchangeRouter.claimFundingFees(_markets, _tokens, address(this));
    }

    function isIncreaseOrder(PositionUtils.OrderType orderType) internal pure returns (bool) {
        return orderType == PositionUtils.OrderType.MarketIncrease || orderType == PositionUtils.OrderType.LimitIncrease;
    }

    error PositionLogic__TraderProxyAlreadyExists();
}
