// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2RegisterRouteIntegration is BaseGMXV2 {
    
    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testRegisterRoute() external {
        _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
    }
}