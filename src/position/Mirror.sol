// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Error} from "./../utils/Error.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {Account} from "./Account.sol";
import {Rule} from "./Rule.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "./interface/IGmxReadDataStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Mirror is CoreContract {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxReadDataStore gmxDataStore;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        uint maxPuppetList;
        uint maxKeeperFeeToAllocationRatio;
        uint maxKeeperFeeToAdjustmentRatio;
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

    struct CallPosition {
        IERC20 collateralToken;
        bytes32 traderRequestKey;
        address trader;
        address market;
        address keeperFeeReceiver;
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
        uint allocationId;
        uint keeperFee;
    }

    struct StalledPositionParams {
        IERC20 collateralToken;
        address market;
        address trader;
        bool isLong;
        uint executionFee;
        uint acceptablePrice;
        uint allocationId;
    }

    Config public config;

    // Position tracking
    mapping(address allocationAddress => Position) public positionMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    // Allocation tracking
    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    /**
     * @notice Get current configuration parameters
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Get position details for an allocation
     */
    function getPosition(
        address _allocationAddress
    ) external view returns (Position memory) {
        return positionMap[_allocationAddress];
    }

    /**
     * @notice Get total allocated amount for an allocation
     */
    function getAllocation(
        address _allocationAddress
    ) external view returns (uint) {
        return allocationMap[_allocationAddress];
    }

    /**
     * @notice Get puppet allocation amounts for an allocation
     */
    function getAllocationPuppetList(
        address _allocationAddress
    ) external view returns (uint[] memory) {
        return allocationPuppetList[_allocationAddress];
    }

    /**
     * @notice Get last activity timestamp for a puppet/trader combination
     */
    function getLastActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external view returns (uint) {
        return lastActivityThrottleMap[_traderMatchingKey][_puppet];
    }

    /**
     * @notice Initialize trader activity throttle - called by Rule contract
     */
    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    /**
     * @notice Get trader's position size in USD from GMX
     */
    function getTraderPositionSizeInUsd(
        bytes32 _traderPositionKey
    ) external view returns (uint) {
        return GmxPositionUtils.getPositionSizeInUsd(config.gmxDataStore, _traderPositionKey);
    }

    /**
     * @notice Get trader's collateral amount from GMX
     */
    function getTraderPositionCollateralAmount(
        bytes32 _traderPositionKey
    ) external view returns (uint) {
        return GmxPositionUtils.getPositionCollateralAmount(config.gmxDataStore, _traderPositionKey);
    }

    /**
     * @notice Opens a new mirrored position by allocating puppet funds to copy a trader's position
     * @dev Validates trader position exists, calculates puppet allocations based on rules, submits GMX order
     */
    function requestOpen(
        Account _account,
        Rule _ruleContract,
        address _callbackContract,
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (address _allocationAddress, bytes32 _requestKey) {
        require(_callParams.isIncrease, Error.Mirror__InitialMustBeIncrease());
        require(_callParams.collateralDelta > 0, Error.Mirror__InvalidCollateralDelta());
        require(_callParams.sizeDeltaInUsd > 0, Error.Mirror__InvalidSizeDelta());

        bytes32 _traderPositionKey = GmxPositionUtils.getPositionKey(
            _callParams.trader, _callParams.market, _callParams.collateralToken, _callParams.isLong
        );

        require(
            GmxPositionUtils.getPositionSizeInUsd(config.gmxDataStore, _traderPositionKey) > 0,
            Error.Mirror__TraderPositionNotFound(_callParams.trader, _traderPositionKey)
        );

        uint _puppetCount = _puppetList.length;
        require(_puppetCount > 0, Error.Mirror__PuppetListEmpty());
        require(_puppetCount <= config.maxPuppetList, "Puppet list too large");

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId);
        _allocationAddress = _account.createAllocationAccount(_allocationKey);

        Rule.RuleParams[] memory _rules = _ruleContract.getRuleList(_traderMatchingKey, _puppetList);
        uint _feePerPuppet = _callParams.keeperFee / _puppetCount;
        uint[] memory _allocatedList = new uint[](_puppetCount);
        uint[] memory _balanceList = _account.getBalanceList(_callParams.collateralToken, _puppetList);
        allocationPuppetList[_allocationAddress] = new uint[](_puppetCount);

        uint _allocated = 0;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            address _puppet = _puppetList[_i];
            Rule.RuleParams memory _rule = _rules[_i];

            if (
                _rule.expiry > block.timestamp
                    && block.timestamp >= lastActivityThrottleMap[_traderMatchingKey][_puppet]
            ) {
                uint _puppetAllocation = Precision.applyBasisPoints(_rule.allowanceRate, _balanceList[_i]);

                if (_feePerPuppet > Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _puppetAllocation)) {
                    continue;
                }

                _allocatedList[_i] = _puppetAllocation;
                allocationPuppetList[_allocationAddress][_i] = _puppetAllocation;
                _balanceList[_i] -= _puppetAllocation;
                _allocated += _puppetAllocation;
                lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
            }
        }

        _account.setBalanceList(_callParams.collateralToken, _puppetList, _balanceList);

        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _allocated),
            Error.Mirror__KeeperFeeExceedsCostFactor(_callParams.keeperFee, _allocated)
        );

        _allocated -= _callParams.keeperFee;
        allocationMap[_allocationAddress] = _allocated;

        _account.transferOut(_callParams.collateralToken, _callParams.keeperFeeReceiver, _callParams.keeperFee);
        _account.transferOut(_callParams.collateralToken, config.gmxOrderVault, _allocated);

        uint _traderTargetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
        uint _sizeDelta = Math.mulDiv(_callParams.sizeDeltaInUsd, _allocated, _callParams.collateralDelta);

        _requestKey = _submitOrder(
            _account,
            _callParams,
            _allocationAddress,
            GmxPositionUtils.OrderType.MarketIncrease,
            config.increaseCallbackGasLimit,
            _sizeDelta,
            _allocated,
            _callbackContract
        );

        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationAddress: _allocationAddress,
            traderIsIncrease: true,
            traderTargetLeverage: _traderTargetLeverage,
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "RequestOpen",
            abi.encode(
                _callParams,
                _allocationAddress,
                _traderMatchingKey,
                _traderPositionKey,
                _requestKey,
                _sizeDelta,
                _traderTargetLeverage,
                _allocated,
                _allocatedList,
                _puppetList
            )
        );
    }

    /**
     * @notice Adjusts an existing mirrored position to match trader's leverage changes
     * @dev Handles keeper fee collection from puppets, calculates new leverage target, submits GMX order
     */
    function requestAdjust(
        Account _account,
        address _callbackContract,
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32 _requestKey) {
        require(_callParams.collateralDelta > 0 || _callParams.sizeDeltaInUsd > 0, Error.Mirror__NoAdjustmentRequired());

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId)
        );

        uint _allocated = allocationMap[_allocationAddress];
        require(_allocated > 0, Error.Mirror__InvalidAllocation(_allocationAddress));
        require(_callParams.keeperFee > 0, Error.Mirror__InvalidKeeperExecutionFeeAmount());
        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _allocated),
            Error.Mirror__KeeperFeeExceedsAdjustmentRatio(_callParams.keeperFee, _allocated)
        );

        uint[] memory _allocationList = allocationPuppetList[_allocationAddress];
        uint _puppetCount = _puppetList.length;
        require(
            _allocationList.length == _puppetCount,
            Error.Mirror__PuppetListMismatch(_allocationList.length, _puppetCount)
        );
        require(
            _allocated > _callParams.keeperFee,
            Error.Mirror__InsufficientAllocationForKeeperFee(_allocated, _callParams.keeperFee)
        );

        uint _remainingKeeperFeeToCollect = _callParams.keeperFee;
        uint _keeperExecutionFeeInsolvency = 0;
        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.collateralToken, _puppetList);

        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _puppetAllocation = _allocationList[_i];

            if (_puppetAllocation == 0) continue;

            uint _remainingPuppets = _puppetCount - _i;
            uint _feePerRemainingPuppet = (_remainingKeeperFeeToCollect + _remainingPuppets - 1) / _remainingPuppets;

            if (_feePerRemainingPuppet > _remainingKeeperFeeToCollect) {
                _feePerRemainingPuppet = _remainingKeeperFeeToCollect;
            }

            if (_nextBalanceList[_i] >= _feePerRemainingPuppet) {
                _nextBalanceList[_i] -= _feePerRemainingPuppet;
                _remainingKeeperFeeToCollect -= _feePerRemainingPuppet;
            } else {
                if (_puppetAllocation > _feePerRemainingPuppet) {
                    _allocationList[_i] = _puppetAllocation - _feePerRemainingPuppet;
                } else {
                    _keeperExecutionFeeInsolvency += _puppetAllocation;
                    _allocationList[_i] = 0;
                }
            }
        }

        _account.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalanceList);

        require(
            _remainingKeeperFeeToCollect == 0,
            Error.Mirror__KeeperFeeNotFullyCovered(0, _remainingKeeperFeeToCollect)
        );

        _allocated -= _keeperExecutionFeeInsolvency;
        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _allocated),
            Error.Mirror__KeeperFeeExceedsAdjustmentRatio(_callParams.keeperFee, _allocated)
        );
        allocationPuppetList[_allocationAddress] = _allocationList;
        allocationMap[_allocationAddress] = _allocated;

        _account.transferOut(_callParams.collateralToken, _callParams.keeperFeeReceiver, _callParams.keeperFee);

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.Mirror__PositionNotFound(_allocationAddress));
        require(_position.traderCollateral > 0, Error.Mirror__TraderCollateralZero(_allocationAddress));

        uint _puppetLeverage = Precision.toBasisPoints(_position.size, _allocated);
        uint _traderTargetLeverage = _callParams.isIncrease
            ? Precision.toBasisPoints(
                _position.traderSize + _callParams.sizeDeltaInUsd, _position.traderCollateral + _callParams.collateralDelta
            )
            : _position.traderSize > _callParams.sizeDeltaInUsd && _position.traderCollateral > _callParams.collateralDelta
                ? Precision.toBasisPoints(
                    _position.traderSize - _callParams.sizeDeltaInUsd, _position.traderCollateral - _callParams.collateralDelta
                )
                : 0;

        require(_traderTargetLeverage != _puppetLeverage, Error.Mirror__NoAdjustmentRequired());
        require(_puppetLeverage > 0, Error.Mirror__InvalidCurrentLeverage());

        bool _isIncrease = _traderTargetLeverage > _puppetLeverage;
        uint _sizeDelta = _traderTargetLeverage == 0
            ? _position.size
            : Math.mulDiv(
                _position.size,
                _isIncrease ? _traderTargetLeverage - _puppetLeverage : _puppetLeverage - _traderTargetLeverage,
                _puppetLeverage
            );

        bytes32 _traderPositionKey = GmxPositionUtils.getPositionKey(
            _callParams.trader, _callParams.market, _callParams.collateralToken, _callParams.isLong
        );

        if (_isIncrease) {
            require(
                GmxPositionUtils.getPositionSizeInUsd(config.gmxDataStore, _traderPositionKey) > 0,
                Error.Mirror__TraderPositionNotFound(_callParams.trader, _traderPositionKey)
            );
        }

        _requestKey = _submitOrder(
            _account,
            _callParams,
            _allocationAddress,
            _isIncrease ? GmxPositionUtils.OrderType.MarketIncrease : GmxPositionUtils.OrderType.MarketDecrease,
            _isIncrease ? config.increaseCallbackGasLimit : config.decreaseCallbackGasLimit,
            _sizeDelta,
            0,
            _callbackContract
        );

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
                _callParams,
                _allocationAddress,
                _traderMatchingKey,
                _traderPositionKey,
                _requestKey,
                _isIncrease,
                _allocated,
                _sizeDelta,
                _traderTargetLeverage,
                _keeperExecutionFeeInsolvency,
                _allocationList
            )
        );
    }

    /**
     * @notice Closes a mirrored position when the trader's position no longer exists on GMX
     * @dev Verifies trader position is closed, then submits full decrease order for puppet position
     */
    function requestCloseStalledPosition(
        Account _account,
        StalledPositionParams calldata _params,
        address[] calldata _puppetList,
        address _callbackContract
    ) external payable auth returns (bytes32 _requestKey) {
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(
                _puppetList,
                PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader),
                _params.allocationId
            )
        );

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.Mirror__PositionNotFound(_allocationAddress));

        bytes32 _traderPositionKey =
            GmxPositionUtils.getPositionKey(_params.trader, _params.market, _params.collateralToken, _params.isLong);
        require(
            GmxPositionUtils.getPositionSizeInUsd(config.gmxDataStore, _traderPositionKey) == 0,
            Error.Mirror__PositionNotStalled(_allocationAddress, _traderPositionKey)
        );

        _requestKey = _submitOrder(
            _account,
            CallPosition({
                collateralToken: _params.collateralToken,
                traderRequestKey: bytes32(0),
                trader: _params.trader,
                market: _params.market,
                isIncrease: false,
                isLong: _params.isLong,
                executionFee: _params.executionFee,
                collateralDelta: 0,
                sizeDeltaInUsd: _position.size,
                acceptablePrice: _params.acceptablePrice,
                triggerPrice: 0,
                allocationId: 0,
                keeperFee: 0,
                keeperFeeReceiver: address(0)
            }),
            _allocationAddress,
            GmxPositionUtils.OrderType.MarketDecrease,
            config.decreaseCallbackGasLimit,
            _position.size,
            0,
            _callbackContract
        );

        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationAddress: _allocationAddress,
            traderIsIncrease: false,
            traderTargetLeverage: 0,
            traderSizeDelta: _position.size,
            traderCollateralDelta: 0,
            sizeDelta: _position.size
        });

        _logEvent(
            "RequestCloseStalledPosition",
            abi.encode(
                _params,
                _allocationAddress,
                _traderPositionKey,
                _requestKey
            )
        );
    }

    /**
     * @notice Execute position adjustment after GMX order confirmation
     * @dev Updates position tracking based on trader's leverage changes
     */
    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        require(_request.allocationAddress != address(0), Error.Mirror__ExecutionRequestMissing(_requestKey));

        Position memory _position = positionMap[_request.allocationAddress];
        delete requestAdjustmentMap[_requestKey];

        if (_request.traderTargetLeverage == 0) {
            delete positionMap[_request.allocationAddress];
            _logEvent("Execute", abi.encode(_request.allocationAddress, _requestKey, 0, 0, 0, 0));
            return;
        }

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

        if (_request.traderTargetLeverage > 0) {
            if (_request.traderIsIncrease) {
                _position.size += _request.sizeDelta;
            } else {
                _position.size = (_position.size > _request.sizeDelta) ? _position.size - _request.sizeDelta : 0;
            }
        }

        if (_position.size == 0) {
            delete positionMap[_request.allocationAddress];
        } else {
            positionMap[_request.allocationAddress] = _position;
        }

        _logEvent(
            "Execute",
            abi.encode(
                _request.allocationAddress,
                _requestKey,
                _request.traderTargetLeverage,
                _position.size,
                _position.traderSize,
                _position.traderCollateral
            )
        );
    }

    /**
     * @notice Mark a position as liquidated
     * @dev Removes position from tracking when liquidated on GMX
     */
    function liquidate(
        address _allocationAddress
    ) external auth {
        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.Mirror__PositionNotFound(_allocationAddress));

        delete positionMap[_allocationAddress];
        _logEvent("Liquidate", abi.encode(_allocationAddress));
    }

    function _submitOrder(
        Account _account,
        CallPosition memory _order,
        address _allocationAddress,
        GmxPositionUtils.OrderType _orderType,
        uint _callbackGasLimit,
        uint _sizeDeltaUsd,
        uint _initialCollateralDeltaAmount,
        address _callbackContract
    ) internal returns (bytes32 requestKey) {
        require(
            msg.value >= _order.executionFee, Error.Mirror__InsufficientGmxExecutionFee(msg.value, _order.executionFee)
        );

        bytes memory gmxCallData = abi.encodeWithSelector(
            config.gmxExchangeRouter.createOrder.selector,
            GmxPositionUtils.CreateOrderParams({
                addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                    receiver: _allocationAddress,
                    cancellationReceiver: _allocationAddress,
                    callbackContract: _callbackContract,
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
            _account.execute(_allocationAddress, address(config.gmxExchangeRouter), gmxCallData, gasleft());

        if (!success) {
            ErrorUtils.revertWithParsedMessage(returnData);
        }

        requestKey = abi.decode(returnData, (bytes32));
        require(requestKey != bytes32(0), Error.Mirror__OrderCreationFailed());
    }

    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.gmxExchangeRouter != IGmxExchangeRouter(address(0)), "Invalid GMX Router address");
        require(_config.gmxOrderVault != address(0), "Invalid GMX Order Vault address");
        require(_config.referralCode != bytes32(0), "Invalid Referral Code");
        require(_config.increaseCallbackGasLimit > 0, "Invalid Increase Callback Gas Limit");
        require(_config.decreaseCallbackGasLimit > 0, "Invalid Decrease Callback Gas Limit");
        require(_config.maxPuppetList > 0, "Invalid max puppet list");
        require(_config.maxKeeperFeeToAllocationRatio > 0, "Invalid max keeper fee to allocation ratio");
        require(_config.maxKeeperFeeToAdjustmentRatio > 0, "Invalid max keeper fee to adjustment ratio");

        config = _config;
    }
}
