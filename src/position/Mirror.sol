// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Error} from "./../utils/Error.sol";
import {Precision} from "./../utils/Precision.sol";
import {Account} from "./Account.sol";
import {Subscribe} from "./Subscribe.sol";
import {IBaseOrderUtils} from "@gmx/contracts/order/IBaseOrderUtils.sol";
import {Order} from "@gmx/contracts/order/Order.sol";
import {Position} from "@gmx/contracts/position/Position.sol";
import {PositionStoreUtils} from "@gmx/contracts/position/PositionStoreUtils.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "./interface/IGmxReadDataStore.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Mirror is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxReadDataStore gmxDataStore;
        address gmxOrderVault;
        bytes32 referralCode;
        uint maxPuppetList;
        uint maxSequencerFeeToAllocationRatio;
        uint maxSequencerFeeToAdjustmentRatio;
        uint maxSequencerFeeToCloseRatio;
        uint maxMatchOpenDuration;
        uint maxMatchAdjustDuration;
    }

    struct CallParams {
        IERC20 collateralToken;
        address trader;
        address market;
        address sequencerFeeReceiver;
        bool isLong;
        uint executionFee;
        uint allocationId;
        uint sequencerFee;
    }

    Config public config;

    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;
    mapping(bytes32 positionKey => uint) public lastTargetSizeMap;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getAllocation(address _allocationAddress) external view returns (uint) {
        return allocationMap[_allocationAddress];
    }

    function getAllocationPuppetList(address _allocationAddress) external view returns (uint[] memory) {
        return allocationPuppetList[_allocationAddress];
    }

    function getLastActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external view returns (uint) {
        return lastActivityThrottleMap[_traderMatchingKey][_puppet];
    }

    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    function getPositionSizeInUsd(
        address _allocationAddress,
        address _market,
        IERC20 _collateralToken,
        bool _isLong
    ) external view returns (uint) {
        bytes32 positionKey = Position.getPositionKey(_allocationAddress, _market, address(_collateralToken), _isLong);
        return _getPositionSizeInUsd(positionKey);
    }

    function matchmake(
        Account _account,
        Subscribe _subscribe,
        CallParams calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (address _allocationAddress, bytes32 _requestKey) {
        if (_callParams.sequencerFee == 0) revert Error.Mirror__InvalidSequencerExecutionFeeAmount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount == 0) revert Error.Mirror__PuppetListEmpty();
        if (_puppetCount > config.maxPuppetList) revert Error.Mirror__PuppetListTooLarge(_puppetCount, config.maxPuppetList);

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId);
        _allocationAddress = _account.getAllocationAddress(_allocationKey);

        bytes32 _puppetPositionKey =
            Position.getPositionKey(_allocationAddress, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);

        uint _gmxSize = _getPositionSizeInUsd(_puppetPositionKey);
        if (_gmxSize != 0) revert Error.Mirror__PositionAlreadyOpen();

        bytes32 _traderPositionKey =
            Position.getPositionKey(_callParams.trader, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);
        uint _traderSizeInUsd = _getPositionSizeInUsd(_traderPositionKey);
        uint _traderCollateral = _getPositionCollateral(_traderPositionKey);
        if (_traderSizeInUsd == 0 || _traderCollateral == 0) revert Error.Mirror__NoPosition();

        _allocationAddress = _account.createAllocationAccount(_allocationKey);

        Subscribe.RuleParams[] memory _rules = _subscribe.getRuleList(_traderMatchingKey, _puppetList);
        uint[] memory _allocatedList = new uint[](_puppetCount);
        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.collateralToken, _puppetList);
        allocationPuppetList[_allocationAddress] = new uint[](_puppetCount);

        uint _allocated = 0;
        uint _remainingFee = _callParams.sequencerFee;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            address _puppet = _puppetList[_i];
            Subscribe.RuleParams memory _rule = _rules[_i];

            if (_rule.expiry <= block.timestamp) continue;
            if (block.timestamp < lastActivityThrottleMap[_traderMatchingKey][_puppet]) continue;

            uint _contribution = Precision.applyBasisPoints(_rule.allowanceRate, _nextBalanceList[_i]);
            uint _remainingPuppets = _puppetCount - _i;
            uint _feeShare = (_remainingFee + _remainingPuppets - 1) / _remainingPuppets;
            if (_feeShare > _contribution) _feeShare = _contribution;

            uint _netAllocation = _contribution - _feeShare;
            _remainingFee -= _feeShare;

            _allocatedList[_i] = _netAllocation;
            allocationPuppetList[_allocationAddress][_i] = _netAllocation;
            _nextBalanceList[_i] -= _contribution;
            _allocated += _netAllocation;
            lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
        }

        if (_remainingFee != 0) {
            revert Error.Mirror__SequencerFeeNotFullyCovered(_callParams.sequencerFee - _remainingFee, _callParams.sequencerFee);
        }
        if (
            _callParams.sequencerFee
                >= Precision.applyFactor(config.maxSequencerFeeToAllocationRatio, _allocated + _callParams.sequencerFee)
        ) revert Error.Mirror__SequencerFeeExceedsCostFactor(_callParams.sequencerFee, _allocated + _callParams.sequencerFee);

        allocationMap[_allocationAddress] = _allocated;

        _account.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalanceList);
        _account.transferOut(_callParams.collateralToken, _callParams.sequencerFeeReceiver, _callParams.sequencerFee);
        _account.transferOut(_callParams.collateralToken, config.gmxOrderVault, _allocated);

        uint _sizeDelta = Math.mulDiv(_traderSizeInUsd, _allocated, _traderCollateral);

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callParams.collateralToken,
            _callParams.market,
            _callParams.isLong,
            _callParams.executionFee,
            Order.OrderType.MarketIncrease,
            _sizeDelta,
            _allocated
        );

        lastTargetSizeMap[_puppetPositionKey] = _sizeDelta;

        _logEvent(
            "Match",
            abi.encode(
                _callParams.collateralToken,
                _callParams.trader,
                _callParams.market,
                _callParams.sequencerFeeReceiver,
                _callParams.isLong,
                _callParams.executionFee,
                _callParams.allocationId,
                _callParams.sequencerFee,
                _allocationAddress,
                _traderMatchingKey,
                _traderPositionKey,
                _puppetPositionKey,
                _requestKey,
                _sizeDelta,
                _allocated,
                _allocatedList,
                _puppetList,
                _nextBalanceList
            )
        );
    }

    function adjust(
        Account _account,
        CallParams calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32 _requestKey) {
        if (_callParams.sequencerFee == 0) revert Error.Mirror__InvalidSequencerExecutionFeeAmount();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId)
        );

        uint _allocated = allocationMap[_allocationAddress];
        if (_allocated == 0) revert Error.Mirror__InvalidAllocation(_allocationAddress);

        bytes32 _puppetPositionKey =
            Position.getPositionKey(_allocationAddress, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);
        uint _puppetCurrentSize = _getPositionSizeInUsd(_puppetPositionKey);
        if (_puppetCurrentSize == 0) revert Error.Mirror__NoPosition();

        uint _lastTarget = lastTargetSizeMap[_puppetPositionKey];
        if (_puppetCurrentSize != _lastTarget) revert Error.Mirror__RequestPending();

        bytes32 _traderPositionKey =
            Position.getPositionKey(_callParams.trader, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);
        uint _traderSizeInUsd = _getPositionSizeInUsd(_traderPositionKey);
        uint _traderCollateral = _getPositionCollateral(_traderPositionKey);
        if (_traderSizeInUsd == 0 || _traderCollateral == 0) revert Error.Mirror__NoPosition();

        uint _puppetTargetSize = Math.mulDiv(_traderSizeInUsd, _allocated, _traderCollateral);

        bool _isIncrease = _puppetTargetSize > _puppetCurrentSize;
        uint _sizeDelta = _isIncrease
            ? _puppetTargetSize - _puppetCurrentSize
            : _puppetCurrentSize - _puppetTargetSize;

        if (_sizeDelta == 0) revert Error.Mirror__InvalidSizeDelta();

        if (_callParams.sequencerFee >= Precision.applyFactor(config.maxSequencerFeeToAdjustmentRatio, _allocated)) {
            revert Error.Mirror__SequencerFeeExceedsAdjustmentRatio(_callParams.sequencerFee, _allocated);
        }

        uint _puppetCount = _puppetList.length;
        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _remainingFee = _callParams.sequencerFee;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            if (_nextBalanceList[_i] == 0) continue;

            uint _remainingPuppets = _puppetCount - _i;
            uint _feeShare = (_remainingFee + _remainingPuppets - 1) / _remainingPuppets;

            if (_nextBalanceList[_i] >= _feeShare) {
                _nextBalanceList[_i] -= _feeShare;
                _remainingFee -= _feeShare;
            } else {
                _remainingFee -= _nextBalanceList[_i];
                _nextBalanceList[_i] = 0;
            }
        }

        if (_remainingFee != 0) {
            revert Error.Mirror__SequencerFeeNotFullyCovered(_callParams.sequencerFee - _remainingFee, _callParams.sequencerFee);
        }

        _account.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalanceList);
        _account.transferOut(_callParams.collateralToken, _callParams.sequencerFeeReceiver, _callParams.sequencerFee);

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callParams.collateralToken,
            _callParams.market,
            _callParams.isLong,
            _callParams.executionFee,
            _isIncrease ? Order.OrderType.MarketIncrease : Order.OrderType.MarketDecrease,
            _sizeDelta,
            0
        );

        lastTargetSizeMap[_puppetPositionKey] = _puppetTargetSize;

        _logEvent(
            "Adjust",
            abi.encode(
                _allocationAddress,
                _requestKey,
                _callParams.sequencerFeeReceiver,
                _callParams.executionFee,
                _callParams.sequencerFee,
                _isIncrease,
                _sizeDelta,
                _puppetCurrentSize,
                _puppetTargetSize,
                _nextBalanceList
            )
        );
    }

    function close(
        Account _account,
        CallParams calldata _callParams,
        address[] calldata _puppetList,
        uint8 _reason
    ) external payable auth returns (bytes32 _requestKey) {
        if (_callParams.sequencerFee == 0) revert Error.Mirror__InvalidSequencerExecutionFeeAmount();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId)
        );

        uint _allocated = allocationMap[_allocationAddress];
        if (_allocated == 0) revert Error.Mirror__InvalidAllocation(_allocationAddress);

        bytes32 _puppetPositionKey =
            Position.getPositionKey(_allocationAddress, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);
        uint _positionSize = _getPositionSizeInUsd(_puppetPositionKey);
        if (_positionSize == 0) revert Error.Mirror__NoPosition();

        uint _lastTarget = lastTargetSizeMap[_puppetPositionKey];
        if (_positionSize != _lastTarget) revert Error.Mirror__RequestPending();

        bytes32 _traderPositionKey =
            Position.getPositionKey(_callParams.trader, _callParams.market, address(_callParams.collateralToken), _callParams.isLong);

        if (_callParams.sequencerFee >= Precision.applyFactor(config.maxSequencerFeeToCloseRatio, _allocated)) {
            revert Error.Mirror__SequencerFeeExceedsCloseRatio(_callParams.sequencerFee, _allocated);
        }

        uint _puppetCount = _puppetList.length;
        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _remainingFee = _callParams.sequencerFee;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            if (_nextBalanceList[_i] == 0) continue;

            uint _remainingPuppets = _puppetCount - _i;
            uint _feeShare = (_remainingFee + _remainingPuppets - 1) / _remainingPuppets;

            if (_nextBalanceList[_i] >= _feeShare) {
                _nextBalanceList[_i] -= _feeShare;
                _remainingFee -= _feeShare;
            } else {
                _remainingFee -= _nextBalanceList[_i];
                _nextBalanceList[_i] = 0;
            }
        }

        if (_remainingFee != 0) {
            revert Error.Mirror__SequencerFeeNotFullyCovered(_callParams.sequencerFee - _remainingFee, _callParams.sequencerFee);
        }

        _account.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalanceList);
        _account.transferOut(_callParams.collateralToken, _callParams.sequencerFeeReceiver, _callParams.sequencerFee);

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callParams.collateralToken,
            _callParams.market,
            _callParams.isLong,
            _callParams.executionFee,
            Order.OrderType.MarketDecrease,
            _positionSize,
            0
        );

        lastTargetSizeMap[_puppetPositionKey] = 0;

        _logEvent(
            "Close",
            abi.encode(
                _allocationAddress,
                _requestKey,
                _callParams.sequencerFeeReceiver,
                _callParams.executionFee,
                _callParams.sequencerFee,
                _positionSize,
                _reason,
                _nextBalanceList
            )
        );
    }

    function _submitOrder(
        Account _account,
        address _allocationAddress,
        IERC20 _collateralToken,
        address _market,
        bool _isLong,
        uint _executionFee,
        Order.OrderType _orderType,
        uint _sizeDeltaUsd,
        uint _initialCollateralDeltaAmount
    ) internal returns (bytes32 requestKey) {
        if (msg.value < _executionFee) {
            revert Error.Mirror__InsufficientGmxExecutionFee(msg.value, _executionFee);
        }

        uint _acceptablePrice = _isLong ? type(uint).max : 0;

        bytes memory gmxCallData = abi.encodeWithSelector(
            config.gmxExchangeRouter.createOrder.selector,
            IBaseOrderUtils.CreateOrderParams({
                addresses: IBaseOrderUtils.CreateOrderParamsAddresses({
                    receiver: _allocationAddress,
                    cancellationReceiver: _allocationAddress,
                    callbackContract: address(0),
                    uiFeeReceiver: address(0),
                    market: _market,
                    initialCollateralToken: address(_collateralToken),
                    swapPath: new address[](0)
                }),
                numbers: IBaseOrderUtils.CreateOrderParamsNumbers({
                    sizeDeltaUsd: _sizeDeltaUsd,
                    initialCollateralDeltaAmount: _initialCollateralDeltaAmount,
                    triggerPrice: 0,
                    acceptablePrice: _acceptablePrice,
                    executionFee: _executionFee,
                    callbackGasLimit: 0,
                    minOutputAmount: 0,
                    validFromTime: 0
                }),
                autoCancel: false,
                orderType: _orderType,
                decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
                isLong: _isLong,
                shouldUnwrapNativeToken: false,
                referralCode: config.referralCode,
                dataList: new bytes32[](0)
            })
        );

        config.gmxExchangeRouter.sendWnt{value: _executionFee}(config.gmxOrderVault, _executionFee);

        (bool success, bytes memory returnData) =
            _account.execute(_allocationAddress, address(config.gmxExchangeRouter), gmxCallData, gasleft());

        if (!success) {
            revert Error.Mirror__OrderCreationFailed();
        }

        requestKey = abi.decode(returnData, (bytes32));
        if (requestKey == bytes32(0)) revert Error.Mirror__OrderCreationFailed();
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.gmxExchangeRouter == IGmxExchangeRouter(address(0))) revert("Invalid GMX Router address");
        if (_config.gmxDataStore == IGmxReadDataStore(address(0))) revert("Invalid GMX Data Store address");
        if (_config.gmxOrderVault == address(0)) revert("Invalid GMX Order Vault address");
        if (_config.referralCode == bytes32(0)) revert("Invalid Referral Code");
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        if (_config.maxSequencerFeeToAllocationRatio == 0) revert("Invalid max sequencer fee to allocation ratio");
        if (_config.maxSequencerFeeToAdjustmentRatio == 0) revert("Invalid max sequencer fee to adjustment ratio");
        if (_config.maxSequencerFeeToCloseRatio == 0) revert("Invalid max sequencer fee to close ratio");

        config = _config;
    }

    function _getPositionSizeInUsd(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.SIZE_IN_USD)));
    }

    function _getPositionCollateral(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.COLLATERAL_AMOUNT)));
    }
}
