// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AllocationStore} from "../shared/AllocationStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {AllocationAccount} from "./../shared/AllocationAccount.sol";
import {Error} from "./../utils/Error.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {Precision} from "./../utils/Precision.sol";
import {Rule} from "./Rule.sol";
import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "./interface/IGmxReadDataStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract MirrorPosition is CoreContract, ReentrancyGuardTransient {
    struct Config {
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxReadDataStore gmxDataStore;
        address gmxOrderVault;
        bytes32 referralCode;
        uint increaseCallbackGasLimit;
        uint decreaseCallbackGasLimit;
        address fallbackRefundExecutionFeeReceiver;
        uint transferOutGasLimit;
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
        bool isIncrease;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDeltaInUsd;
        uint acceptablePrice;
        uint triggerPrice;
        uint allocationId;
        uint keeperFee;
        address keeperFeeReceiver;
    }

    Config public config;
    AllocationStore public immutable allocationStore;
    address public immutable allocationAccountImplementation;

    // Position tracking
    mapping(address allocationAddress => Position) public positionMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;

    // Allocation tracking
    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;

    constructor(
        IAuthority _authority,
        AllocationStore _allocationStore,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        allocationStore = _allocationStore;
        allocationAccountImplementation = address(new AllocationAccount(_allocationStore));
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getPosition(
        address _allocationAddress
    ) external view returns (Position memory) {
        return positionMap[_allocationAddress];
    }

    function getAllocation(
        address _allocationAddress
    ) external view returns (uint) {
        return allocationMap[_allocationAddress];
    }

    function getPuppetAllocationList(
        address _allocationAddress
    ) external view returns (uint[] memory) {
        return allocationPuppetList[_allocationAddress];
    }

    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
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
     * @param _ruleContract The rule contract used to determine allocation amounts for each puppet.
     * @param _callParams The parameters for the position to be mirrored, including market, collateral token,
     * @param _puppetList The list of puppet addresses to allocate funds to
     */
    function requestOpen(
        Rule _ruleContract,
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth nonReentrant returns (address _allocationAddress, bytes32 _requestKey) {
        require(_callParams.isIncrease, Error.MirrorPosition__InitialMustBeIncrease());
        require(_callParams.collateralDelta > 0, Error.MirrorPosition__InvalidCollateralDelta());
        require(_callParams.sizeDeltaInUsd > 0, Error.MirrorPosition__InvalidSizeDelta());

        // Create allocation inline
        uint _puppetCount = _puppetList.length;
        require(_puppetCount > 0, Error.Allocation__PuppetListEmpty());
        require(_puppetCount <= config.maxPuppetList, "Puppet list too large");

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId);

        _allocationAddress = Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);

        // Get rules and balances
        Rule.RuleParams[] memory _rules = _ruleContract.getRuleList(_traderMatchingKey, _puppetList);
        uint[] memory _balanceList = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);

        uint _feePerPuppet = _callParams.keeperFee / _puppetCount;
        uint[] memory _allocatedList = new uint[](_puppetCount);
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

        allocationStore.setBalanceList(_callParams.collateralToken, _puppetList, _balanceList);

        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _allocated),
            Error.Allocation__KeeperFeeExceedsCostFactor(_callParams.keeperFee, _allocated)
        );

        _allocated -= _callParams.keeperFee;
        allocationMap[_allocationAddress] = _allocated;

        allocationStore.transferOut(
            config.transferOutGasLimit,
            _callParams.collateralToken,
            _callParams.keeperFeeReceiver,
            _callParams.keeperFee
        );
        allocationStore.transferOut(
            config.transferOutGasLimit, _callParams.collateralToken, config.gmxOrderVault, _allocated
        );

        // Mirror position
        uint _traderTargetLeverage = Precision.toBasisPoints(_callParams.sizeDeltaInUsd, _callParams.collateralDelta);
        uint _sizeDelta = Math.mulDiv(_callParams.sizeDeltaInUsd, _allocated, _callParams.collateralDelta);

        _requestKey = _submitOrder(
            _callParams,
            _allocationAddress,
            GmxPositionUtils.OrderType.MarketIncrease,
            config.increaseCallbackGasLimit,
            _sizeDelta,
            _allocated,
            msg.sender // callbackContract
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
                _puppetList,
                _traderMatchingKey,
                _allocationAddress,
                _sizeDelta,
                _traderTargetLeverage,
                _requestKey,
                _allocated,
                _allocatedList
            )
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
     * @param _callParams Position parameters for the trader's adjustment, including market, collateral token,
     * size delta, and execution fee.
     * @param _puppetList The list of puppet addresses to allocate funds to
     * @return _requestKey The GMX request key for the submitted adjustment order
     */
    function requestAdjust(
        CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(
            _callParams.collateralDelta > 0 || _callParams.sizeDeltaInUsd > 0,
            Error.MirrorPosition__NoAdjustmentRequired()
        );

        // Collect keeper fee and update allocations inline
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId);
        address _allocationAddress =
            Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));

        uint _allocated = allocationMap[_allocationAddress];

        require(_allocated > 0, Error.Allocation__InvalidAllocation(_allocationAddress));
        require(_callParams.keeperFee > 0, Error.Allocation__InvalidKeeperExecutionFeeAmount());
        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _allocated),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_callParams.keeperFee, _allocated)
        );

        uint[] memory _allocationList = allocationPuppetList[_allocationAddress];
        uint[] memory _balanceList = allocationStore.getBalanceList(_callParams.collateralToken, _puppetList);
        uint _puppetCount = _puppetList.length;

        require(
            _allocationList.length == _puppetCount,
            Error.Allocation__PuppetListMismatch(_allocationList.length, _puppetCount)
        );
        require(
            _allocated > _callParams.keeperFee,
            Error.Allocation__InsufficientAllocationForKeeperFee(_allocated, _callParams.keeperFee)
        );

        uint _remainingKeeperFeeToCollect = _callParams.keeperFee;
        uint _keeperExecutionFeeInsolvency = 0;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _puppetAllocation = _allocationList[_i];
            if (_puppetAllocation == 0) continue;

            uint _remainingPuppets = _puppetCount - _i;
            uint _executionFee = (_remainingKeeperFeeToCollect + _remainingPuppets - 1) / _remainingPuppets;

            if (_executionFee > _remainingKeeperFeeToCollect) {
                _executionFee = _remainingKeeperFeeToCollect;
            }

            if (_balanceList[_i] >= _executionFee) {
                _balanceList[_i] -= _executionFee;
                _remainingKeeperFeeToCollect -= _executionFee;
            } else {
                if (_puppetAllocation > _executionFee) {
                    _allocationList[_i] = _puppetAllocation - _executionFee;
                } else {
                    _keeperExecutionFeeInsolvency += _puppetAllocation;
                    _allocationList[_i] = 0;
                }
            }
        }

        require(
            _remainingKeeperFeeToCollect == 0,
            Error.Allocation__KeeperFeeNotFullyCovered(0, _remainingKeeperFeeToCollect)
        );

        _allocated -= _keeperExecutionFeeInsolvency;

        require(
            _callParams.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _allocated),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_callParams.keeperFee, _allocated)
        );

        allocationStore.setBalanceList(_callParams.collateralToken, _puppetList, _balanceList);
        allocationPuppetList[_allocationAddress] = _allocationList;
        allocationMap[_allocationAddress] = _allocated;

        allocationStore.transferOut(
            config.transferOutGasLimit,
            _callParams.collateralToken,
            _callParams.keeperFeeReceiver,
            _callParams.keeperFee
        );

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound(_allocationAddress));
        require(_position.traderCollateral > 0, Error.MirrorPosition__TraderCollateralZero(_allocationAddress));

        // Calculate adjustments
        uint _currentPuppetLeverage = Precision.toBasisPoints(_position.size, _allocated);

        uint _newTraderSize;
        uint _newTraderCollateral;

        if (_callParams.isIncrease) {
            _newTraderSize = _position.traderSize + _callParams.sizeDeltaInUsd;
            _newTraderCollateral = _position.traderCollateral + _callParams.collateralDelta;
        } else {
            _newTraderSize = _position.traderSize > _callParams.sizeDeltaInUsd
                ? _position.traderSize - _callParams.sizeDeltaInUsd
                : 0;
            _newTraderCollateral = _position.traderCollateral > _callParams.collateralDelta
                ? _position.traderCollateral - _callParams.collateralDelta
                : 0;
        }

        uint _traderTargetLeverage;
        if (_callParams.isIncrease) {
            _traderTargetLeverage = Precision.toBasisPoints(_newTraderSize, _newTraderCollateral);
        } else {
            if (
                _position.traderSize > _callParams.sizeDeltaInUsd
                    && _position.traderCollateral > _callParams.collateralDelta
            ) {
                _traderTargetLeverage = Precision.toBasisPoints(_newTraderSize, _newTraderCollateral);
            } else {
                _traderTargetLeverage = 0;
            }
        }

        require(_traderTargetLeverage != _currentPuppetLeverage, Error.MirrorPosition__NoAdjustmentRequired());
        require(_currentPuppetLeverage > 0, Error.MirrorPosition__InvalidCurrentLeverage());

        // Calculate size delta
        bool isIncrease = _traderTargetLeverage > _currentPuppetLeverage;
        uint _sizeDelta;

        if (isIncrease) {
            _sizeDelta =
                Math.mulDiv(_position.size, (_traderTargetLeverage - _currentPuppetLeverage), _currentPuppetLeverage);
        } else if (_traderTargetLeverage == 0) {
            _sizeDelta = _position.size;
        } else {
            _sizeDelta =
                Math.mulDiv(_position.size, (_currentPuppetLeverage - _traderTargetLeverage), _currentPuppetLeverage);
        }

        _requestKey = _submitOrder(
            _callParams,
            _allocationAddress,
            isIncrease ? GmxPositionUtils.OrderType.MarketIncrease : GmxPositionUtils.OrderType.MarketDecrease,
            isIncrease ? config.increaseCallbackGasLimit : config.decreaseCallbackGasLimit,
            _sizeDelta,
            0,
            msg.sender // callbackContract
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
                _traderMatchingKey,
                _allocationAddress,
                _allocated,
                _sizeDelta,
                _traderTargetLeverage,
                _requestKey,
                _keeperExecutionFeeInsolvency,
                _allocationList
            )
        );
    }

    /**
     * @notice Closes a stalled mirrored position when trader has closed their position on GMX
     * @dev This function checks if the trader's position still exists on GMX using the DataStore.
     * If the trader's position is closed (size = 0) but the mirrored position still exists,
     * it submits a market decrease order to close the entire mirrored position.
     * This prevents puppets from being stuck in positions that the trader has already exited.
     * @param _params The position parameters to verify and close
     * @param _allocationAddress The allocation address of the mirrored position
     * @param _callbackContract The callback contract for GMX order execution
     * @return _requestKey The GMX request key for the close order
     */
    function requestCloseStalledPosition(
        CallPosition calldata _params,
        address _allocationAddress,
        address _callbackContract
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        require(_allocationAddress != address(0), Error.MirrorPosition__InvalidAllocation(_allocationAddress));

        Position memory _position = positionMap[_allocationAddress];
        require(_position.size > 0, Error.MirrorPosition__PositionNotFound(_allocationAddress));
        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(_params.trader, _params.market, _params.collateralToken, _params.isLong);

        require(
            GmxPositionUtils.getPositionSizeInUsd(config.gmxDataStore, positionKey) > 0,
            Error.MirrorPosition__PositionNotStalled(_allocationAddress, positionKey)
        );

        _requestKey = _submitOrder(
            _params,
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
            abi.encode(_params, _allocationAddress, _position.size, positionKey, _requestKey)
        );
    }

    function execute(
        bytes32 _requestKey
    ) external auth nonReentrant {
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
        } else {
            positionMap[_request.allocationAddress] = _position;
        }

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

    function liquidate(
        address _allocationAddress
    ) external auth nonReentrant {
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
        uint _initialCollateralDeltaAmount,
        address _callbackContract
    ) internal returns (bytes32 requestKey) {
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
            AllocationAccount(_allocationAddress).execute(address(config.gmxExchangeRouter), gmxCallData, gasleft());

        if (!success) {
            ErrorUtils.revertWithParsedMessage(returnData);
        }

        requestKey = abi.decode(returnData, (bytes32));
        require(requestKey != bytes32(0), Error.MirrorPosition__OrderCreationFailed());
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
        require(_config.fallbackRefundExecutionFeeReceiver != address(0), "Invalid Refund Execution Fee Receiver");
        require(_config.maxPuppetList > 0, "Invalid Max Puppet List");
        require(_config.maxKeeperFeeToAllocationRatio > 0, "Invalid Max Keeper Fee To Allocation Ratio");
        require(_config.maxKeeperFeeToAdjustmentRatio > 0, "Invalid Max Keeper Fee To Adjustment Ratio");

        config = _config;
    }
}
