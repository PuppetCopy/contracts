// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        uint limitAllocationListLength;
        uint platformFee;
    }

    struct Position {
        uint allocated;
        uint mpSize;
        uint mpCollateral;
        uint traderSize;
        uint traderCollateral;
    }

    struct PositionParams {
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

    struct RequestAdjustment {
        bytes32 allocationKey;
        PositionUtils.AjustmentType targetLeverageType;
        uint puppetSizeDelta;
        uint puppetCollateralDelta;
        uint traderSizeDelta;
        uint traderCollateralDelta;
    }
    // uint executionGasFee;

    Config public config;

    AllocationStore immutable allocationStore;
    MatchRule immutable matchRule;
    FeeMarketplace immutable feeMarket;
    address public immutable allocationStoreImplementation;

    uint public nextAllocationId = 1;

    mapping(address trader => mapping(address puppet => uint)) public activityThrottleMap;
    mapping(bytes32 allocationkey => uint) public allocationMap;
    mapping(bytes32 allocationkey => mapping(address puppet => uint)) public allocationPuppetMap;
    mapping(bytes32 allocationkey => Position) public positionMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

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

    function initializeTraderAcitityThrottle(address _trader, address _puppet) external auth {
        activityThrottleMap[_trader][_puppet] = 1;
    }

    function allocate(
        IERC20 _collateralToken,
        address _trader,
        address[] calldata _puppetList
    ) external auth returns (uint) {
        uint _allocationId = nextAllocationId;
        bytes32 _matchKey = PositionUtils.getMatchKey(_collateralToken, _trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _allocationId);
        address _allocationAddress =
            AllocationAccountUtils.cloneDeterministic(allocationStoreImplementation, _allocationKey);

        require(_puppetList.length <= config.limitAllocationListLength, Error.MirrorPosition__PuppetListLimit());

        uint _allocated;

        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        uint[] memory _balanceList = allocationStore.getBalanceList(_collateralToken, _puppetList);

        for (uint i = 0; i < _puppetList.length; i++) {
            MatchRule.Rule memory rule = _ruleList[i];

            // Only process if within time window
            if (rule.expiry > block.timestamp && block.timestamp > activityThrottleMap[_trader][_puppetList[i]]) {
                uint _balanceAllocation = Precision.applyBasisPoints(rule.allowanceRate, _balanceList[i]);

                allocationPuppetMap[_allocationKey][_puppetList[i]] = _balanceAllocation;
                _balanceList[i] -= _balanceAllocation;
                _allocated += _balanceAllocation;
            }

            activityThrottleMap[_trader][_puppetList[i]] = block.timestamp + rule.throttleActivity;
        }

        allocationStore.setBalanceList(_collateralToken, _puppetList, _balanceList);

        require(_allocated > 0, Error.MirrorPosition__NoPuppetAllocation());

        allocationMap[_allocationKey] = _allocated;
        nextAllocationId++;

        _logEvent(
            "Allocate",
            abi.encode(
                _collateralToken,
                _trader,
                _matchKey,
                _puppetList,
                _allocationAddress,
                _allocationKey,
                _balanceList,
                _allocationId,
                _allocated
            )
        );

        return _allocationId;
    }

    function mirror(
        PositionParams calldata _params,
        address[] calldata _puppetList,
        uint _allocationId
    ) external payable auth returns (bytes32 _requestKey) {
        bytes32 _matchKey = PositionUtils.getMatchKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _allocationId);

        Position memory _position = positionMap[_allocationKey];

        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );

        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        RequestAdjustment memory _request = RequestAdjustment({
            allocationKey: _allocationKey,
            targetLeverageType: PositionUtils.AjustmentType.INCREASE,
            traderSizeDelta: _params.sizeDeltaInUsd,
            traderCollateralDelta: _params.collateralDelta,
            puppetSizeDelta: 0,
            puppetCollateralDelta: 0
        });

        if (_position.mpSize == 0) {
            uint _allocated = allocationMap[_allocationKey];

            _request.puppetSizeDelta = _params.sizeDeltaInUsd * _allocated / _params.collateralDelta;
            _request.puppetCollateralDelta = _allocated;

            allocationStore.transferOut(_params.collateralToken, config.gmxOrderVault, _allocated);

            _requestKey = _submitOrder(
                _params,
                _allocationAddress,
                _request,
                GmxPositionUtils.OrderType.MarketIncrease,
                _allocated,
                config.increaseCallbackGasLimit
            );
        } else {
            uint _currentLeverage = Precision.toBasisPoints(_position.traderSize, _position.traderCollateral);
            uint _targetLeverage = _params.isIncrease
                ? Precision.toBasisPoints(
                    _position.traderSize + _params.sizeDeltaInUsd, _position.traderCollateral + _params.collateralDelta
                )
                : _position.traderSize > _params.sizeDeltaInUsd
                    ? Precision.toBasisPoints(
                        _position.traderSize - _params.sizeDeltaInUsd, _position.traderCollateral - _params.collateralDelta
                    )
                    : 0;

            if (_targetLeverage >= _currentLeverage) {
                _request.targetLeverageType = PositionUtils.AjustmentType.INCREASE;
                _request.puppetSizeDelta = _position.mpSize * (_targetLeverage - _currentLeverage) / _currentLeverage;
                _requestKey = _submitOrder(
                    _params,
                    _allocationAddress,
                    _request,
                    GmxPositionUtils.OrderType.MarketIncrease,
                    0,
                    config.increaseCallbackGasLimit
                );
            } else {
                _request.targetLeverageType =
                    _params.isIncrease ? PositionUtils.AjustmentType.LIQUIDATE : PositionUtils.AjustmentType.DECREASE;
                _request.puppetSizeDelta = _position.mpSize * (_currentLeverage - _targetLeverage) / _currentLeverage;

                _requestKey = _submitOrder(
                    _params,
                    _allocationAddress,
                    _request,
                    GmxPositionUtils.OrderType.MarketDecrease,
                    0,
                    config.decreaseCallbackGasLimit
                );
            }
        }

        requestAdjustmentMap[_requestKey] = _request;

        _logEvent("Mirror", abi.encode(_allocationAddress, _requestKey, _request.traderSizeDelta));
    }

    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        Position memory _position = positionMap[_request.allocationKey];

        require(_request.allocationKey != bytes32(0), Error.MirrorPosition__ExecutionRequestMissing());

        if (_request.targetLeverageType == PositionUtils.AjustmentType.INCREASE) {
            _position.traderSize += _request.traderSizeDelta;
            _position.traderCollateral += _request.traderCollateralDelta;
            _position.mpSize += _request.puppetSizeDelta;
            _position.mpCollateral += _request.puppetCollateralDelta;
            positionMap[_request.allocationKey] = _position;
        } else {
            require(_position.mpSize > 0, Error.MirrorPosition__PositionDoesNotExist());

            // Partial decrease - calculate based on the adjusted portion
            if (_position.mpSize > _request.puppetSizeDelta) {
                if (_request.targetLeverageType == PositionUtils.AjustmentType.LIQUIDATE) {
                    _position.traderSize += _request.traderSizeDelta;
                    _position.traderCollateral += _request.traderCollateralDelta;
                } else {
                    _position.traderSize -= _request.traderSizeDelta;
                    _position.traderCollateral -= _request.traderCollateralDelta;
                }
                _position.mpSize -= _request.puppetSizeDelta;
                // _position.mpCollateral -= _request.puppetCollateralDelta;
                positionMap[_request.allocationKey] = _position;
            } else {
                delete positionMap[_request.allocationKey];
            }
        }

        delete requestAdjustmentMap[_requestKey];

        _logEvent(
            "Execute",
            abi.encode(
                _requestKey, _position.mpSize, _position.mpCollateral, _position.traderSize, _position.traderCollateral
            )
        );
    }

    function settle(
        IERC20 _token, //
        address _trader,
        address[] calldata _puppetList,
        uint allocationId
    ) external auth {
        uint _startGas = gasleft();

        bytes32 _matchKey = PositionUtils.getMatchKey(_token, _trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, allocationId);
        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );

        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _allocated = allocationMap[_allocationKey];
        uint _settled = _token.balanceOf(_allocationAddress);

        require(_allocated > 0, Error.MirrorPosition__InvalidAllocation());
        require(_settled > 0, Error.MirrorPosition__NoSettledFunds());

        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_token, _puppetList);

        uint _feeAmount;
        uint _allocationGasFee = (_startGas - gasleft()) * tx.gasprice;

        // Calculate platform fee
        if (feeMarket.askAmount(_token) > 0) {
            _feeAmount = Precision.applyFactor(config.platformFee, _settled);
            _settled -= _feeAmount;
            feeMarket.deposit(_token, allocationStore, _feeAmount);
        }

        // Distribute the remaining amount proportionally
        for (uint i = 0; i < _nextBalanceList.length; i++) {
            address puppet = _puppetList[i];
            uint puppetAllocation = allocationPuppetMap[_allocationKey][puppet];
            if (puppetAllocation == 0) continue;

            unchecked {
                _nextBalanceList[i] += _settled * puppetAllocation / _allocated;
            }

            // Clear allocation records
            delete allocationPuppetMap[_allocationKey][puppet];
        }

        // Cleanup allocation records
        if (positionMap[_allocationKey].mpSize == 0) {
            delete allocationMap[_allocationKey];
        }

        allocationStore.setBalanceList(_token, _puppetList, _nextBalanceList);

        _logEvent(
            "Settle",
            abi.encode(
                _matchKey,
                _allocationKey,
                _allocationAddress,
                _token,
                _puppetList,
                allocationId,
                _settled,
                _feeAmount,
                _allocationGasFee,
                _nextBalanceList
            )
        );
    }

    function _submitOrder(
        PositionParams calldata _order,
        address _allocationAddress,
        RequestAdjustment memory _request,
        GmxPositionUtils.OrderType _orderType,
        uint _collateralDelta,
        uint _callbackGasLimit
    ) internal returns (bytes32) {
        (bool _orderSuccess, bytes memory _orderReturnData) = AllocationAccount(_allocationAddress).execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(
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
                        sizeDeltaUsd: _request.traderSizeDelta,
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
            )
        );

        if (!_orderSuccess) {
            ErrorUtils.revertWithParsedMessage(_orderReturnData);
        }

        return abi.decode(_orderReturnData, (bytes32));
    }

    function _setConfig(
        bytes calldata _data
    ) internal override {
        config = abi.decode(_data, (Config));
    }
}
