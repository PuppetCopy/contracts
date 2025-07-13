// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {AllocationAccount} from "./../shared/AllocationAccount.sol";
import {Error} from "./../utils/Error.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract MirrorPosition is CoreContract, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        address refundExecutionFeeReceiver;
    }

    struct Position {
        uint size;
        uint traderSize;
        uint traderCollateral;
    }

    struct RequestAdjustment {
        address allocationAddress;
        bool traderIsIncrease;
        uint traderTargetLeverage;
        uint traderCollateralDelta;
        uint traderSizeDelta;
        uint sizeDelta;
    }

    struct UnhandledCallback {
        address operator;
        bytes32 key;
        bytes error;
    }

    struct CallPosition {
        IERC20 collateralToken;
        address trader;
        address market;
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
    }

    Config public config;
    uint public unhandledCallbackListId = 0;

    mapping(address allocationAddress => Position) public positionMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getPosition(
        address _allocationAddress
    ) external view returns (Position memory) {
        return positionMap[_allocationAddress];
    }

    function getRequestAdjustment(
        bytes32 _requestKey
    ) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_requestKey];
    }

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority) {
        _setConfig(abi.encode(_config));
    }

    /**
     * @notice Starts copying a trader's new position opening (increase) for a selected group of followers (puppets).
     * @dev Called by an authorized Keeper (`auth`) to initiate the copy-trading process when a followed trader opens a
     * new position.
     * This function determines how much capital each eligible puppet allocates based on their individual matching rules
     * (`MatchingRule`),
     * available funds (`AllocationStore`), and activity limits. It ensures the total allocated amount is sufficient to
     * cover the provided keeper execution fee (`_callParams.keeperExecutionFee`).
     *
     * The function orchestrates the fund movements:
     * 1. It reserves the calculated allocation amounts from each puppet's balance in the `AllocationStore`.
     * 2. It transfers the total collected capital from the `AllocationStore`.
     * 3. It pays the `keeperExecutionFee` to the designated `_keeperFeeReceiver`.
     * 4. It sends the remaining net capital (`_netAllocation`) to the GMX order vault (`config.gmxOrderVault`) to
     * collateralize the position.
     *
     * It then calculates the appropriate size (`_sizeDelta`) for the combined puppet position, proportional to the net
     * capital provided,
     * and submits a `MarketIncrease` order to the GMX Router. The Keeper must provide `msg.value` to cover the GMX
     * network execution fee (`_callParams.executionFee`).
     *
     * Finally, it records details about this specific mirror action, including the total capital committed
     * (`allocationMap`) and the GMX request details (`requestAdjustmentMap`),
     * which are necessary for future adjustments or settlement via the `execute` function upon GMX callback.
     * Emits a `Mirror` event with key details.
     * @param _params Position parameters for the trader's action
     * @param _allocationAddress The allocation account address created
     * @param _netAllocation The net allocation amount after deducting the keeper fee
     * @return _requestKey The unique key returned by GMX identifying the created order request
     */
    function requestMirror(
        CallPosition calldata _params,
        address _allocationAddress,
        uint _netAllocation
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(_params.isIncrease, Error.MirrorPosition__InitialMustBeIncrease());
        require(_params.collateralDelta > 0, Error.MirrorPosition__InvalidCollateralDelta());
        require(_params.sizeDeltaInUsd > 0, Error.MirrorPosition__InvalidSizeDelta());
        require(_allocationAddress != address(0), Error.MirrorPosition__InvalidAllocation(_allocationAddress));
        require(_netAllocation > 0, "Invalid net allocation");

        // Calculate position size proportional to trader's leverage
        uint _traderTargetLeverage = Precision.toBasisPoints(_params.sizeDeltaInUsd, _params.collateralDelta);
        uint _sizeDelta = Math.mulDiv(_params.sizeDeltaInUsd, _netAllocation, _params.collateralDelta);

        // Submit GMX order
        _requestKey = _submitOrder(
            _params,
            _allocationAddress,
            GmxPositionUtils.OrderType.MarketIncrease,
            config.increaseCallbackGasLimit,
            _sizeDelta,
            _netAllocation
        );

        // Store request details for execute callback
        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationAddress: _allocationAddress,
            traderIsIncrease: true,
            traderTargetLeverage: _traderTargetLeverage,
            traderSizeDelta: _params.sizeDeltaInUsd,
            traderCollateralDelta: _params.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "RequestMirror",
            abi.encode(_params, _requestKey, _allocationAddress, _netAllocation, _sizeDelta, _traderTargetLeverage)
        );
    }

    /**
     * @notice Adjusts an existing mirrored position to follow a trader's action (increase/decrease).
     * @dev Called by an authorized Keeper when the trader being copied modifies their GMX position. This function
     * ensures the combined puppet position reflects the trader's change. It requires `msg.value` from the Keeper
     * to cover the GMX network fee for submitting the adjustment order.
     *
     * This function handles the Keeper's execution fee (`_callParams.keeperExecutionFee`) in a way that doesn't block
     * the adjustment for all puppets if one cannot pay. It attempts to deduct each puppet's share of the fee from
     * their available balance in the `AllocationStore`. If a puppet lacks sufficient funds, their invested amount
     * (`allocationPuppetMap`) in *this specific position* is reduced by the unpaid fee amount. The *full* keeper fee
     * is paid immediately using funds from the `AllocationStore`.
     *
     * The core logic calculates the trader's new target leverage based on their latest action. It compares this to the
     * current leverage of the mirrored position (considering any reductions due to fee insolvency). It then determines
     * the required size change (`_sizeDelta`) for the mirrored position to match the trader's target leverage and
     * submits the corresponding `MarketIncrease` or `MarketDecrease` order to GMX.
     *
     * Details about the adjustment request are stored (`requestAdjustmentMap`) for processing when GMX confirms the
     * order execution via the `execute` function callback. If puppet allocations were reduced due to fee handling,
     * the total allocation (`allocationMap`) is updated. Emits an `Adjust` event.
     * @param _params Structure containing details of the trader's adjustment action (deltas must be > 0),
     * market, collateral, GMX execution fee, keeper fee, and keeper fee receiver.
     * @param _allocationAddress The allocation account address associated with the position being adjusted.
     * @param _currentAllocation The current total allocation amount for the position.
     * @return _requestKey The unique key returned by GMX identifying the created adjustment order request.
     */
    function requestAdjust(
        CallPosition calldata _params,
        address _allocationAddress,
        uint _currentAllocation
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(_params.collateralDelta > 0 || _params.sizeDeltaInUsd > 0, Error.MirrorPosition__NoAdjustmentRequired());
        require(_allocationAddress != address(0), Error.MirrorPosition__InvalidAllocation(_allocationAddress));
        require(_currentAllocation > 0, "Invalid current allocation");

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound(_allocationAddress));
        require(_position.traderCollateral > 0, Error.MirrorPosition__TraderCollateralZero(_allocationAddress));

        // Calculate trader's new target leverage
        uint _currentPuppetLeverage = Precision.toBasisPoints(_position.size, _currentAllocation);

        uint newTraderSize;
        uint newTraderCollateral;

        if (_params.isIncrease) {
            newTraderSize = _position.traderSize + _params.sizeDeltaInUsd;
            newTraderCollateral = _position.traderCollateral + _params.collateralDelta;
        } else {
            newTraderSize =
                _position.traderSize > _params.sizeDeltaInUsd ? _position.traderSize - _params.sizeDeltaInUsd : 0;
            newTraderCollateral = _position.traderCollateral > _params.collateralDelta
                ? _position.traderCollateral - _params.collateralDelta
                : 0;
        }

        uint _traderTargetLeverage;
        if (_params.isIncrease) {
            _traderTargetLeverage = Precision.toBasisPoints(newTraderSize, newTraderCollateral);
        } else {
            if (_position.traderSize > _params.sizeDeltaInUsd && _position.traderCollateral > _params.collateralDelta) {
                _traderTargetLeverage = Precision.toBasisPoints(newTraderSize, newTraderCollateral);
            } else {
                _traderTargetLeverage = 0;
            }
        }

        require(_traderTargetLeverage != _currentPuppetLeverage, Error.MirrorPosition__NoAdjustmentRequired());
        require(_currentPuppetLeverage > 0, Error.MirrorPosition__InvalidCurrentLeverage());

        // Calculate size delta and submit order
        bool isIncrease = _traderTargetLeverage > _currentPuppetLeverage;
        uint _sizeDelta;

        if (isIncrease) {
            _sizeDelta =
                Math.mulDiv(_position.size, (_traderTargetLeverage - _currentPuppetLeverage), _currentPuppetLeverage);
        } else if (_traderTargetLeverage == 0) {
            _sizeDelta = _position.size; // Close entire position
        } else {
            _sizeDelta =
                Math.mulDiv(_position.size, (_currentPuppetLeverage - _traderTargetLeverage), _currentPuppetLeverage);
        }

        _requestKey = _submitOrder(
            _params,
            _allocationAddress,
            isIncrease ? GmxPositionUtils.OrderType.MarketIncrease : GmxPositionUtils.OrderType.MarketDecrease,
            isIncrease ? config.increaseCallbackGasLimit : config.decreaseCallbackGasLimit,
            _sizeDelta,
            0
        );

        // Store request details for execute callback
        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationAddress: _allocationAddress,
            traderIsIncrease: _params.isIncrease,
            traderTargetLeverage: _traderTargetLeverage,
            traderSizeDelta: _params.sizeDeltaInUsd,
            traderCollateralDelta: _params.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "RequestAdjust",
            abi.encode(_params, _requestKey, _allocationAddress, _currentAllocation, _sizeDelta, _traderTargetLeverage)
        );
    }

    /**
     * @notice Finalizes the state update after a GMX order execution.
     * @dev This function is called by the `GmxExecutionCallback` contract via its `afterOrderExecution` function,
     * which is triggered by GMX's callback mechanism upon successful order execution (increase or decrease).
     * It uses the GMX request key (`_requestKey`) to retrieve the details of the intended adjustment stored
     * during the `mirror` or `adjust` call. It updates the internal position state (`positionMap`) to reflect
     * the executed changes in size and collateral, based on the stored `RequestAdjustment` data.
     * If the adjustment results in closing the position (target leverage becomes zero or size becomes zero),
     * it cleans up the position data. Finally, it removes the processed `RequestAdjustment` record and emits
     * an `Execute` event.
     * @param _requestKey The unique key provided by GMX identifying the executed order request.
     */
    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        require(_request.allocationAddress != address(0), Error.MirrorPosition__ExecutionRequestMissing(_requestKey));

        Position memory _position = positionMap[_request.allocationAddress];

        delete requestAdjustmentMap[_requestKey];

        if (_request.traderTargetLeverage == 0) {
            delete positionMap[_request.allocationAddress];
            _logEvent("Execute", abi.encode(_request.allocationAddress, _requestKey, 0, 0, 0, 0));
            return;
        }

        // Update trader position state
        if (_request.traderIsIncrease) {
            _position.traderSize += _request.traderSizeDelta;
            _position.traderCollateral += _request.traderCollateralDelta;
        } else {
            _position.traderSize =
                (_position.traderSize > _request.traderSizeDelta) ? _position.traderSize - _request.traderSizeDelta : 0;
            _position.traderCollateral = (_position.traderCollateral > _request.traderCollateralDelta)
                ? _position.traderCollateral - _request.traderCollateralDelta
                : 0;
        }

        // Update puppet position size
        if (_request.traderTargetLeverage > 0) {
            if (_request.traderIsIncrease) {
                _position.size += _request.sizeDelta;
            } else {
                _position.size = (_position.size > _request.sizeDelta) ? _position.size - _request.sizeDelta : 0;
            }
        }

        if (_position.size == 0) {
            delete positionMap[_request.allocationAddress];
            _logEvent(
                "Execute",
                abi.encode(
                    _request.allocationAddress,
                    _requestKey,
                    _position.traderSize,
                    _position.traderCollateral,
                    0,
                    _request.traderTargetLeverage
                )
            );
        } else {
            positionMap[_request.allocationAddress] = _position;
            _logEvent(
                "Execute",
                abi.encode(
                    _request.allocationAddress,
                    _requestKey,
                    _position.traderSize,
                    _position.traderCollateral,
                    _position.size,
                    _request.traderTargetLeverage
                )
            );
        }
    }

    function liquidate(
        address _allocationAddress
    ) external auth {
        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound(_allocationAddress));

        delete positionMap[_allocationAddress];

        _logEvent("Liquidate", abi.encode(_allocationAddress));
    }

    function _submitOrder(
        CallPosition calldata _order,
        address _allocationAddress,
        GmxPositionUtils.OrderType _orderType,
        uint _callbackGasLimit,
        uint _sizeDeltaUsd,
        uint _initialCollateralDeltaAmount
    ) internal returns (bytes32 gmxRequestKey) {
        require(
            msg.value >= _order.executionFee,
            Error.MirrorPosition__InsufficientGmxExecutionFee(msg.value, _order.executionFee)
        );

        bytes memory gmxCallData = abi.encodeWithSelector(
            config.gmxExchangeRouter.createOrder.selector,
            GmxPositionUtils.CreateOrderParams({
                addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                    receiver: _allocationAddress,
                    cancellationReceiver: _allocationAddress,
                    callbackContract: address(this),
                    uiFeeReceiver: address(0),
                    market: _order.market,
                    initialCollateralToken: _order.collateralToken,
                    swapPath: new address[](0)
                }),
                numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                    sizeDeltaUsd: _sizeDeltaUsd,
                    initialCollateralDeltaAmount: _initialCollateralDeltaAmount,
                    triggerPrice: _order.triggerPrice,
                    acceptablePrice: _order.acceptablePrice,
                    executionFee: _order.executionFee,
                    callbackGasLimit: _callbackGasLimit,
                    minOutputAmount: 0,
                    validFromTime: 0
                }),
                autoCancel: false,
                orderType: _orderType,
                decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
                isLong: _order.isLong,
                shouldUnwrapNativeToken: false,
                referralCode: config.referralCode
            })
        );

        config.gmxExchangeRouter.sendWnt{value: _order.executionFee}(config.gmxOrderVault, _order.executionFee);

        (bool success, bytes memory returnData) =
            AllocationAccount(_allocationAddress).execute(address(config.gmxExchangeRouter), gmxCallData, gasleft());

        if (!success) {
            ErrorUtils.revertWithParsedMessage(returnData);
        }

        gmxRequestKey = abi.decode(returnData, (bytes32));
        require(gmxRequestKey != bytes32(0), Error.MirrorPosition__OrderCreationFailed());
    }

    /// @notice  Sets the configuration parameters via governance
    /// @param _data The encoded configuration data
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.gmxExchangeRouter != IGmxExchangeRouter(address(0)), "Invalid GMX Router address");
        require(_config.gmxOrderVault != address(0), "Invalid GMX Order Vault address");
        require(_config.referralCode != bytes32(0), "Invalid Referral Code");
        require(_config.increaseCallbackGasLimit > 0, "Invalid Increase Callback Gas Limit");
        require(_config.decreaseCallbackGasLimit > 0, "Invalid Decrease Callback Gas Limit");
        require(_config.refundExecutionFeeReceiver != address(0), "Invalid Refund Execution Fee Receiver");

        config = _config;
    }

    /**
     * @notice Called after an order is executed.
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props memory order,
        GmxPositionUtils.EventLogData memory /*eventData*/
    ) external auth {
        if (
            GmxPositionUtils.isIncreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
                || GmxPositionUtils.isDecreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
        ) {
            try this.execute(key) {}
            catch (bytes memory err) {
                _storeUnhandledCallback(key, err);
            }
        } else if (GmxPositionUtils.isLiquidateOrder(GmxPositionUtils.OrderType(order.numbers.orderType))) {
            try this.liquidate(order.addresses.account) {}
            catch (bytes memory err) {
                _storeUnhandledCallback(key, err);
            }
        } else {
            _storeUnhandledCallback(key, "Invalid order type");
        }
    }

    /**
     * @notice Called after an order is cancelled.
     */
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata, /*order*/
        GmxPositionUtils.EventLogData calldata /*eventData*/
    ) external auth {
        _storeUnhandledCallback(key, "Cancellation not implemented");
    }

    /**
     * @notice Called after an order is frozen.
     */
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata, /*order*/
        GmxPositionUtils.EventLogData calldata /*eventData*/
    ) external auth {
        _storeUnhandledCallback(key, "Freezing not implemented");
    }

    function refundExecutionFee(
        bytes32 key,
        GmxPositionUtils.EventLogData memory /*eventData*/
    ) external payable auth {
        require(msg.value > 0, "No execution fee to refund");

        // Refund the execution fee to the configured receiver
        (bool success,) = config.refundExecutionFeeReceiver.call{value: msg.value}("");
        require(success, Error.GmxExecutionCallback__FailedRefundExecutionFee());

        _logEvent("RefundExecutionFee", abi.encode(key, msg.value));
    }

    function _storeUnhandledCallback(bytes32 _key, bytes memory error) internal {
        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = UnhandledCallback({operator: msg.sender, key: _key, error: error});

        _logEvent("StoreUnhandledCallback", abi.encode(id, error, _key));
    }
}
