// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {FeeMarketplace} from "../tokenomics/FeeMarketplace.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchRule} from "./../position/MatchRule.sol";
import {AllocationAccount} from "./../shared/AllocationAccount.sol";
import {AllocationStore} from "./../shared/AllocationStore.sol";
import {TokenRouter} from "./../shared/TokenRouter.sol";
import {CallUtils} from "./../utils/CallUtils.sol";
import {Error} from "./../utils/Error.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {AllocationAccountUtils} from "./utils/AllocationAccountUtils.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract MirrorPosition is CoreContract {
    event KeeperFeePaid( // Assuming this event exists or is added
    bytes32 indexed allocationKey, address indexed receiver, address indexed token, uint amount, string action);

    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        address callbackHandler;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        uint platformSettleFeeFactor;
        uint maxPuppetList;
        uint minExecutionCostRate;
    }

    struct Position {
        uint size;
        uint traderSize;
        uint traderCollateral;
    }

    struct CallPosition {
        IERC20 collateralToken;
        address trader;
        address market;
        address keeperExecutionFeeReceiver;
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
        uint keeperExecutionFee;
    }

    struct CallSettle {
        IERC20 allocationToken;
        IERC20 distributeToken;
        address keeperExecutionFeeReceiver;
        address trader;
        uint allocationId;
        uint keeperExecutionFee;
    }

    struct RequestAdjustment {
        bytes32 allocationKey;
        bool traderIsIncrease;
        uint traderTargetLeverage;
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
    ) CoreContract(_authority) {
        allocationStore = _puppetStore;
        matchRule = _matchRule;
        feeMarket = _feeMarket;
        allocationStoreImplementation = address(new AllocationAccount(allocationStore));
    }

    function initializeTraderActivityThrottle(address _trader, address _puppet) external auth {
        activityThrottleMap[_trader][_puppet] = 0;
    }

    /**
     * @notice Initiates the mirroring of a new trader position increase on GMX for a specified list of puppets.
     * @dev Called by an authorized Keeper (`auth`) to start the copy-trading process for a new position.
     * This function calculates how much capital each eligible puppet allocates based on matching rules (`MatchRule`),
     * available balances (`AllocationStore`), activity throttles, and minimum required allocation relative to the
     * provided keeper execution fee (`_callParams.keeperExecutionFee`). It updates the puppets' balances in the
     * `AllocationStore` via `setBalanceList`, deducts the keeper fee from the total allocated amount (`_allocated`)
     * to get the net allocation (`_netAllocated`), and then explicitly moves funds using the confirmed mechanism:
     * 1. The total gross allocated amount (`_allocated`) is transferred from `AllocationStore` *to* this
     * `MirrorPosition` contract
     * (using the confirmed `allocationStore.transferOut(..., address(this), _allocated)` method).
     * 2. The internal helper `_disburseFunds` is called, which uses `SafeERC20.safeTransfer` to send funds *from* this
     * contract:
     * - The `keeperExecutionFee` (if > 0) is sent to the `_callParams.keeperExecutionFeeReceiver`.
     * - The `_netAllocated` amount is sent to the GMX order vault (`config.gmxOrderVault`).
     * It then calculates the proportional size delta (`_sizeDelta`) for the mirrored position based on the
     * `_netAllocated` capital
     * and submits a `MarketIncrease` order to the GMX Router via `_submitOrder`. The `_submitOrder` function
     * forwards the `msg.value` (provided by the Keeper) to cover the GMX network execution fee
     * (`_callParams.executionFee`).
     * Finally, it stores the total gross allocation in `allocationMap` (for settlement calculations) and records
     * request details in `requestAdjustmentMap` (for processing by the `execute` function upon GMX callback).
     * Emits a `KeeperFeePaid` event (if applicable via `_disburseFunds`) and logs a `Mirror` event.
     * Requires `_callParams.isIncrease` to be true as this function only handles initial position opening.
     * @param _callParams Structure containing details of the trader's action (must be `isIncrease=true`),
     * market, collateral, size/collateral deltas, GMX execution fee, keeper fee, and keeper fee receiver.
     * @param _puppetList An array of puppet addresses to potentially participate in mirroring this position.
     * @return _nextAllocationId A unique ID for this allocation instance, incremented for each call.
     * @return _requestKey The unique key returned by GMX identifying the created order request, used for callbacks.
     */
    function mirror(
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (uint _nextAllocationId, bytes32 _requestKey) {
        require(_callParams.isIncrease, Error.MirrorPosition__InitialMustBeIncrease());
        require(_callParams.collateralDelta > 0, Error.MirrorPosition__InvalidCollateralDelta());
        require(_callParams.sizeDeltaInUsd > 0, Error.MirrorPosition__InvalidSizeDelta());

        _nextAllocationId = ++nextAllocationId;

        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _nextAllocationId);
        address _allocationAddress =
            AllocationAccountUtils.cloneDeterministic(allocationStoreImplementation, _allocationKey);
        uint _puppetListLength = _puppetList.length;

        require(_puppetListLength > 0, Error.MirrorPosition__PuppetListEmpty());
        require(_puppetListLength <= config.maxPuppetList, Error.MirrorPosition__MaxPuppetList());

        uint _keeperFee = _callParams.keeperExecutionFee;
        address _keeperFeeReceiver = _callParams.keeperExecutionFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExeuctionFeeReceiver());
        // Keep check if mirror always requires a fee, otherwise remove
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _estimatedExecutionFeePerPuppet = 0;
        if (_puppetListLength > 0) {
            _estimatedExecutionFeePerPuppet = _keeperFee / _puppetListLength;
        }
        uint _allocated = 0;

        for (uint i = 0; i < _puppetListLength; i++) {
            MatchRule.Rule memory rule = _ruleList[i];
            address _puppet = _puppetList[i];

            if (rule.expiry > block.timestamp && block.timestamp >= activityThrottleMap[_callParams.trader][_puppet]) {
                uint _balanceAllocation = Precision.applyBasisPoints(rule.allowanceRate, _nextBalanceList[i]);

                if (
                    _balanceAllocation == 0
                        || _estimatedExecutionFeePerPuppet
                            > Precision.applyBasisPoints(config.minExecutionCostRate, _balanceAllocation)
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

        require(
            Precision.applyBasisPoints(config.minExecutionCostRate, _allocated) > _keeperFee,
            Error.MirrorPosition__KeeperExecutionFeeExceedsFactorLimit()
        );
        require(_allocated >= _keeperFee, Error.MirrorPosition__InsufficientKeeperExecutionFee());

        uint _netAllocated = _allocated - _keeperFee;
        require(_netAllocated > 0, Error.MirrorPosition__NoNetFundsAllocated());

        uint _targetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
        uint _sizeDelta = (_callParams.sizeDeltaInUsd * _netAllocated) / _callParams.collateralDelta;

        allocationStore.transferOut(_callParams.collateralToken, address(this), _allocated);
        SafeERC20.safeTransfer(_callParams.collateralToken, _keeperFeeReceiver, _keeperFee);
        SafeERC20.safeTransfer(_callParams.collateralToken, config.gmxOrderVault, _netAllocated);

        _requestKey = _submitOrder(
            _callParams,
            _allocationAddress,
            GmxPositionUtils.OrderType.MarketIncrease,
            config.increaseCallbackGasLimit,
            _sizeDelta,
            _netAllocated
        );

        allocationMap[_allocationKey] = _allocated;
        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationKey: _allocationKey,
            traderIsIncrease: true,
            traderTargetLeverage: _targetLeverage,
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "Mirror",
            abi.encode(
                _matchKey,
                _allocationKey,
                _allocationAddress,
                _keeperFeeReceiver,
                _allocated,
                _netAllocated,
                _keeperFee,
                _sizeDelta,
                _targetLeverage,
                _requestKey
            )
        );
    }

    function adjust(
        CallPosition calldata _callParams,
        address[] calldata _puppetList,
        uint _allocationId
    ) external payable auth returns (bytes32 _requestKey) {
        require(
            _callParams.collateralDelta > 0 || _callParams.sizeDeltaInUsd > 0,
            Error.MirrorPosition__NoAdjustmentRequired()
        );

        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _allocationId);

        Position memory _position = positionMap[_allocationKey];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound());
        require(_position.traderCollateral > 0, Error.MirrorPosition__TraderCollateralZero());

        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );
        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _keeperFee = _callParams.keeperExecutionFee;
        address _keeperFeeReceiver = _callParams.keeperExecutionFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExeuctionFeeReceiver());
        // Allow _keeperFee = 0? If so remove check below. Assuming > 0 required for adjust for now.
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        uint _puppetListLength = _puppetList.length;
        require(_puppetListLength > 0, Error.MirrorPosition__PuppetListEmpty());

        uint _originalTotalAllocation = allocationMap[_allocationKey];
        require(_originalTotalAllocation > 0, Error.MirrorPosition__InvalidAllocation());

        uint _feeCollectedFromBalance = 0;
        uint _totalMapReduction = 0;
        uint[] memory _currentBalances = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);
        // Create copy for modification
        uint[] memory _nextBalances = new uint[](_puppetListLength);
        for (uint i = 0; i < _puppetListLength; i++) {
            _nextBalances[i] = _currentBalances[i];
        }

        require( // Check fee doesn't exceed total allocation *before* detailed checks
            _originalTotalAllocation > _keeperFee,
            Error.MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount()
        );

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            uint _puppetOriginalShare = allocationPuppetMap[_allocationKey][_puppet];
            if (_puppetOriginalShare == 0) continue;

            uint _puppetFeePortion = (_keeperFee * _puppetOriginalShare) / _originalTotalAllocation; // Use original
                // total for portion calc

            if (_currentBalances[i] >= _puppetFeePortion) {
                _nextBalances[i] -= _puppetFeePortion;
                _feeCollectedFromBalance += _puppetFeePortion;
            } else {
                uint _deductionFromShare;
                if (_puppetOriginalShare >= _puppetFeePortion) {
                    _deductionFromShare = _puppetFeePortion;
                    allocationPuppetMap[_allocationKey][_puppet] = _puppetOriginalShare - _deductionFromShare;
                } else {
                    _deductionFromShare = _puppetOriginalShare;
                    allocationPuppetMap[_allocationKey][_puppet] = 0;
                }
                _totalMapReduction += _deductionFromShare;
            }
        }

        allocationStore.setBalanceList(_callParams.collateralToken, _puppetList, _nextBalances);
        allocationStore.transferOut(_callParams.collateralToken, _keeperFeeReceiver, _keeperFee);

        uint _newTotalAllocation = _originalTotalAllocation - _totalMapReduction;
        require(_newTotalAllocation > 0, Error.MirrorPosition__AllocationZeroAfterKeeperExecutionFeeReduction());

        allocationMap[_allocationKey] = _newTotalAllocation;

        uint _currentPuppetLeverage = Precision.toBasisPoints(_position.size, _newTotalAllocation);

        uint _traderTargetLeverage;
        if (_callParams.isIncrease) {
            require(
                _position.traderCollateral + _callParams.collateralDelta > 0,
                Error.MirrorPosition__ZeroCollateralOnIncrease()
            );
            _traderTargetLeverage = Precision.toBasisPoints(
                _position.traderSize + _callParams.sizeDeltaInUsd,
                _position.traderCollateral + _callParams.collateralDelta
            );
        } else {
            if (
                _position.traderSize > _callParams.sizeDeltaInUsd
                    && _position.traderCollateral > _callParams.collateralDelta
            ) {
                uint _nextTraderCollateral = _position.traderCollateral - _callParams.collateralDelta;
                // Denominator _nextTraderCollateral > 0 is guaranteed by the && condition
                _traderTargetLeverage =
                    Precision.toBasisPoints(_position.traderSize - _callParams.sizeDeltaInUsd, _nextTraderCollateral);
            } else {
                _traderTargetLeverage = 0;
            }
        }

        require(_traderTargetLeverage != _currentPuppetLeverage, Error.MirrorPosition__NoAdjustmentRequired());
        require(_currentPuppetLeverage > 0, Error.MirrorPosition__InvalidCurrentLeverage());

        uint _sizeDelta;
        if (_traderTargetLeverage > _currentPuppetLeverage) {
            _sizeDelta = _position.size * (_traderTargetLeverage - _currentPuppetLeverage) / _currentPuppetLeverage;

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
                : _position.size * (_currentPuppetLeverage - _traderTargetLeverage) / _currentPuppetLeverage;
            _requestKey = _submitOrder(
                _callParams,
                _allocationAddress,
                GmxPositionUtils.OrderType.MarketDecrease,
                config.decreaseCallbackGasLimit,
                _sizeDelta,
                0
            );
        }

        requestAdjustmentMap[_requestKey] = RequestAdjustment({
            allocationKey: _allocationKey,
            traderIsIncrease: _callParams.isIncrease,
            traderTargetLeverage: _traderTargetLeverage,
            traderSizeDelta: _callParams.sizeDeltaInUsd,
            traderCollateralDelta: _callParams.collateralDelta,
            sizeDelta: _sizeDelta
        });

        _logEvent(
            "Adjust",
            abi.encode(
                _matchKey,
                _allocationKey,
                _requestKey,
                _allocationAddress,
                _keeperFeeReceiver,
                _sizeDelta,
                _traderTargetLeverage,
                _keeperFee
            )
        );
    }

    // Corrected execute function
    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        require(_request.allocationKey != bytes32(0), Error.MirrorPosition__ExecutionRequestMissing());

        Position memory _position = positionMap[_request.allocationKey]; // Fetch state BEFORE changes

        delete requestAdjustmentMap[_requestKey];

        if (_request.traderTargetLeverage == 0) {
            delete positionMap[_request.allocationKey];
            _logEvent("Execute", abi.encode(_request.allocationKey, _requestKey, 0, 0, 0, 0));
            return;
        }

        require(_position.traderCollateral > 0, Error.MirrorPosition__ExecuteOnZeroCollateralPosition());
        uint _originalLeverage = Precision.toBasisPoints(_position.traderSize, _position.traderCollateral);

        if (_request.traderIsIncrease) {
            _position.traderSize += _request.traderSizeDelta;
            _position.traderCollateral += _request.traderCollateralDelta;
        } else {
            _position.traderSize = _position.traderSize - _request.traderSizeDelta;
            _position.traderCollateral = _position.traderCollateral - _request.traderCollateralDelta;
        }

        if (_request.traderTargetLeverage > _originalLeverage) {
            _position.size += _request.sizeDelta;
        } else if (_request.traderTargetLeverage < _originalLeverage) {
            _position.size = _position.size - _request.sizeDelta;
        }

        if (_position.size == 0) {
            delete positionMap[_request.allocationKey];
            _logEvent(
                "Execute",
                abi.encode(
                    _request.allocationKey,
                    _requestKey,
                    _position.traderSize,
                    _position.traderCollateral,
                    0,
                    _request.traderTargetLeverage
                )
            );
        } else {
            positionMap[_request.allocationKey] = _position;
            _logEvent(
                "Execute",
                abi.encode(
                    _request.allocationKey,
                    _requestKey,
                    _position.traderSize,
                    _position.traderCollateral,
                    _position.size,
                    _request.traderTargetLeverage
                )
            );
        }
    }
    /**
     * @notice Settles and distributes funds received for a specific allocation instance.
     * @dev This function is called by a Keeper when funds related to a closed or partially closed
     * GMX position (identified by the allocation instance) are available in the AllocationAccount.
     * It retrieves the specified `distributeToken` balance from the account, transfers it to the
     * central `AllocationStore`, deducts a Keeper fee (paid to msg.sender) and a platform fee
     * (sent to FeeMarketplace), and distributes the remaining amount to the participating Puppets'
     * balances within the `AllocationStore` based on their original contribution ratios (`allocationPuppetMap`).
     *
     * IMPORTANT: Settlement on GMX might occur in stages or involve multiple token types (e.g.,
     * collateral returned separately from PnL or fees). This function processes only the currently
     * available balance of the specified `distributeToken`. Multiple calls to `settle` (potentially
     * with different `distributeToken` parameters) may be required for the same `allocationKey`
     * to fully distribute all proceeds.
     *
     * Consequently, this function SHOULD NOT perform cleanup of the allocation state (`allocationMap`,
     * `allocationPuppetMap`). This state must persist to correctly attribute any future funds
     * arriving for this allocation instance. A separate mechanism or function call, triggered
     * once a Keeper confirms no further funds are expected, should be used for final cleanup.
     * @param _callParams Structure containing settlement details (tokens, trader, allocationId, keeperFee).
     * @param _puppetList The list of puppet addresses involved in this specific allocation instance.
     */
    function settle(CallSettle calldata _callParams, address[] calldata _puppetList) external auth {
        bytes32 _matchKey = PositionUtils.getMatchKey(_callParams.allocationToken, _callParams.trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _matchKey, _callParams.allocationId);
        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );

        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _puppetListLength = _puppetList.length;
        require(_puppetListLength > 0, Error.MirrorPosition__PuppetListEmpty());

        uint _allocated = allocationMap[_allocationKey];
        require(_allocated > 0, Error.MirrorPosition__InvalidAllocationOrFullyReduced());

        uint _keeperFee = _callParams.keeperExecutionFee;
        address _keeperFeeReceiver = _callParams.keeperExecutionFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExeuctionFeeReceiver());
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        uint _settledBalance = _callParams.distributeToken.balanceOf(_allocationAddress);

        if (_settledBalance > 0) {
            (bool success,) = AllocationAccount(_allocationAddress).execute(
                address(_callParams.distributeToken),
                abi.encodeWithSelector(IERC20.transfer.selector, address(allocationStore), _settledBalance)
            );
            require(success, Error.MirrorPosition__SettlementTransferFailed());

            allocationStore.recordTransferIn(_callParams.distributeToken);
        }

        uint _amountToDistribute = _settledBalance;

        require(_amountToDistribute >= _keeperFee, Error.MirrorPosition__InsufficientSettledBalanceForKeeperFee());

        _amountToDistribute -= _keeperFee;

        allocationStore.transferOut(_callParams.distributeToken, _keeperFeeReceiver, _keeperFee);

        uint _platformFeeAmount = 0;
        if (
            config.platformSettleFeeFactor > 0 && _amountToDistribute > 0
                && feeMarket.askAmount(_callParams.distributeToken) > 0
        ) {
            _platformFeeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _amountToDistribute);

            if (_platformFeeAmount > 0) {
                if (_platformFeeAmount > _amountToDistribute) {
                    _platformFeeAmount = _amountToDistribute;
                }
                _amountToDistribute -= _platformFeeAmount;
                feeMarket.deposit(_callParams.distributeToken, allocationStore, _platformFeeAmount);
            }
        }

        if (_amountToDistribute > 0) {
            uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.distributeToken, _puppetList);
            uint _distributedTotal = 0; // For potential dust check later if needed

            for (uint i = 0; i < _puppetListLength; i++) {
                // Reads potentially reduced/zeroed share
                uint _puppetAllocationShare = allocationPuppetMap[_allocationKey][_puppetList[i]];
                if (_puppetAllocationShare == 0) continue;

                uint _puppetDistribution = (_amountToDistribute * _puppetAllocationShare) / _allocated;

                _nextBalanceList[i] += _puppetDistribution;
                _distributedTotal += _puppetDistribution;
            }
            allocationStore.setBalanceList(_callParams.distributeToken, _puppetList, _nextBalanceList);
            // Potential dust (_finalAmountToDistribute - _distributedTotal) remains in AllocationStore pool
        }

        _logEvent(
            "Settle",
            abi.encode(
                _matchKey,
                _allocationKey,
                _allocationAddress,
                _keeperFeeReceiver,
                _settledBalance,
                _amountToDistribute,
                _platformFeeAmount,
                _keeperFee
            )
        );
    }

    function _submitOrder(
        CallPosition calldata _order,
        address _allocationAddress,
        GmxPositionUtils.OrderType _orderType,
        uint _callbackGasLimit,
        uint _sizeDeltaUsd,
        uint _initialCollateralDeltaAmount
    ) internal returns (bytes32 gmxRequestKey) {
        require(msg.value >= _order.executionFee, Error.MirrorPosition__InsufficientGmxExecutionFee());

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

        (bool success, bytes memory returnData) = AllocationAccount(_allocationAddress).execute{
            value: _order.executionFee
        }(address(config.gmxExchangeRouter), gmxCallData);

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
        require(config.gmxExchangeRouter != IGmxExchangeRouter(address(0)), "Invalid GMX Router address");
        require(config.callbackHandler != address(0), "Invalid Callback Handler address");
        require(config.gmxOrderVault != address(0), "Invalid GMX Order Vault address");
        require(config.referralCode != bytes32(0), "Invalid Referral Code");
        require(config.maxPuppetList > 0, "Invalid Max Puppet List");
        require(config.increaseCallbackGasLimit > 0, "Invalid Increase Callback Gas Limit");
        require(config.decreaseCallbackGasLimit > 0, "Invalid Decrease Callback Gas Limit");
        require(config.platformSettleFeeFactor > 0, "Invalid Platform Settle Fee Factor");
        require(config.minExecutionCostRate > 0, "Invalid Min Execution Cost Rate");
    }
}
