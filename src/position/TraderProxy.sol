// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
// import {IGMXOrder} from "./../integrations/GMXV2/interfaces/IGMXOrder.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract TraderProxy is Proxy {
    PositionStore store;
    address private _currentImplementation;
    address public trader;

    constructor(PositionStore _store, address _trader) {
        store = _store;
        trader = _trader;
    }

    function _implementation() internal view override returns (address) {
        return store.positionLogicImplementation();
    }

    // Add a receive function to handle plain ether transfers
    receive() external payable {
        // If there's no function selector (i.e., no data), we simply delegate the call to the implementation.
        // This requires the implementation to have a receive function.
        _fallback();
    }
    // function claimFundingFees(address[] memory _markets, address[] memory _tokens) external onlyOrchestrator {
    //     GMXV2RouteHelper.gmxExchangeRouter(dataStore).claimFundingFees(_markets, _tokens, CommonHelper.trader(dataStore, address(this)));
    // }

    // function afterOrderExecution(bytes32 _requestKey, IGMXOrder.Props calldata _order, bytes memory /* logData */ ) external {
    //     _proxyExeuctionCall(_requestKey, false, isIncreaseOrder(_order.numbers.orderType));
    // }

    // function afterOrderCancellation(bytes32 _requestKey, IGMXOrder.Props calldata _order, bytes memory /* logData */ ) external {
    //     _proxyExeuctionCall(_requestKey, false, isIncreaseOrder(_order.numbers.orderType));
    // }

    // /// @dev If an order is frozen, a Trader must call the ```cancelRequest``` function to cancel the order
    // function afterOrderFrozen(bytes32 _requestKey, IGMXOrder.Props calldata _order, bytes memory /* logData */ ) external {}

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

    // function isIncreaseOrder(IGMXOrder.OrderType orderType) internal pure returns (bool) {
    //     return orderType == IGMXOrder.OrderType.MarketIncrease || orderType == IGMXOrder.OrderType.LimitIncrease;
    // }

    // error SubAccountProxy__UnauthorizedCaller();
}
