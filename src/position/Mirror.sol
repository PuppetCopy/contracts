// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

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
        uint maxMatchmakerFeeToAllocationRatio;
        uint maxMatchmakerFeeToAdjustmentRatio;
        uint maxMatchmakerFeeToCloseRatio;
        uint maxMatchOpenDuration;
        uint maxMatchAdjustDuration;
        uint collateralReserveBps;
    }

    struct CallPosition {
        IERC20 collateralToken;
        address trader;
        address market;
        bool isLong;
        uint executionFee;
        uint allocationId;
        uint matchmakerFee;
    }

    Config public config;

    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(address allocationAddress => uint reservedCollateralAmount) public reservedCollateralMap;
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
        bytes32 _positionKey = Position.getPositionKey(_allocationAddress, _market, address(_collateralToken), _isLong);
        return _getPositionSizeInUsd(_positionKey);
    }

    function matchmake(
        Account _account,
        Subscribe _subscribe,
        CallPosition calldata _callPosition,
        address[] calldata _puppetList,
        address _feeReceiver
    ) external payable auth returns (address _allocationAddress, bytes32 _requestKey) {
        if (_callPosition.matchmakerFee == 0) revert Error.Mirror__InvalidMatchmakerExecutionFeeAmount();
        uint _puppetCount = _puppetList.length;
        if (_puppetCount == 0) revert Error.Mirror__PuppetListEmpty();
        if (_puppetCount > config.maxPuppetList) revert Error.Mirror__PuppetListTooLarge(_puppetCount, config.maxPuppetList);

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callPosition.collateralToken, _callPosition.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callPosition.allocationId);
        bytes32 _traderPositionKey = Position.getPositionKey(
            _callPosition.trader, _callPosition.market, address(_callPosition.collateralToken), _callPosition.isLong
        );

        uint _traderSizeInUsd = _getPositionSizeInUsd(_traderPositionKey);
        uint _traderSizeInTokens = _getPositionSizeInTokens(_traderPositionKey);
        uint _traderCollateral = _getPositionCollateral(_traderPositionKey);
        if (_traderSizeInUsd == 0 || _traderCollateral == 0) revert Error.Mirror__NoPosition();
        if (_traderSizeInTokens == 0) revert Error.Mirror__NoPosition();

        uint _traderIncreasedAt = _getPositionIncreasedAtTime(_traderPositionKey);
        if (block.timestamp > _traderIncreasedAt + config.maxMatchOpenDuration) {
            revert Error.Mirror__TraderPositionTooOld();
        }

        _allocationAddress = _account.getAllocationAddress(_allocationKey);
        bytes32 _positionKey = Position.getPositionKey(
            _allocationAddress, _callPosition.market, address(_callPosition.collateralToken), _callPosition.isLong
        );
        if (_getPositionSizeInUsd(_positionKey) != 0) revert Error.Mirror__PositionAlreadyOpen();

        Subscribe.RuleParams[] memory _rules = _subscribe.getRuleList(_traderMatchingKey, _puppetList);
        uint[] memory _allocatedList = new uint[](_puppetCount);
        uint[] memory _nextBalanceList = _account.getBalanceList(_callPosition.collateralToken, _puppetList);

        uint _allocated = 0;
        uint _remainingFee = _callPosition.matchmakerFee;

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
            _nextBalanceList[_i] -= _contribution;
            _allocated += _netAllocation;
            lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
        }

        if (_remainingFee != 0) {
            revert Error.Mirror__MatchmakerFeeNotFullyCovered(_callPosition.matchmakerFee - _remainingFee, _callPosition.matchmakerFee);
        }
        if (_callPosition.matchmakerFee >= Precision.applyFactor(config.maxMatchmakerFeeToAllocationRatio, _allocated + _callPosition.matchmakerFee)) {
            revert Error.Mirror__MatchmakerFeeExceedsCostFactor(_callPosition.matchmakerFee, _allocated + _callPosition.matchmakerFee);
        }

        _allocationAddress = _account.createAllocationAccount(_allocationKey);
        allocationMap[_allocationAddress] = _allocated;
        allocationPuppetList[_allocationAddress] = _allocatedList;
        reservedCollateralMap[_allocationAddress] = Math.mulDiv(_allocated, config.collateralReserveBps, 10_000);

        _account.setBalanceList(_callPosition.collateralToken, _puppetList, _nextBalanceList);
        _account.transferOut(_callPosition.collateralToken, _feeReceiver, _callPosition.matchmakerFee);
        _account.transferOut(_callPosition.collateralToken, config.gmxOrderVault, _allocated);

        uint _reserved = reservedCollateralMap[_allocationAddress];
        uint _effectiveCollateral = _allocated > _reserved ? _allocated - _reserved : 0;
        if (_effectiveCollateral == 0) revert Error.Mirror__InvalidSizeDelta();
        uint _sizeDelta = Math.mulDiv(_traderSizeInUsd, _effectiveCollateral, _traderCollateral);
        uint _acceptablePrice = (_traderSizeInUsd + _traderSizeInTokens - 1) / _traderSizeInTokens;

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callPosition.collateralToken,
            _callPosition.market,
            _callPosition.isLong,
            _callPosition.executionFee,
            Order.OrderType.MarketIncrease,
            _sizeDelta,
            _allocated,
            _acceptablePrice
        );

        lastTargetSizeMap[_positionKey] = _sizeDelta;

        _logEvent(
            "Match",
            abi.encode(
                _callPosition.collateralToken,
                _callPosition.trader,
                _callPosition.market,
                _feeReceiver,
                _callPosition.isLong,
                _callPosition.executionFee,
                _callPosition.allocationId,
                _callPosition.matchmakerFee,
                _allocationAddress,
                _traderMatchingKey,
                _traderPositionKey,
                _positionKey,
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
        CallPosition calldata _callPosition,
        address[] calldata _puppetList,
        address _feeReceiver
    ) external payable auth returns (bytes32 _requestKey) {
        if (_callPosition.matchmakerFee == 0) revert Error.Mirror__InvalidMatchmakerExecutionFeeAmount();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callPosition.collateralToken, _callPosition.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callPosition.allocationId)
        );
        uint _allocated = allocationMap[_allocationAddress];
        if (_allocated == 0) revert Error.Mirror__InvalidAllocation(_allocationAddress);

        if (_callPosition.matchmakerFee >= Precision.applyFactor(config.maxMatchmakerFeeToAdjustmentRatio, _allocated)) {
            revert Error.Mirror__MatchmakerFeeExceedsAdjustmentRatio(_callPosition.matchmakerFee, _allocated);
        }

        bytes32 _positionKey = Position.getPositionKey(
            _allocationAddress, _callPosition.market, address(_callPosition.collateralToken), _callPosition.isLong
        );
        uint _currentSize = _getPositionSizeInUsd(_positionKey);
        if (_currentSize == 0) revert Error.Mirror__NoPosition();
        if (_currentSize != lastTargetSizeMap[_positionKey]) revert Error.Mirror__RequestPending();

        bytes32 _traderPositionKey = Position.getPositionKey(
            _callPosition.trader, _callPosition.market, address(_callPosition.collateralToken), _callPosition.isLong
        );
        uint _traderSizeInUsd = _getPositionSizeInUsd(_traderPositionKey);
        uint _traderSizeInTokens = _getPositionSizeInTokens(_traderPositionKey);
        uint _traderCollateral = _getPositionCollateral(_traderPositionKey);
        if (_traderSizeInUsd == 0 || _traderCollateral == 0 || _traderSizeInTokens == 0) revert Error.Mirror__NoPosition();

        uint _traderLastUpdateTime = Math.max(
            _getPositionIncreasedAtTime(_traderPositionKey),
            _getPositionDecreasedAtTime(_traderPositionKey)
        );
        if (block.timestamp > _traderLastUpdateTime + config.maxMatchAdjustDuration) {
            revert Error.Mirror__TraderPositionTooOld();
        }

        uint _allocationCollateral = _getPositionCollateral(_positionKey);
        uint _allocationSizeInTokens = _getPositionSizeInTokens(_positionKey);
        if (_allocationCollateral == 0 || _allocationSizeInTokens == 0) revert Error.Mirror__NoPosition();

        uint _reservedCollateral = reservedCollateralMap[_allocationAddress];
        uint _effectiveAllocationCollateral = _allocationCollateral > _reservedCollateral ? _allocationCollateral - _reservedCollateral : 0;
        if (_effectiveAllocationCollateral == 0) revert Error.Mirror__InvalidSizeDelta();
        uint _targetSize = Math.mulDiv(_traderSizeInUsd, _effectiveAllocationCollateral, _traderCollateral);
        bool _isIncrease = _targetSize > _currentSize;
        uint _sizeDelta = _isIncrease ? _targetSize - _currentSize : _currentSize - _targetSize;
        if (_sizeDelta == 0) revert Error.Mirror__InvalidSizeDelta();

        uint[] memory _nextBalanceList = _collectMatchmakerFee(
            _account, _allocationAddress, _callPosition.collateralToken, _puppetList, _callPosition.matchmakerFee, _feeReceiver
        );

        uint _acceptablePrice = _isIncrease
            ? (_callPosition.isLong ? type(uint).max : 0)
            : (_callPosition.isLong ? 0 : type(uint).max);

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callPosition.collateralToken,
            _callPosition.market,
            _callPosition.isLong,
            _callPosition.executionFee,
            _isIncrease ? Order.OrderType.MarketIncrease : Order.OrderType.MarketDecrease,
            _sizeDelta,
            0,
            _acceptablePrice
        );

        lastTargetSizeMap[_positionKey] = _targetSize;

        _logEvent(
            "Adjust",
            abi.encode(
                _allocationAddress,
                _requestKey,
                _feeReceiver,
                _callPosition.executionFee,
                _callPosition.matchmakerFee,
                _isIncrease,
                _sizeDelta,
                _currentSize,
                _targetSize,
                _nextBalanceList
            )
        );
    }

    function close(
        Account _account,
        CallPosition calldata _callPosition,
        address[] calldata _puppetList,
        uint8 _reason,
        address _feeReceiver
    ) external payable auth returns (bytes32 _requestKey) {
        if (_callPosition.matchmakerFee == 0) revert Error.Mirror__InvalidMatchmakerExecutionFeeAmount();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callPosition.collateralToken, _callPosition.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callPosition.allocationId)
        );
        uint _allocated = allocationMap[_allocationAddress];
        if (_allocated == 0) revert Error.Mirror__InvalidAllocation(_allocationAddress);

        if (_callPosition.matchmakerFee >= Precision.applyFactor(config.maxMatchmakerFeeToCloseRatio, _allocated)) {
            revert Error.Mirror__MatchmakerFeeExceedsCloseRatio(_callPosition.matchmakerFee, _allocated);
        }

        bytes32 _positionKey = Position.getPositionKey(
            _allocationAddress, _callPosition.market, address(_callPosition.collateralToken), _callPosition.isLong
        );
        uint _currentSize = _getPositionSizeInUsd(_positionKey);
        if (_currentSize == 0) revert Error.Mirror__NoPosition();
        if (_currentSize != lastTargetSizeMap[_positionKey]) revert Error.Mirror__RequestPending();

        uint _puppetCount = _puppetList.length;
        uint[] memory _nextBalanceList = _collectMatchmakerFee(
            _account, _allocationAddress, _callPosition.collateralToken, _puppetList, _callPosition.matchmakerFee, _feeReceiver
        );

        uint _acceptablePrice = _callPosition.isLong ? 0 : type(uint).max;

        _requestKey = _submitOrder(
            _account,
            _allocationAddress,
            _callPosition.collateralToken,
            _callPosition.market,
            _callPosition.isLong,
            _callPosition.executionFee,
            Order.OrderType.MarketDecrease,
            _currentSize,
            0,
            _acceptablePrice
        );

        lastTargetSizeMap[_positionKey] = 0;

        _logEvent(
            "Close",
            abi.encode(
                _allocationAddress,
                _requestKey,
                _feeReceiver,
                _callPosition.executionFee,
                _callPosition.matchmakerFee,
                _currentSize,
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
        uint _initialCollateralDeltaAmount,
        uint _acceptablePrice
    ) internal returns (bytes32 requestKey) {
        if (msg.value < _executionFee) {
            revert Error.Mirror__InsufficientGmxExecutionFee(msg.value, _executionFee);
        }

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

    function _collectMatchmakerFee(
        Account _account,
        address _allocationAddress,
        IERC20 _collateralToken,
        address[] calldata _puppetList,
        uint _matchmakerFee,
        address _feeReceiver
    ) internal returns (uint[] memory _nextBalanceList) {
        uint[] memory _allocationList = allocationPuppetList[_allocationAddress];
        uint _puppetCount = _puppetList.length;
        if (_allocationList.length != _puppetCount) revert Error.Mirror__PuppetListMismatch(_puppetCount, _allocationList.length);

        uint _remainingFee = _matchmakerFee;
        uint _allocationToRedistribute = 0;
        _nextBalanceList = _account.getBalanceList(_collateralToken, _puppetList);

        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _puppetAllocation = _allocationList[_i];
            if (_puppetAllocation == 0) continue;

            uint _remainingPuppets = _puppetCount - _i;
            uint _feeShare = (_remainingFee + _remainingPuppets - 1) / _remainingPuppets;
            if (_feeShare > _remainingFee) _feeShare = _remainingFee;

            uint _balance = _nextBalanceList[_i];
            if (_balance >= _feeShare) {
                _nextBalanceList[_i] = _balance - _feeShare;
                _remainingFee -= _feeShare;

                if (_allocationToRedistribute > 0) {
                    uint _shareOfRedistribution = _allocationToRedistribute / _remainingPuppets;
                    _allocationList[_i] += _shareOfRedistribution;
                    _allocationToRedistribute -= _shareOfRedistribution;
                }
            } else {
                if (_balance != 0) {
                    _remainingFee -= _balance;
                    _nextBalanceList[_i] = 0;
                }

                uint _missing = _feeShare - _balance;
                if (_missing == 0) continue;

                if (_puppetAllocation > _missing) {
                    _allocationList[_i] = _puppetAllocation - _missing;
                    _allocationToRedistribute += _missing;
                } else {
                    _allocationList[_i] = 0;
                    _allocationToRedistribute += _puppetAllocation;
                }
            }
        }

        if (_remainingFee != 0) {
            revert Error.Mirror__MatchmakerFeeNotFullyCovered(_matchmakerFee - _remainingFee, _matchmakerFee);
        }

        allocationPuppetList[_allocationAddress] = _allocationList;
        if (_allocationToRedistribute != 0) revert Error.Mirror__AllocationNotFullyRedistributed(_allocationToRedistribute);

        _account.setBalanceList(_collateralToken, _puppetList, _nextBalanceList);
        _account.transferOut(_collateralToken, _feeReceiver, _matchmakerFee);
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.gmxExchangeRouter == IGmxExchangeRouter(address(0))) revert("Invalid GMX Router address");
        if (_config.gmxDataStore == IGmxReadDataStore(address(0))) revert("Invalid GMX Data Store address");
        if (_config.gmxOrderVault == address(0)) revert("Invalid GMX Order Vault address");
        if (_config.referralCode == bytes32(0)) revert("Invalid Referral Code");
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        if (_config.maxMatchmakerFeeToAllocationRatio == 0) revert("Invalid max matchmaker fee to allocation ratio");
        if (_config.maxMatchmakerFeeToAdjustmentRatio == 0) revert("Invalid max matchmaker fee to adjustment ratio");
        if (_config.maxMatchmakerFeeToCloseRatio == 0) revert("Invalid max matchmaker fee to close ratio");
        if (_config.collateralReserveBps >= 10_000) revert("Invalid collateral reserve bps");

        config = _config;
    }

    function _getPositionSizeInUsd(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.SIZE_IN_USD)));
    }

    function _getPositionCollateral(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.COLLATERAL_AMOUNT)));
    }

    function _getPositionIncreasedAtTime(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.INCREASED_AT_TIME)));
    }

    function _getPositionDecreasedAtTime(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.DECREASED_AT_TIME)));
    }

    function _getPositionSizeInTokens(bytes32 _positionKey) internal view returns (uint) {
        return config.gmxDataStore.getUint(keccak256(abi.encode(_positionKey, PositionStoreUtils.SIZE_IN_TOKENS)));
    }
}
