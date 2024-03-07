// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2DepositIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testDepositWNTFlow() external {
        _deposit.depositWNTFlowTest(context, false);
    }

    function testDepositNativeTokenFlow() external {
        _deposit.depositWNTFlowTest(context, true);
    }

    function testDepositWNTAndBatchSubscribe() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, true, _routeKey);
    }

    function testDepositNativeTokenAndBatchSubscribe() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, false, _routeKey);
    }
}