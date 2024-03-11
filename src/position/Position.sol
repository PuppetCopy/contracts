// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./utils/IGmxExchangeRouter.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {IOrderCallbackReceiver} from "./interface/IOrderCallbackReceiver.sol";

import {PositionStore} from "./store/PositionStore.sol";
import {IncreasePositionLogic} from "./logic/IncreasePositionLogic.sol";

contract Position is Auth, IOrderCallbackReceiver {
    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createTraderProxy(PositionStore store, address trader) external {
        IncreasePositionLogic.createTraderProxy(store, trader);
    }

    function requestMatchPosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        address[] calldata puppetList
    ) external requiresAuth {
        IncreasePositionLogic.requestMatchPosition(callConfig, callPositionAdjustment, puppetList);
    }

    function requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment
    ) external requiresAuth {
        IncreasePositionLogic.requestIncreasePosition(callConfig, callPositionAdjustment);
    }

    function claimFundingFees(IGmxExchangeRouter gmxExchangeRouter, address[] memory _markets, address[] memory _tokens) external requiresAuth {
        gmxExchangeRouter.claimFundingFees(_markets, _tokens, address(this));
    }

    function afterOrderExecution(bytes32 requestKey, PositionUtils.Props calldata order, bytes memory /* logData */ ) external {
        // _proxyExeuctionCall(requestKey, false, isIncreaseOrder(order.numbers.orderType));
    }

    function afterOrderCancellation(bytes32 requestKey, PositionUtils.Props calldata order, bytes memory /* logData */ ) external {
        // _proxyExeuctionCall(requestKey, false, isIncreaseOrder(order.numbers.orderType));
    }

    /// @dev If an order is frozen, a Trader must call the ```cancelRequest``` function to cancel the order
    function afterOrderFrozen(bytes32 _requestKey, PositionUtils.Props calldata _order, bytes memory /* logData */ ) external {}

    function isIncreaseOrder(PositionUtils.OrderType orderType) internal pure returns (bool) {
        return orderType == PositionUtils.OrderType.MarketIncrease || orderType == PositionUtils.OrderType.LimitIncrease;
    }

    function getPositionKey(address account, address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }
}
