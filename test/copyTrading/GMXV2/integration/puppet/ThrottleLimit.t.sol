// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2ThrottleLimitIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testBatchSubscribeFlow() external {
        _throttleLimit.throttleLimitTest(context);
    }
}