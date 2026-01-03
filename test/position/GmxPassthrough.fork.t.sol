// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CALLTYPE_SINGLE} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IExchangeRouter} from "gmx-synthetics/router/IExchangeRouter.sol";
import {IBaseOrderUtils} from "gmx-synthetics/order/IBaseOrderUtils.sol";
import {Order} from "gmx-synthetics/order/Order.sol";

import {GmxStage} from "src/position/stage/GmxStage.sol";
import {Position} from "src/position/Position.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {Error} from "src/utils/Error.sol";
import {Const} from "script/Const.sol";

import {ForkSetup} from "../base/ForkSetup.t.sol";

/// @title GMX Passthrough Fork Tests
/// @notice Tests raw execution passthrough for GMX V2 actions
contract GmxPassthroughTest is ForkSetup {
    GmxStage gmxStage;
    Position position;

    address subaccount;

    function setUp() public override {
        super.setUp();

        gmxStage = new GmxStage(gmxDataStore, gmxExchangeRouter, gmxOrderVault, address(wnt));

        position = new Position(dictator);
        dictator.setPermission(position, position.setHandler.selector, users.owner);
        position.setHandler(gmxExchangeRouter, IStage(address(gmxStage)));

        subaccount = makeAddr("subaccount");
        _dealUSDC(subaccount, 10_000e6);
    }

    // ============ INCREASE: Rejects missing execution fee ============

    function test_Increase_RejectsMissingExecutionFee() public {
        bytes[] memory innerCalls = new bytes[](2);

        // Only sendTokens, no sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(usdc), gmxOrderVault, 100e6);

        IBaseOrderUtils.CreateOrderParams memory params = _buildIncreaseParams(subaccount);
        innerCalls[1] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0, multicallData);

        vm.expectRevert(Error.GmxStage__InvalidExecutionSequence.selector);
        gmxStage.validate(users.owner, subaccount, 0, CALLTYPE_SINGLE, execData);
    }

    // ============ INCREASE: Rejects missing collateral ============

    function test_Increase_RejectsMissingCollateral() public {
        bytes[] memory innerCalls = new bytes[](2);

        // Only sendWnt for execution fee, no sendTokens for collateral
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, 0.001 ether);

        IBaseOrderUtils.CreateOrderParams memory params = _buildIncreaseParams(subaccount);
        innerCalls[1] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0.001 ether, multicallData);

        vm.expectRevert(Error.GmxStage__InvalidExecutionSequence.selector);
        gmxStage.validate(users.owner, subaccount, 0.001 ether, CALLTYPE_SINGLE, execData);
    }

    // ============ INCREASE: Rejects swap path ============

    function test_Increase_RejectsSwapPath() public {
        // Orders with swapPath are not supported (too complex)
        bytes[] memory innerCalls = new bytes[](3);

        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, 0.001 ether);
        innerCalls[1] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(usdc), gmxOrderVault, 100e6);

        // Build params with non-empty swapPath
        address[] memory swapPath = new address[](1);
        swapPath[0] = 0x63Dc80EE90F26363B3FCD609007CC9e14c8991BE; // some market

        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: subaccount,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: swapPath // non-empty!
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 1000e30,
                initialCollateralDeltaAmount: 100e6,
                triggerPrice: 0,
                acceptablePrice: type(uint256).max,
                executionFee: 0,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: Const.referralCode,
            dataList: new bytes32[](0)
        });
        innerCalls[2] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0.001 ether, multicallData);

        vm.expectRevert(Error.GmxStage__InvalidOrderType.selector);
        gmxStage.validate(users.owner, subaccount, 0.001 ether, CALLTYPE_SINGLE, execData);
    }

    // ============ INCREASE: Raw GMX UI calldata ============

    function test_Increase_RawCalldata() public {
        // Raw multicall calldata from GMX UI (MarketIncrease long ETH/USDC)
        // The receiver from the raw calldata (20-byte address)
        address rawReceiver = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;
        uint256 executionFee = 0x532909ab8440; // ~0.000091 ETH

        // Build the multicall matching the GMX UI pattern
        bytes[] memory innerCalls = new bytes[](3);

        // sendWnt(orderVault, executionFee)
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, executionFee);

        // sendTokens(USDC, orderVault, 10 USDC)
        innerCalls[1] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(usdc), gmxOrderVault, 10e6);

        // createOrder with real GMX UI params
        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: rawReceiver,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001, // GMX UI fee receiver
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 0x4e707b0f08e31b45bf377e36000, // ~100k USD position
                initialCollateralDeltaAmount: 10e6,
                triggerPrice: 0,
                acceptablePrice: 0x742d8303366, // slippage bound
                executionFee: executionFee,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: bytes32(uint256(3)), // from raw calldata
            dataList: new bytes32[](0)
        });
        innerCalls[2] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        // Wrap in multicall
        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, executionFee, multicallData);

        // Should revert because receiver doesn't match subaccount
        vm.expectRevert();
        gmxStage.validate(users.owner, subaccount, executionFee, CALLTYPE_SINGLE, execData);

        // With correct subaccount (matching receiver), should pass
        (, bytes memory hookData) = gmxStage.validate(users.owner, rawReceiver, executionFee, CALLTYPE_SINGLE, execData);
        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        assertTrue(positionKey != bytes32(0), "Position key returned");
    }

    // ============ INCREASE: multicall (GMX UI pattern) ============

    function test_Increase_Multicall() public view {
        // Build inner calls as bytes[]
        bytes[] memory innerCalls = new bytes[](3);

        // sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, 0.001 ether);

        // sendTokens for collateral
        innerCalls[1] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(usdc), gmxOrderVault, 100e6);

        // createOrder
        IBaseOrderUtils.CreateOrderParams memory params = _buildIncreaseParams(subaccount);
        innerCalls[2] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        // Wrap in multicall
        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);

        // Encode as single call to exchangeRouter
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0.001 ether, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, 0.001 ether, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(usdc), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ INCREASE: Native ETH collateral (2 calls) ============

    function test_Increase_NativeEthCollateral() public view {
        // Native ETH: sendWnt covers both execution fee + collateral
        bytes[] memory innerCalls = new bytes[](2);

        uint256 totalWnt = 0.011 ether; // exec fee (~0.001) + collateral (~0.01)

        // sendWnt for both execution fee and collateral
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, totalWnt);

        // createOrder with WETH as collateral
        IBaseOrderUtils.CreateOrderParams memory params = _buildIncreaseParamsWeth(subaccount);
        innerCalls[1] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, totalWnt, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, totalWnt, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(wnt), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ INCREASE: WETH token collateral (3 calls) ============

    function test_Increase_WethTokenCollateral() public view {
        // WETH token: sendWnt (fee) + sendTokens (WETH) + createOrder
        bytes[] memory innerCalls = new bytes[](3);

        uint256 executionFee = 0xa7536b0c55ec; // from raw calldata
        uint256 collateralAmount = 0x2386f26fc10000; // 0.01 WETH

        // sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, executionFee);

        // sendTokens for WETH collateral
        innerCalls[1] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(wnt), gmxOrderVault, collateralAmount);

        // createOrder with WETH as collateral
        IBaseOrderUtils.CreateOrderParams memory params = _buildIncreaseParamsWeth(subaccount);
        innerCalls[2] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, executionFee, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, executionFee, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(wnt), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ INCREASE: LimitIncrease via multicall ============

    function test_Increase_LimitOrder() public view {
        // Limit order pattern: sendWnt + sendTokens + createOrder(LimitIncrease)
        bytes[] memory innerCalls = new bytes[](3);

        uint256 executionFee = 0x1d35517f28258; // from raw calldata
        uint256 collateralAmount = 0x55d4a80; // ~90 USDC

        // sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, executionFee);

        // sendTokens for collateral
        innerCalls[1] = abi.encodeWithSelector(gmxStage.SEND_TOKENS(), address(usdc), gmxOrderVault, collateralAmount);

        // createOrder with LimitIncrease
        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: subaccount,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 0xaee496c63c38b7dce59b2fa00000, // position size
                initialCollateralDeltaAmount: collateralAmount,
                triggerPrice: 0xa4deaa7cca800, // limit trigger price
                acceptablePrice: type(uint256).max,
                executionFee: executionFee,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.LimitIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: bytes32(uint256(3)),
            dataList: new bytes32[](0)
        });
        innerCalls[2] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        // Wrap in multicall
        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, executionFee, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, executionFee, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(usdc), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ DECREASE: StopLoss via multicall ============

    function test_Decrease_StopLoss() public view {
        // Stop-loss order pattern: sendWnt + createOrder(StopLossDecrease)
        bytes[] memory innerCalls = new bytes[](2);

        uint256 executionFee = 0xb1d722184970; // from raw calldata

        // sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, executionFee);

        // createOrder with StopLossDecrease
        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: subaccount,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 0xee9f3e280d71f23cec57f00000000, // position size
                initialCollateralDeltaAmount: 0x9a63954, // collateral delta
                triggerPrice: 0xa4dabca8b9c000, // stop-loss trigger price
                acceptablePrice: 0,
                executionFee: executionFee,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.StopLossDecrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: true,
            referralCode: bytes32(uint256(1)),
            dataList: new bytes32[](0)
        });
        innerCalls[1] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        // Wrap in multicall
        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, executionFee, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, executionFee, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(usdc), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ DECREASE: MarketDecrease via multicall ============

    function test_Decrease_MarketDecrease() public view {
        // Market decrease pattern: sendWnt + createOrder(MarketDecrease)
        bytes[] memory innerCalls = new bytes[](2);

        uint256 executionFee = 0xab6a0ae33260; // from raw calldata
        uint256 collateralDelta = 0x608edae; // ~101 USDC

        // sendWnt for execution fee
        innerCalls[0] = abi.encodeWithSelector(gmxStage.SEND_WNT(), gmxOrderVault, executionFee);

        // createOrder with MarketDecrease
        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: subaccount,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 0x1f2d82d9ce6935cc2b60d6f8f8000, // position size delta
                initialCollateralDeltaAmount: collateralDelta,
                triggerPrice: 0,
                acceptablePrice: 0xac16923d5ae36, // slippage bound
                executionFee: executionFee,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketDecrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: bytes32(uint256(3)),
            dataList: new bytes32[](0)
        });
        innerCalls[1] = abi.encodeCall(IExchangeRouter.createOrder, (params));

        // Wrap in multicall
        bytes memory multicallData = abi.encodeWithSelector(gmxStage.MULTICALL(), innerCalls);
        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, executionFee, multicallData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, executionFee, CALLTYPE_SINGLE, execData);

        (,, bytes32 positionKey,) = abi.decode(hookData, (uint8, bytes32, bytes32, address));
        bytes32 expectedKey = keccak256(abi.encode(subaccount, gmxEthUsdcMarket, address(usdc), true));
        assertEq(positionKey, expectedKey, "Position key derived correctly");
    }

    // ============ DECREASE: Rejects missing execution fee ============

    function test_Decrease_RejectsMissingExecutionFee() public {
        // Direct createOrder without sendWnt should fail
        IBaseOrderUtils.CreateOrderParams memory params = _buildDecreaseParams(subaccount);
        bytes memory createOrderData = abi.encodeCall(IExchangeRouter.createOrder, (params));

        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0, createOrderData);

        vm.expectRevert(Error.GmxStage__InvalidExecutionSequence.selector);
        gmxStage.validate(users.owner, subaccount, 0, CALLTYPE_SINGLE, execData);
    }

    // ============ CLAIM: Claim funding fees ============

    function test_ClaimFundingFees() public view {
        // claimFundingFees(address[] markets, address[] tokens, address receiver)
        address[] memory markets = new address[](2);
        markets[0] = gmxEthUsdcMarket;
        markets[1] = gmxEthUsdcMarket;

        address[] memory tokens = new address[](2);
        tokens[0] = address(wnt);
        tokens[1] = address(usdc);

        bytes memory claimData = abi.encodeWithSelector(
            gmxStage.CLAIM_FUNDING(),
            markets, tokens, subaccount
        );

        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0, claimData);

        (, bytes memory hookData) = gmxStage.validate(users.owner, subaccount, 0, CALLTYPE_SINGLE, execData);
        assertEq(hookData.length, 0, "Claim funding returns empty hookData");
    }

    function test_ClaimFundingFees_RejectsWrongReceiver() public {
        address[] memory markets = new address[](1);
        markets[0] = gmxEthUsdcMarket;

        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);

        // Wrong receiver - not subaccount
        address wrongReceiver = makeAddr("wrongReceiver");
        bytes memory claimData = abi.encodeWithSelector(
            gmxStage.CLAIM_FUNDING(),
            markets, tokens, wrongReceiver
        );

        bytes memory execData = ExecutionLib.encodeSingle(gmxExchangeRouter, 0, claimData);

        vm.expectRevert(Error.GmxStage__InvalidReceiver.selector);
        gmxStage.validate(users.owner, subaccount, 0, CALLTYPE_SINGLE, execData);
    }

    // ============ Helpers ============

    function _buildIncreaseParams(address receiver) internal view returns (IBaseOrderUtils.CreateOrderParams memory) {
        return IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: receiver,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 1000e30,
                initialCollateralDeltaAmount: 100e6,
                triggerPrice: 0,
                acceptablePrice: type(uint256).max,
                executionFee: 0,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: Const.referralCode,
            dataList: new bytes32[](0)
        });
    }

    function _buildIncreaseParamsWeth(address receiver) internal view returns (IBaseOrderUtils.CreateOrderParams memory) {
        return IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: receiver,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(wnt),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 1000e30,
                initialCollateralDeltaAmount: 0.01 ether,
                triggerPrice: 0,
                acceptablePrice: type(uint256).max,
                executionFee: 0,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: Const.referralCode,
            dataList: new bytes32[](0)
        });
    }

    function _buildDecreaseParams(address receiver) internal view returns (IBaseOrderUtils.CreateOrderParams memory) {
        return IBaseOrderUtils.CreateOrderParams({
            addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                receiver: receiver,
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: gmxEthUsdcMarket,
                initialCollateralToken: address(usdc),
                swapPath: new address[](0)
            }),
            numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: 1000e30,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 0,
                executionFee: 0,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: Order.OrderType.MarketDecrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: true,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: Const.referralCode,
            dataList: new bytes32[](0)
        });
    }
}
