// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {FeeMarketplace} from "../tokenomics/FeeMarketplace.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchRule} from "./../position/MatchRule.sol";
import {Error} from "./../shared/Error.sol";
import {Subaccount} from "./../shared/Subaccount.sol";
import {SubaccountStore} from "./../shared/SubaccountStore.sol";
import {TokenRouter} from "./../shared/TokenRouter.sol";
import {CallUtils} from "./../utils/CallUtils.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
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
        uint performanceFee;
        uint traderPerformanceFee;
    }

    struct Allocation {
        bytes32 matchKey;
        bytes32 listHash;
        IERC20 collateralToken;
        uint allocated;
        uint settled;
        uint allocationGasFee;
        uint executionGasFee;
    }

    struct Position {
        // uint collateral;
        uint size;
    }

    struct MirrorPositionParams {
        IERC20 collateralToken;
        bytes32 sourceRequestKey;
        bytes32 allocationKey;
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
        bytes32 sourceRequestKey;
        bytes32 matchKey;
        uint sizeDelta;
    }

    Config public config;

    SubaccountStore immutable subaccountStore;
    MatchRule immutable matchRule;
    FeeMarketplace immutable feeMarket;
    address immutable subaccountStoreImplementation;

    mapping(address trader => mapping(address puppet => uint)) public activityThrottleMap;
    mapping(bytes32 allocationKey => Allocation) public allocationMap;
    mapping(bytes32 allocationKey => mapping(address puppet => uint)) public allocationPuppetMap;
    mapping(bytes32 positionKey => Position) public positionMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    constructor(
        IAuthority _authority,
        SubaccountStore _puppetStore,
        MatchRule _matchRule,
        FeeMarketplace _feeMarket
    ) CoreContract("MirrorPosition", _authority) {
        subaccountStore = _puppetStore;
        subaccountStoreImplementation = subaccountStore.implementation();
        matchRule = _matchRule;
        feeMarket = _feeMarket;
    }

    function allocate(
        IERC20 _collateralToken,
        bytes32 _sourceRequestKey,
        bytes32 _matchKey,
        bytes32 _positionKey,
        address _trader,
        address[] calldata _puppetList
    ) external auth returns (bytes32) {
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_matchKey, _positionKey);
        uint _startGas = gasleft();
        Allocation memory _allocation = allocationMap[_allocationKey];

        require(_allocation.allocated == 0, Error.MirrorPosition__PendingAllocation());
        require(_puppetList.length <= config.limitAllocationListLength, Error.MirrorPosition__PuppetListLimit());

        if (_allocation.matchKey == 0) {
            _allocation.matchKey = _matchKey;
            _allocation.collateralToken = _collateralToken;
        }

        _allocation.listHash = keccak256(abi.encode(_puppetList));

        (uint[] memory _balanceList, uint _allocated) =
            _processPuppetList(_collateralToken, _matchKey, _allocationKey, _trader, _puppetList);

        require(_allocated > 0, Error.MirrorPosition__NoPuppetAllocation());

        _allocation.allocated = _allocated;
        _allocation.allocationGasFee += (_startGas - gasleft()) * tx.gasprice;

        allocationMap[_allocationKey] = _allocation;

        _logEvent(
            "Allocate",
            abi.encode(
                _collateralToken,
                _allocationKey,
                _matchKey,
                _sourceRequestKey,
                _allocation.listHash,
                _puppetList,
                _balanceList,
                _allocation.allocationGasFee,
                _allocated
            )
        );

        return _allocationKey;
    }

    function _processPuppetList(
        IERC20 _collateralToken,
        bytes32 _matchKey,
        bytes32 _allocationKey,
        address _trader,
        address[] calldata _puppetList
    ) internal returns (uint[] memory _balanceList, uint _allocated) {
        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        _balanceList = subaccountStore.getBalanceList(_collateralToken, _puppetList);

        for (uint i = 0; i < _puppetList.length; i++) {
            MatchRule.Rule memory rule = _ruleList[i];

            // Only process if within time window
            if (rule.expiry > block.timestamp && block.timestamp > activityThrottleMap[_trader][_puppetList[i]]) {
                uint _allocation = Precision.applyBasisPoints(rule.allowanceRate, _balanceList[i]);

                allocationPuppetMap[_allocationKey][_puppetList[i]] = _allocation;
                _balanceList[i] -= _allocation;
                _allocated += _allocation;
            }

            activityThrottleMap[_trader][_puppetList[i]] = block.timestamp + rule.throttleActivity;
        }

        subaccountStore.setBalanceList(_collateralToken, _puppetList, _balanceList);
    }

    function mirror(
        MirrorPositionParams calldata _params
    ) external payable auth returns (bytes32 _requestKey) {
        uint _startGas = gasleft();
        Allocation memory _allocation = allocationMap[_params.allocationKey];
        Position memory _position = positionMap[_params.allocationKey];

        address _subaccountAddress = _predictDeterministicAddress(_allocation.matchKey);

        Subaccount _subaccount = Subaccount(
            CallUtils.isContract(_subaccountAddress)
                ? _subaccountAddress
                : Clones.cloneDeterministic(subaccountStoreImplementation, _allocation.matchKey)
        );

        RequestAdjustment memory _request = RequestAdjustment({
            matchKey: _allocation.matchKey,
            allocationKey: _params.allocationKey,
            sourceRequestKey: _params.sourceRequestKey,
            sizeDelta: 0
        });

        uint _leverage;
        uint _targetLeverage;

        if (_position.size == 0) {
            require(_allocation.allocated > 0, Error.MirrorPosition__NoAllocation());
            require(_allocation.executionGasFee == 0, Error.MirrorPosition__PendingAllocationExecution());

            subaccountStore.transferOut(_params.collateralToken, config.gmxOrderVault, _allocation.allocated);
            _requestKey = _submitOrder(
                _params,
                _subaccount,
                _request,
                GmxPositionUtils.OrderType.MarketIncrease,
                _allocation.allocated,
                config.increaseCallbackGasLimit
            );

            _request.sizeDelta = _params.sizeDeltaInUsd;
        } else {
            _leverage = Precision.toBasisPoints(_position.size, _allocation.allocated);
            _targetLeverage = _params.isIncrease
                ? Precision.toBasisPoints(
                    _position.size + _params.sizeDeltaInUsd, _allocation.allocated + _params.collateralDelta
                )
                : _params.sizeDeltaInUsd < _position.size
                    ? Precision.toBasisPoints(
                        _position.size - _params.sizeDeltaInUsd, _allocation.allocated - _params.collateralDelta
                    )
                    : 0;

            uint deltaLeverage;

            if (_targetLeverage >= _leverage) {
                deltaLeverage = _targetLeverage - _leverage;
                _request.sizeDelta = _position.size * deltaLeverage / _targetLeverage;

                _requestKey = _submitOrder(
                    _params,
                    _subaccount,
                    _request,
                    GmxPositionUtils.OrderType.MarketIncrease,
                    0,
                    config.increaseCallbackGasLimit
                );
            } else {
                deltaLeverage = _leverage - _targetLeverage;
                _request.sizeDelta = _position.size * deltaLeverage / _leverage;

                _requestKey = _submitOrder(
                    _params,
                    _subaccount,
                    _request,
                    GmxPositionUtils.OrderType.MarketDecrease,
                    0,
                    config.decreaseCallbackGasLimit
                );
            }
        }

        _allocation.executionGasFee += (_startGas - gasleft()) * tx.gasprice + _params.executionFee;
        requestAdjustmentMap[_requestKey] = _request;
        allocationMap[_params.allocationKey] = _allocation;

        _logEvent(
            _targetLeverage >= _leverage ? "RequestIncrease" : "RequestDecrease",
            abi.encode(
                _subaccountAddress,
                _params.trader,
                _params.allocationKey,
                _params.sourceRequestKey,
                _requestKey,
                _request.matchKey,
                _allocation.executionGasFee,
                _request.sizeDelta
            )
        );
    }

    function requestIncrease(
        MirrorPositionParams calldata _params
    ) external payable auth returns (bytes32 _requestKey) {}

    function increase(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        Position memory _position = positionMap[_request.allocationKey];

        require(_request.matchKey != 0, Error.MirrorPosition__ExecutionRequestMissing());

        _position.size += _request.sizeDelta;

        positionMap[_request.allocationKey] = _position;
        delete requestAdjustmentMap[_requestKey];

        _logEvent(
            "ExecuteIncrease",
            abi.encode(
                _requestKey, _request.sourceRequestKey, _request.allocationKey, _request.matchKey, _position.size
            )
        );
    }

    function decrease(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];

        require(_request.matchKey != 0, Error.MirrorPosition__ExecutionRequestMissing());

        Position memory _position = positionMap[_request.allocationKey];
        Allocation memory _allocation = allocationMap[_request.allocationKey];

        require(_position.size > 0, Error.MirrorPosition__PositionDoesNotExist());

        uint _recordedAmountIn = subaccountStore.recordTransferIn(_allocation.collateralToken);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        // Partial decrease - calculate based on the adjusted portion
        if (_position.size > _request.sizeDelta) {
            _position.size -= _request.sizeDelta;
            _allocation.settled += _recordedAmountIn;
        } else {
            _allocation.settled = _recordedAmountIn;
            delete positionMap[_request.allocationKey];
        }

        delete requestAdjustmentMap[_requestKey];
        allocationMap[_request.allocationKey] = _allocation;

        _logEvent(
            "ExecuteDecrease",
            abi.encode(
                _requestKey,
                _request.sourceRequestKey,
                _request.allocationKey,
                _request.matchKey,
                _request.sizeDelta,
                _recordedAmountIn,
                _allocation.allocated,
                _position.size,
                _allocation.settled
            )
        );
    }

    function settle(bytes32 _allocationKey, address[] calldata _puppetList) external auth {
        uint _startGas = gasleft();

        Allocation memory _allocation = allocationMap[_allocationKey];

        require(_allocation.settled > 0, Error.MirrorPosition__AllocationDoesNotExist());

        bytes32 _puppetListHash = keccak256(abi.encode(_puppetList));

        require(_allocation.listHash == _puppetListHash, Error.MirrorPosition__InvalidPuppetListIntegrity());

        uint[] memory _nextBalanceList = subaccountStore.getBalanceList(_allocation.collateralToken, _puppetList);

        uint _feeAmount;
        uint _traderFee;
        uint _allocationGasFee = (_startGas - gasleft()) * tx.gasprice;
        int _pnl = int(_allocation.settled) - int(_allocation.allocated);
        uint _distributionAmount = _allocation.settled;

        if (_pnl > 0) {
            uint _profit = uint(_pnl);

            // Calculate platform fee
            if (feeMarket.askAmount(_allocation.collateralToken) > 0) {
                _feeAmount = Precision.applyFactor(config.performanceFee, _profit);
                _distributionAmount -= _feeAmount;
                feeMarket.deposit(_allocation.collateralToken, subaccountStore, _feeAmount);
            }

            // Calculate trader fee
            if (config.traderPerformanceFee > 0) {
                _traderFee = Precision.applyFactor(config.traderPerformanceFee, _profit);
                _distributionAmount -= _traderFee;
                // Transfer trader fee (implementation depends on your architecture)
                // Example: subaccountStore.transfer(_allocation.collateralToken, _trader, _traderFee);
            }
        }

        // Distribute the remaining amount proportionally
        for (uint i = 0; i < _nextBalanceList.length; i++) {
            uint puppetAllocation = allocationPuppetMap[_allocationKey][_puppetList[i]];
            if (puppetAllocation == 0) continue;

            _nextBalanceList[i] += _distributionAmount * puppetAllocation / _allocation.allocated;

            // Clear allocation records
            delete allocationPuppetMap[_allocationKey][_puppetList[i]];
        }

        // Update allocation state
        if (_allocation.allocated > 0) {
            _allocation.allocationGasFee += _allocationGasFee;
            _allocation.settled = 0;
            allocationMap[_allocationKey] = _allocation;
        } else {
            delete allocationMap[_allocationKey];
        }

        subaccountStore.setBalanceList(_allocation.collateralToken, _puppetList, _nextBalanceList);

        _logEvent(
            "Settle",
            abi.encode(
                _allocation.collateralToken,
                _allocation.matchKey,
                _allocationKey,
                _puppetListHash,
                _nextBalanceList,
                _puppetList,
                _feeAmount + _traderFee,
                _pnl,
                _allocationGasFee,
                _distributionAmount
            )
        );
    }

    function _submitOrder(
        MirrorPositionParams calldata _order,
        Subaccount _subaccount,
        RequestAdjustment memory _request,
        GmxPositionUtils.OrderType _orderType,
        uint _collateralDelta,
        uint _callbackGasLimit
    ) internal returns (bytes32) {
        (bool _orderSuccess, bytes memory _orderReturnData) = _subaccount.execute(
            address(config.gmxExchangeRouter),
            abi.encodeWithSelector(
                config.gmxExchangeRouter.createOrder.selector,
                GmxPositionUtils.CreateOrderParams({
                    addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                        receiver: address(this),
                        callbackContract: config.callbackHandler,
                        uiFeeReceiver: address(0),
                        market: _order.market,
                        initialCollateralToken: _order.collateralToken,
                        swapPath: new address[](0)
                    }),
                    numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                        sizeDeltaUsd: _request.sizeDelta,
                        initialCollateralDeltaAmount: _collateralDelta,
                        triggerPrice: _order.triggerPrice,
                        acceptablePrice: _order.acceptablePrice,
                        executionFee: _order.executionFee,
                        callbackGasLimit: _callbackGasLimit,
                        minOutputAmount: 0
                    }),
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

    function _predictDeterministicAddress(
        bytes32 _salt
    ) internal view returns (address) {
        return Clones.predictDeterministicAddress(subaccountStoreImplementation, _salt, address(this));
    }

    function _setConfig(
        bytes calldata _data
    ) internal override {
        config = abi.decode(_data, (Config));
    }
}
