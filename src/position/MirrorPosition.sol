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

/**
 * @title MirrorPosition
 * @notice This contract acts as the core engine for the Puppet copy trading platform's GMX integration.
 * @dev It enables "Puppets" (investors) to automatically mirror the positions initiated or adjusted
 * by chosen "Traders" on the GMX derivatives exchange. The contract manages the allocation
 * of funds from multiple Puppets for a single mirrored trade, interacts with the GMX protocol
 * to submit market orders (increase/decrease), and tracks the state of these mirrored positions.
 * It relies on matching rules (`MatchRule`) to determine Puppet participation and allocation amounts,
 * and integrates with the `FeeMarketplace` for platform fee handling during settlement.
 *
 * Interaction with GMX involves asynchronous order creation. Authorized external actors ("Keepers")
 * are responsible for monitoring the GMX order flow and providing necessary execution fees. Upon confirmation
 * of an order's execution on GMX, Keepers call the `execute` function on this contract to update
 * the mirrored position's state. Keepers also trigger the `settle` function to distribute funds
 * back to Puppets via the `AllocationStore` when the corresponding GMX position is closed or settled.
 * Settlement may occur in stages involving different tokens, requiring state persistence until final resolution.
 * Keeper compensation fees are deducted from Puppet funds during `mirror`, `adjust`, and `settle` operations.
 *
 * The contract utilizes deterministic clones (`AllocationAccount`) to hold funds and interact with GMX
 * for each specific mirrored trade instance (allocation).
 */
contract MirrorPosition is CoreContract {
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
    // allocation is the amount allocated during matching, it should be used as a denominator but not be used to measure
    // a position collateral because fees are deducted from the allocation
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
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        MatchRule.Rule[] memory _ruleList = matchRule.getRuleList(_matchKey, _puppetList);
        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _estimatedExecutionFeePerPuppet = _callParams.keeperExecutionFee / _puppetListLength;
        uint _allocated = 0;

        for (uint i = 0; i < _puppetListLength; i++) {
            MatchRule.Rule memory rule = _ruleList[i];
            address _puppet = _puppetList[i];

            if (rule.expiry > block.timestamp && block.timestamp >= activityThrottleMap[_callParams.trader][_puppet]) {
                uint _balanceAllocation = Precision.applyBasisPoints(rule.allowanceRate, _nextBalanceList[i]);

                if (
                    _balanceAllocation == 0
                        || (
                            _callParams.keeperExecutionFee > 0
                                && _estimatedExecutionFeePerPuppet
                                    > Precision.applyBasisPoints(config.minExecutionCostRate, _balanceAllocation)
                        )
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

        if (_callParams.keeperExecutionFee > 0) {
            require(
                Precision.applyBasisPoints(config.minExecutionCostRate, _allocated) > _callParams.keeperExecutionFee,
                Error.MirrorPosition__KeeperExecutionFeeExceedsFactorLimit()
            );
            require(
                _allocated >= _callParams.keeperExecutionFee, Error.MirrorPosition__InsufficientKeeperExecutionFee()
            );
        }

        uint _netAllocated = _allocated - _callParams.keeperExecutionFee;

        require(_netAllocated > 0, Error.MirrorPosition__NoFundsAllocated());

        uint _targetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
        uint _sizeDelta = (_callParams.sizeDeltaInUsd * _netAllocated) / _callParams.collateralDelta;

        allocationStore.transferOut(_callParams.collateralToken, address(this), _allocated);

        if (_callParams.keeperExecutionFee > 0) {
            SafeERC20.safeTransfer(
                _callParams.collateralToken, _callParams.keeperExecutionFeeReceiver, _callParams.keeperExecutionFee
            );
        }

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
                _callParams.keeperExecutionFeeReceiver,
                _allocated,
                _netAllocated,
                _callParams.keeperExecutionFee,
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
        require(_position.traderCollateral > 0, Error.MirrorPosition__PositionNotFound());

        address _allocationAddress = AllocationAccountUtils.predictDeterministicAddress(
            allocationStoreImplementation, _allocationKey, address(this)
        );
        require(CallUtils.isContract(_allocationAddress), Error.MirrorPosition__AllocationAccountNotFound());

        uint _keeperFee = _callParams.keeperExecutionFee;
        address _keeperFeeReceiver = _callParams.keeperExecutionFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExeuctionFeeReceiver());
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        uint _puppetListLength = _puppetList.length;
        require(_puppetListLength > 0, Error.MirrorPosition__PuppetListEmpty());

        uint _executionDebt;
        uint _puppetExecutionInsolvencyAmount;
        uint _allocated = allocationMap[_allocationKey];

        require(_allocated > _keeperFee, Error.MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount());

        uint[] memory _currentBalances = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _feeCollected = 0;

        for (uint i = 0; i < _puppetListLength; i++) {
            uint _puppetAllocationShare = allocationPuppetMap[_allocationKey][_puppetList[i]];
            if (_puppetAllocationShare == 0) continue;
            uint _puppetFeePortion = (_keeperFee * _puppetAllocationShare) / _allocated;

            if (_currentBalances[i] >= _puppetFeePortion) {
                _currentBalances[i] -= _puppetFeePortion;
                _feeCollected += _puppetFeePortion;
            } else if (_puppetAllocationShare > _puppetFeePortion) {
                allocationPuppetMap[_allocationKey][_puppetList[i]] = _puppetAllocationShare - _puppetFeePortion;
                _executionDebt += _puppetFeePortion;
                _puppetExecutionInsolvencyAmount += _puppetFeePortion;
            }
        }

        require(_feeCollected == _keeperFee, Error.MirrorPosition__KeeperFeeCollectionMismatch());

        allocationStore.setBalanceList(_callParams.collateralToken, _puppetList, _currentBalances);
        allocationStore.transferOut(_callParams.collateralToken, _keeperFeeReceiver, _keeperFee);

        uint _currentPuppetLeverage = Precision.toBasisPoints(_position.size, _allocated);
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

        uint _sizeDelta;

        require(_traderTargetLeverage != _currentPuppetLeverage, Error.MirrorPosition__NoAdjustmentRequired());
        require(_currentPuppetLeverage > 0, Error.MirrorPosition__NoAdjustmentRequired());

        if (_traderTargetLeverage > _currentPuppetLeverage) {
            _sizeDelta = (_position.size * (_traderTargetLeverage - _currentPuppetLeverage)) / _currentPuppetLeverage;
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
                : (_position.size * (_currentPuppetLeverage - _traderTargetLeverage)) / _currentPuppetLeverage;
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

    function execute(
        bytes32 _requestKey
    ) external auth {
        RequestAdjustment memory _request = requestAdjustmentMap[_requestKey];
        require(_request.allocationKey != bytes32(0), Error.MirrorPosition__ExecutionRequestMissing());

        // Fetch position state *before* modification/deletion
        Position memory _position = positionMap[_request.allocationKey];

        delete requestAdjustmentMap[_requestKey];

        if (_request.traderTargetLeverage > 0) {
            // Calculate current leverage before update
            uint _currentLeverage = (_position.traderCollateral > 0)
                ? Precision.toBasisPoints(_position.traderSize, _position.traderCollateral)
                : 0;

            // Apply trader's deltas first to reflect their intended state
            if (_request.traderIsIncrease) {
                _position.traderSize += _request.traderSizeDelta;
                _position.traderCollateral += _request.traderCollateralDelta;
            } else {
                _position.traderSize = (_position.traderSize > _request.traderSizeDelta)
                    ? _position.traderSize - _request.traderSizeDelta
                    : 0;
                _position.traderCollateral = (_position.traderCollateral > _request.traderCollateralDelta)
                    ? _position.traderCollateral - _request.traderCollateralDelta
                    : 0;
            }

            // Apply mirrored size delta based on whether leverage increased or decreased
            if (_request.traderTargetLeverage > _currentLeverage) {
                // Leverage increased
                _position.size += _request.sizeDelta;
            } else {
                // Leverage decreased or position closed (_request.sizeDelta would be calculated accordingly in adjust)
                _position.size = (_position.size > _request.sizeDelta) ? _position.size - _request.sizeDelta : 0;
            }

            // If size becomes 0, ensure collateral also reflects 0 (or handle dust)
            if (_position.size == 0) {
                _position.traderCollateral = 0;
                _position.traderSize = 0;
                delete positionMap[_request.allocationKey];
            } else {
                positionMap[_request.allocationKey] = _position;
            }

            _logEvent(
                "Execute",
                abi.encode(
                    _request.allocationKey,
                    _requestKey,
                    _position.traderSize, // Log state *after* applying deltas
                    _position.traderCollateral,
                    _position.size,
                    _request.traderTargetLeverage // Log the target leverage for this execution
                )
            );
        } else {
            delete positionMap[_request.allocationKey];

            _logEvent("Execute", abi.encode(_request.allocationKey, _requestKey, 0, 0, 0, 0));
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
        require(_allocated > 0, Error.MirrorPosition__InvalidAllocation()); // Original allocation must exist

        uint _keeperFee = _callParams.keeperExecutionFee;
        address _keeperFeeReceiver = _callParams.keeperExecutionFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExeuctionFeeReceiver());
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExeuctionFeeAmount());

        // --- Fund Retrieval ---
        uint _settledBalance = _callParams.distributeToken.balanceOf(_allocationAddress);
        // Allow settlement even if balance is 0 (e.g., liquidated position, nothing to recover)
        // require(_settledBalance > 0, Error.MirrorPosition__NoSettledFunds());

        // Transfer the *entire* settled balance from AllocationAccount to AllocationStore first
        if (_settledBalance > 0) {
            (bool success,) = AllocationAccount(_allocationAddress).execute(
                address(_callParams.distributeToken),
                abi.encodeWithSelector(
                    _callParams.distributeToken.transfer.selector, address(allocationStore), _settledBalance
                )
            );
            require(success, Error.MirrorPosition__SettlementTransferFailed());

            // Notify AllocationStore about the incoming funds
            allocationStore.recordTransferIn(_callParams.distributeToken);
        }

        uint _amountAvailableForDistribution = _settledBalance; // Start with the full settled amount

        require(_amountAvailableForDistribution >= _keeperFee, Error.MirrorPosition__InsufficientKeeperExecutionFee());

        // Deduct keeper fee
        _amountAvailableForDistribution -= _keeperFee;

        // Transfer fee to Keeper from AllocationStore
        allocationStore.transferOut(_callParams.distributeToken, _callParams.keeperExecutionFeeReceiver, _keeperFee);

        uint _platformFeeAmount = 0;
        if (
            config.platformSettleFeeFactor > 0 && _amountAvailableForDistribution > 0
                && feeMarket.askAmount(_callParams.distributeToken) > 0
        ) {
            // Calculate platform fee based on remaining amount *after* keeper fee
            _platformFeeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _amountAvailableForDistribution);

            if (_platformFeeAmount > 0) {
                // Ensure fee doesn't exceed available amount
                if (_platformFeeAmount > _amountAvailableForDistribution) {
                    _platformFeeAmount = _amountAvailableForDistribution;
                }

                _amountAvailableForDistribution -= _platformFeeAmount;
                // Deposit platform fee (from AllocationStore)
                feeMarket.deposit(_callParams.distributeToken, allocationStore, _platformFeeAmount);
            }
        }

        // Distribute the final remaining amount
        uint _finalAmountToDistribute = _amountAvailableForDistribution;

        if (_finalAmountToDistribute > 0) {
            uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.distributeToken, _puppetList);
            uint _distributedTotal = 0;

            for (uint i = 0; i < _puppetListLength; i++) {
                uint _puppetAllocationShare = allocationPuppetMap[_allocationKey][_puppetList[i]];
                if (_puppetAllocationShare == 0) continue;

                uint _puppetDistribution = (_finalAmountToDistribute * _puppetAllocationShare) / _allocated;
                _nextBalanceList[i] += _puppetDistribution;
                _distributedTotal += _puppetDistribution;
            }
            allocationStore.setBalanceList(_callParams.distributeToken, _puppetList, _nextBalanceList);
        }

        _logEvent(
            "Settle",
            abi.encode(
                _matchKey,
                _allocationKey,
                _allocationAddress,
                _keeperFeeReceiver,
                _finalAmountToDistribute,
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
        uint _sizeDeltaUsd, // Use clearer parameter names
        uint _initialCollateralDeltaAmount // Use clearer parameter names
    ) internal returns (bytes32 gmxRequestKey) {
        require(msg.value >= _order.executionFee, Error.MirrorPosition__InsufficientGmxExecutionFee());

        // Encode the call data for GMX Router's createOrder function
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

        // --- Process Result ---
        // Decode the GMX request key from the returned data
        gmxRequestKey = abi.decode(returnData, (bytes32));
        // Ensure GMX returned a valid request key
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
