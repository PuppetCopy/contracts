// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGMXExchangeRouter} from "./../integrations/GMXV2/interfaces/IGMXExchangeRouter.sol";
import {GmxOrder} from "./utils/GmxOrder.sol";
import {IOrderCallbackReceiver} from "./interface/IOrderCallbackReceiver.sol";

contract PositionExecutor is Auth, IOrderCallbackReceiver {
    constructor(Authority _authority) Auth(address(0), _authority) {}

    function claimFundingFees(IGMXExchangeRouter gmxExchangeRouter, address[] memory _markets, address[] memory _tokens) external requiresAuth {
        gmxExchangeRouter.claimFundingFees(_markets, _tokens, address(this));
    }

    function afterOrderExecution(bytes32 requestKey, GmxOrder.Props calldata order, bytes memory /* logData */ ) external {
        // _proxyExeuctionCall(requestKey, false, isIncreaseOrder(order.numbers.orderType));
    }

    function afterOrderCancellation(bytes32 requestKey, GmxOrder.Props calldata order, bytes memory /* logData */ ) external {
        // _proxyExeuctionCall(requestKey, false, isIncreaseOrder(order.numbers.orderType));
    }

    /// @dev If an order is frozen, a Trader must call the ```cancelRequest``` function to cancel the order
    function afterOrderFrozen(bytes32 _requestKey, GmxOrder.Props calldata _order, bytes memory /* logData */ ) external {}

    function isIncreaseOrder(GmxOrder.OrderType orderType) internal pure returns (bool) {
        return orderType == GmxOrder.OrderType.MarketIncrease || orderType == GmxOrder.OrderType.LimitIncrease;
    }

    function getPositionKey(address account, address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }
}
