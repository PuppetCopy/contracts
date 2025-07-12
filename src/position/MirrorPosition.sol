// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
import {PositionUtils} from "./utils/PositionUtils.sol";

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
     * @notice Mirrors a trader's position using pre-allocated funds
     * @dev Called by Router after allocation has been created. This function focuses purely on GMX order submission.
     * @param _callParams Structure containing trader's position details
     * @param _allocationAddress The allocation account address (created by Allocation contract)
     * @param _netAllocation The net allocation amount available for position (after keeper fees)
     * @return _requestKey The unique key returned by GMX identifying the created order request
     */
    function requestMirror(
        CallPosition calldata _callParams,
        address _allocationAddress,
        uint _netAllocation
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(_callParams.isIncrease, Error.MirrorPosition__InitialMustBeIncrease());
        require(_callParams.collateralDelta > 0, Error.MirrorPosition__InvalidCollateralDelta());
        require(_callParams.sizeDeltaInUsd > 0, Error.MirrorPosition__InvalidSizeDelta());
        require(_allocationAddress != address(0), Error.MirrorPosition__InvalidAllocation(_allocationAddress));
        require(_netAllocation > 0, "Invalid net allocation");

        // Calculate position size proportional to trader's leverage
        uint _traderTargetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
        uint _sizeDelta = Math.mulDiv(_callParams.sizeDeltaInUsd, _netAllocation, _callParams.collateralDelta);

        // Submit GMX order
        _requestKey = _submitOrder(
            _callParams,
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
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "RequestMirror",
            abi.encode(_callParams, _requestKey, _allocationAddress, _netAllocation, _sizeDelta, _traderTargetLeverage)
        );
    }

    /**
     * @notice Adjusts an existing mirrored position to follow a trader's action
     * @dev Called by Router after allocation has been updated. Focuses purely on GMX order submission.
     * @param _callParams Structure containing trader's adjustment details
     * @param _allocationAddress The allocation account address
     * @param _currentAllocation The current allocation amount for this position
     * @return _requestKey The unique key returned by GMX identifying the created adjustment order request
     */
    function requestAdjust(
        CallPosition calldata _callParams,
        address _allocationAddress,
        uint _currentAllocation
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(
            _callParams.collateralDelta > 0 || _callParams.sizeDeltaInUsd > 0,
            Error.MirrorPosition__NoAdjustmentRequired()
        );
        require(_allocationAddress != address(0), Error.MirrorPosition__InvalidAllocation(_allocationAddress));
        require(_currentAllocation > 0, "Invalid current allocation");

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound(_allocationAddress));
        require(_position.traderCollateral > 0, Error.MirrorPosition__TraderCollateralZero(_allocationAddress));

        // Calculate trader's new target leverage
        uint _currentPuppetLeverage = Precision.toBasisPoints(_position.size, _currentAllocation);
        uint _traderTargetLeverage;

        if (_callParams.isIncrease) {
            _traderTargetLeverage = Precision.toBasisPoints(
                _position.traderSize + _callParams.sizeDeltaInUsd,
                _position.traderCollateral + _callParams.collateralDelta
            );
        } else {
            if (
                _position.traderSize > _callParams.sizeDeltaInUsd
                    && _position.traderCollateral > _callParams.collateralDelta
            ) {
                _traderTargetLeverage = Precision.toBasisPoints(
                    _position.traderSize - _callParams.sizeDeltaInUsd,
                    _position.traderCollateral - _callParams.collateralDelta
                );
            } else {
                _traderTargetLeverage = 0;
            }
        }

        require(_traderTargetLeverage != _currentPuppetLeverage, Error.MirrorPosition__NoAdjustmentRequired());
        require(_currentPuppetLeverage > 0, Error.MirrorPosition__InvalidCurrentLeverage());

        // Calculate size delta and submit order
        uint _sizeDelta;
        if (_traderTargetLeverage > _currentPuppetLeverage) {
            _sizeDelta =
                Math.mulDiv(_position.size, (_traderTargetLeverage - _currentPuppetLeverage), _currentPuppetLeverage);
            _requestKey = _submitOrder(
                _callParams,
                _allocationAddress,
                GmxPositionUtils.OrderType.MarketIncrease,
                config.increaseCallbackGasLimit,
                _sizeDelta,
                0
            );
        } else {
            _sizeDelta = (_traderTargetLeverage == 0)
                ? _position.size
                : Math.mulDiv(_position.size, (_currentPuppetLeverage - _traderTargetLeverage), _currentPuppetLeverage);
            _requestKey = _submitOrder(
                _callParams,
                _allocationAddress,
                GmxPositionUtils.OrderType.MarketDecrease,
                config.decreaseCallbackGasLimit,
                _sizeDelta,
                0
            );
        }

        // Store request details for execute callback
        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationAddress: _allocationAddress,
            traderIsIncrease: _callParams.isIncrease,
            traderTargetLeverage: _traderTargetLeverage,
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "RequestAdjust",
            abi.encode(
                _callParams, _requestKey, _allocationAddress, _currentAllocation, _sizeDelta, _traderTargetLeverage
            )
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
