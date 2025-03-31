// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {FeeMarketplace} from "../tokenomics/FeeMarketplace.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchRule} from "./../position/MatchRule.sol";
import {AllocationAccount} from "./../shared/AllocationAccount.sol";
import {AllocationStore} from "./../shared/AllocationStore.sol";
import {Error} from "./../shared/Error.sol";
import {TokenRouter} from "./../shared/TokenRouter.sol";
import {CallUtils} from "./../utils/CallUtils.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {AllocationAccountUtils} from "./utils/AllocationAccountUtils.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract MirrorPosition is CoreContract {
    using SafeCast for uint;

    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        uint platformSettleFeeFactor;
        uint maxPuppetList;
        uint minExecutionCostFactor;
    }

    struct Position {
        uint size;
        uint traderSize;
        uint traderCollateral;
    }

    struct CallAllocation {
        IERC20 collateralToken;
        address trader;
        uint executionFee;
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
        uint allocationId;
    }

    struct CallSettle {
        IERC20 allocationToken;
        IERC20 distributeToken;
        address trader;
        uint allocationId;
    }

    struct RequestAdjustment {
        bytes32 allocationKey;
        bool traderIsIncrease;
        uint targetLeverage;
        uint traderCollateralDelta;
        uint traderSizeDelta;
        uint sizeDelta;
    }

    Config public config;

    AllocationStore immutable allocationStore;
    MatchRule immutable matchRule;
    FeeMarketplace immutable feeMarket;
    address public immutable allocationStoreImplementation;

    uint public nextAllocationId = 0;

    mapping(address => mapping(address => uint)) public activityThrottleMap;
    mapping(bytes32 => uint) public allocationMap;
    mapping(bytes32 => mapping(address => uint)) public allocationPuppetMap;
    mapping(bytes32 => Position) public positionMap;
    mapping(bytes32 => RequestAdjustment) public requestAdjustmentMap;

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getAllocation(
        bytes32 _allocationKey
    ) external view returns (uint) {
        return allocationMap[_allocationKey];
    }

    function getPosition(
        bytes32 _allocationKey
    ) external view returns (Position memory) {
        return positionMap[_allocationKey];
    }

    function getRequestAdjustment(
        bytes32 _requestKey
    ) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_requestKey];
    }

    constructor(
        IAuthority _authority,
        AllocationStore _puppetStore,
        MatchRule _matchRule,
        FeeMarketplace _feeMarket
    ) CoreContract("MirrorPosition", _authority) {
        allocationStore = _puppetStore;
        matchRule = _matchRule;
        feeMarket = _feeMarket;
        allocationStoreImplementation = address(new AllocationAccount(allocationStore));
    }

    function initializeTraderActivityThrottle(address _trader, address _puppet) external auth {
        activityThrottleMap[_trader][_puppet] = 0;
    }

    function allocate(
        CallAllocation calldata _callParams, //
        address[] calldata _puppetList
    ) external auth returns (uint) {
        uint _nextAllocationId = ++nextAllocationId;
        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _nextAllocationId);
        address _allocationAddress =
            AllocationAccountUtils.cloneDeterministic(allocationStoreImplementation, _allocationKey);
        uint _puppetListLength = _puppetList.length;

        require(_puppetListLength > 0, Error.MirrorPosition__InvalidPuppetList());
        require(_puppetListLength <= config.maxPuppetList, Error.MirrorPosition__MaxPuppetList());

        uint _allocated;

        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);

        uint _estimatedExecutionFeePerPuppet = _callParams.executionFee / _puppetListLength;

        for (uint i = 0; i < _puppetListLength; i++) {
            MatchRule.Rule memory rule = _ruleList[i];
            address _puppet = _puppetList[i];

            if (rule.expiry > block.timestamp && block.timestamp >= activityThrottleMap[_callParams.trader][_puppet]) {
                uint _balanceAllocation = Precision.applyBasisPoints(rule.allowanceRate, _nextBalanceList[i]);

                // Skip if the allocated balance is less than the minimum estimated execution cost required
                if (
                    Precision.applyFactor(config.minExecutionCostFactor, _balanceAllocation)
                        > _estimatedExecutionFeePerPuppet
                ) {
                    continue;
                }

                allocationPuppetMap[_allocationKey][_puppet] = _balanceAllocation;
                _nextBalanceList[i] -= _balanceAllocation;
                _allocated += _balanceAllocation;
                activityThrottleMap[_callParams.trader][_puppet] = block.timestamp + rule.throttleActivity;
            }
        }

        allocationStore.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalanceList);

        require(_allocated > 0, Error.MirrorPosition__InvalidAllocation());

        allocationMap[_allocationKey] = _allocated;

        _logEvent(
            "Allocate",
            abi.encode(_matchKey, _allocationKey, _allocationAddress, _nextAllocationId, _allocated, _puppetListLength)
        );

        return _nextAllocationId;
    }

    function mirror(
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32 _requestKey) {
        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _callParams.allocationId);

        Position memory _position = positionMap[_allocationKey];

        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );

        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _targetLeverage;
        uint _sizeDelta;

        if (_position.size == 0) {
            require(_callParams.isIncrease, Error.MirrorPosition__InitialMustBeIncrease());
            require(_callParams.collateralDelta > 0, Error.MirrorPosition__InvalidCollateralDelta());
            require(_callParams.sizeDeltaInUsd > 0, Error.MirrorPosition__InvalidSizeDelta());

            uint _allocated = allocationMap[_allocationKey];

            _targetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
            _sizeDelta = _callParams.sizeDeltaInUsd * _allocated / _callParams.collateralDelta;
            allocationStore.transferOut(_callParams.collateralToken, config.gmxOrderVault, _allocated);

            _requestKey = _submitOrder(
                _callParams,
                _allocationAddress,
                GmxPositionUtils.OrderType.MarketIncrease,
                config.increaseCallbackGasLimit,
                _allocated,
                _sizeDelta
            );
        } else {
            uint _currentLeverage = Precision.toBasisPoints(_position.traderSize, _position.traderCollateral);
            _targetLeverage = _callParams.isIncrease
                ? Precision.toBasisPoints(
                    _position.traderSize + _callParams.sizeDeltaInUsd,
                    _position.traderCollateral + _callParams.collateralDelta
                )
                : _position.traderSize > _callParams.sizeDeltaInUsd
                    ? Precision.toBasisPoints(
                        _position.traderSize - _callParams.sizeDeltaInUsd,
                        _position.traderCollateral - _callParams.collateralDelta
                    )
                    : 0;

            if (_targetLeverage > _currentLeverage) {
                _sizeDelta = _position.size * (_targetLeverage - _currentLeverage) / _currentLeverage;

                _requestKey = _submitOrder(
                    _callParams,
                    _allocationAddress,
                    GmxPositionUtils.OrderType.MarketIncrease,
                    config.increaseCallbackGasLimit,
                    _sizeDelta,
                    0
                );
            } else {
                _sizeDelta = _position.size * (_currentLeverage - _targetLeverage) / _currentLeverage;
                _requestKey = _submitOrder(
                    _callParams,
                    _allocationAddress,
                    GmxPositionUtils.OrderType.MarketDecrease,
                    config.decreaseCallbackGasLimit,
                    _sizeDelta,
                    0
                );
            }
        }

        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationKey: _allocationKey,
            traderIsIncrease: _callParams.isIncrease,
            targetLeverage: _targetLeverage,
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "Mirror",
            abi.encode(_matchKey, _allocationKey, _allocationAddress, _sizeDelta, _targetLeverage, _requestKey)
        );
    }

    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        Position memory _position = positionMap[_request.allocationKey];

        require(_request.allocationKey != bytes32(0), Error.MirrorPosition__ExecutionRequestMissing());

        if (_request.targetLeverage > 0) {
            uint _currentLeverage = _position.traderCollateral > 0
                ? Precision.toBasisPoints(_position.traderSize, _position.traderCollateral)
                : 0;

            if (_request.targetLeverage > _currentLeverage) {
                _position.traderSize += _request.traderSizeDelta;
                _position.traderCollateral += _request.traderCollateralDelta;
                _position.size += _request.sizeDelta;

                positionMap[_request.allocationKey] = _position;
            } else {
                if (_request.traderIsIncrease) {
                    _position.traderSize += _request.traderSizeDelta;
                    _position.traderCollateral += _request.traderCollateralDelta;
                } else {
                    _position.traderSize -= _request.traderSizeDelta;
                    _position.traderCollateral -= _request.traderCollateralDelta;
                }
                _position.size -= _request.sizeDelta;
                positionMap[_request.allocationKey] = _position;
            }
        } else {
            delete positionMap[_request.allocationKey];
        }

        delete requestAdjustmentMap[_requestKey];

        _logEvent(
            "Execute",
            abi.encode(
                _request.allocationKey,
                _requestKey,
                _position.traderSize,
                _position.traderCollateral,
                _position.size,
                _request.targetLeverage
            )
        );
    }

    function settle(CallSettle calldata _callParams, address[] calldata _puppetList) external auth {
        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.allocationToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _callParams.allocationId);
        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );

        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _puppetListLength = _puppetList.length;
        require(_puppetListLength > 0, Error.MirrorPosition__InvalidPuppetList());

        uint _allocated = allocationMap[_allocationKey];
        require(_allocated > 0, Error.MirrorPosition__InvalidAllocation());

        uint _settledBalance = _callParams.distributeToken.balanceOf(_allocationAddress);
        require(_settledBalance > 0, Error.MirrorPosition__NoSettledFunds());

        (bool success,) = AllocationAccount(_allocationAddress).execute(
            address(_callParams.distributeToken),
            abi.encodeWithSelector(
                _callParams.distributeToken.transfer.selector, address(allocationStore), _settledBalance
            )
        );
        require(success, Error.MirrorPosition__SettlementTransferFailed());

        allocationStore.recordTransferIn(_callParams.distributeToken);

        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.distributeToken, _puppetList);
        uint _feeAmount = 0;
        uint _amountToDistribute = _settledBalance;

        if (config.platformSettleFeeFactor > 0 && feeMarket.askAmount(_callParams.distributeToken) > 0) {
            _feeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _settledBalance);

            if (_feeAmount > 0) {
                _amountToDistribute -= _feeAmount;
                feeMarket.deposit(_callParams.distributeToken, allocationStore, _feeAmount);
            }
        }

        for (uint i = 0; i < _puppetListLength; i++) {
            uint _puppetAllocation = allocationPuppetMap[_allocationKey][_puppetList[i]];

            if (_puppetAllocation == 0) continue;

            _nextBalanceList[i] += (_amountToDistribute * _puppetAllocation) / _allocated;
        }

        allocationStore.setBalanceList(_callParams.distributeToken, _puppetList, _nextBalanceList);

        _logEvent(
            "Settle",
            abi.encode(
                _matchKey, _allocationKey, _allocationAddress, _amountToDistribute, _feeAmount, _puppetListLength
            )
        );
    }

    function _submitOrder(
        CallPosition calldata _order,
        address _allocationAddress,
        GmxPositionUtils.OrderType _orderType,
        uint _callbackGasLimit,
        uint _sizeDelta,
        uint _collateralDelta
    ) internal returns (bytes32 gmxRequestKey) {
        bytes memory gmxCallData = abi.encodeWithSelector(
            config.gmxExchangeRouter.createOrder.selector,
            GmxPositionUtils.CreateOrderParams({
                addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                    receiver: _allocationAddress,
                    cancellationReceiver: _allocationAddress,
                    callbackContract: config.callbackHandler,
                    uiFeeReceiver: address(0),
                    market: _order.market,
                    initialCollateralToken: _order.collateralToken,
                    swapPath: new address[](0)
                }),
                numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                    sizeDeltaUsd: _sizeDelta,
                    initialCollateralDeltaAmount: _collateralDelta,
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

        (bool success, bytes memory returnData) =
            AllocationAccount(_allocationAddress).execute(address(config.gmxExchangeRouter), gmxCallData);

        if (!success) {
            ErrorUtils.revertWithParsedMessage(returnData);
        }

        gmxRequestKey = abi.decode(returnData, (bytes32));
        require(gmxRequestKey != bytes32(0), Error.MirrorPosition__OrderCreationFailed());
    }

    function _setConfig(
        bytes calldata _data
    ) internal override {
        config = abi.decode(_data, (Config));
        require(config.gmxExchangeRouter != IGmxExchangeRouter(address(0)), "Invalid GMX Router");
        require(config.callbackHandler != address(0), "Invalid Callback Handler");
        require(config.gmxOrderVault != address(0), "Invalid GMX Vault");
        require(config.maxPuppetList > 0, "Invalid Max Puppet List");
    }
}
