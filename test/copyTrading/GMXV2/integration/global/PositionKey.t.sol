// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {CommonHelper} from "src/integrations/libraries/CommonHelper.sol";
import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";

import {BaseGMXV2} from "../../BaseGMXV2.t.sol";

contract GMXV2PositionKeyIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testCorrespondingPositionKey() external {
        address _collateralToken = _weth;
        address _indexToken = _weth;
        bool _isLong = true;
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _collateralToken, _indexToken, _isLong, _ethLongMarketData);

        address _route = CommonHelper.routeAddress(context.dataStore, _routeKey);
        bytes32 _puppetPositionKey = IBaseOrchestrator(context.orchestrator).positionKey(_route);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/PositionUtils.sol#L241
        bytes32 _gmxV2PositionKey = keccak256(abi.encode(
            address(_route),
            _ethMarket,
            CommonHelper.collateralToken(context.dataStore, _route),
            CommonHelper.isLong(context.dataStore, _route)
        ));

        assertEq(_puppetPositionKey, _gmxV2PositionKey, "testCorrespondingPositionKey: E1");
    }
}