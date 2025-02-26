// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";

contract MockGmxExchangeRouter is IGmxExchangeRouter {
    // This mapping can be used to track created orders for testing purposes
    mapping(bytes32 => GmxPositionUtils.CreateOrderParams) public orders;
    uint public orderCount;

    // Other functions from the interface can be left unimplemented for brevity
    // ...

    function createOrder(GmxPositionUtils.CreateOrderParams calldata params)
        external
        payable
        override
        returns (bytes32)
    {
        // Increment the order count to simulate a unique order ID
        orderCount++;

        // Generate a mock order ID using the order count
        bytes32 orderId = keccak256(abi.encodePacked(orderCount));

        // Store the order parameters in the mapping for later retrieval
        orders[orderId] = params;

        // Emit an event for the created order (optional, for testing purposes)
        emit OrderCreated(orderId, params);

        // Return the mock order ID
        return orderId;
    }

    // Events are useful for testing to ensure that certain actions took place
    event OrderCreated(bytes32 indexed orderId, GmxPositionUtils.CreateOrderParams params);

    // Other functions from the interface can be mocked as needed for testing
    // ...

    // The following functions are not relevant for the mock and can be left unimplemented
    function multicall(bytes[] calldata data) external payable override returns (bytes[] memory results) {
        // Left unimplemented for brevity
        results = new bytes[](0);
    }

    function sendWnt(address receiver, uint amount) external payable override {
        // Left unimplemented for brevity
    }

    function sendNativeToken(address receiver, uint amount) external payable override {
        // Left unimplemented for brevity
    }

    function sendTokens(address token, address receiver, uint amount) external payable override {
        // Left unimplemented for brevity
    }

    function cancelOrder(bytes32 key) external payable override {
        // Left unimplemented for brevity
    }

    function claimFundingFees(
        address[] memory markets,
        address[] memory tokens,
        address receiver
    ) external payable override returns (uint[] memory) {
        // Left unimplemented for brevity
        return new uint[](0);
    }

    function claimAffiliateRewards(
        address[] memory markets,
        address[] memory tokens,
        address receiver
    ) external payable override returns (uint[] memory) {
        // Left unimplemented for brevity
        return new uint[](0);
    }
}
