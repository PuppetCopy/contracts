// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AllocationAccount} from "../shared/AllocationAccount.sol";
import {AllocationStore} from "../shared/AllocationStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchingRule} from "./MatchingRule.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title Allocation
 * @notice Manages allocation logic for puppet copy trading
 * @dev Handles creation and management of allocation accounts for puppets following traders
 */
contract Allocation is CoreContract {
    struct Config {
        uint platformSettleFeeFactor;
        uint maxKeeperFeeToCollectDustRatio;
        uint maxPuppetList;
        uint maxKeeperFeeToAllocationRatio;
        uint maxKeeperFeeToAdjustmentRatio;
        address gmxOrderVault;
        uint allocationAccountTransferGasLimit;
    }

    struct CallAllocation {
        IERC20 collateralToken;
        address trader;
        address[] puppetList;
        uint allocationId;
        uint keeperFee;
        address keeperFeeReceiver;
    }

    struct CallSettle {
        IERC20 collateralToken;
        IERC20 distributionToken;
        address keeperFeeReceiver;
        address trader;
        uint allocationId;
        uint keeperExecutionFee;
    }

    AllocationStore public immutable allocationStore;
    address public immutable allocationAccountImplementation;

    Config public config;
    IERC20[] public tokenDustThresholdList;

    // Allocation tracking
    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;
    mapping(IERC20 token => uint) public tokenDustThresholdAmountMap;

    // Platform fee tracking
    mapping(IERC20 token => uint accumulatedFees) public platformFeeMap;

    constructor(
        IAuthority _authority,
        AllocationStore _allocationStore,
        Config memory _config
    ) CoreContract(_authority) {
        allocationStore = _allocationStore;
        allocationAccountImplementation = address(new AllocationAccount(_allocationStore));
        _setConfig(abi.encode(_config));
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Get total allocation for an address
     */
    function getAllocation(
        address _allocationAddress
    ) external view returns (uint) {
        return allocationMap[_allocationAddress];
    }

    /**
     * @notice Get puppet allocations for an address
     */
    function getPuppetAllocationList(
        address _allocationAddress
    ) external view returns (uint[] memory) {
        return allocationPuppetList[_allocationAddress];
    }

    /**
     * @notice Initialize trader activity throttle
     */
    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    /**
     * @notice Creates allocations for puppets following a trader
     * @dev Calculates how much each puppet allocates based on their rules and balances
     * @return _allocationAddress The deterministic address for this allocation
     * @return _allocated The total amount allocated after keeper fee
     */
    function createAllocation(
        MatchingRule _matchingRule,
        CallAllocation calldata _params
    ) external auth returns (address _allocationAddress, uint _allocated) {
        uint _puppetCount = _params.puppetList.length;
        require(_puppetCount > 0, Error.Allocation__PuppetListEmpty());

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_params.puppetList, _traderMatchingKey, _params.allocationId);

        _allocationAddress =
            Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));
        Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);

        // Get rules and balances
        MatchingRule.Rule[] memory _rules = _matchingRule.getRuleList(_traderMatchingKey, _params.puppetList);
        uint[] memory _balances = allocationStore.getBalanceList(_params.collateralToken, _params.puppetList);

        uint _estimatedFeePerPuppet = _params.keeperFee / _puppetCount;
        uint _grossAllocation = 0;

        // Initialize puppet allocations array
        uint[] memory _puppetAllocations = new uint[](_puppetCount);
        allocationPuppetList[_allocationAddress] = new uint[](_puppetCount);

        // Calculate allocations for each puppet
        for (uint _i = 0; _i < _puppetCount; _i++) {
            address _puppet = _params.puppetList[_i];
            MatchingRule.Rule memory _rule = _rules[_i];

            // Check if puppet is eligible (rule active and throttle passed)
            if (
                _rule.expiry > block.timestamp
                    && block.timestamp >= lastActivityThrottleMap[_traderMatchingKey][_puppet]
            ) {
                uint _puppetAllocation = Precision.applyBasisPoints(_rule.allowanceRate, _balances[_i]);

                // Skip if keeper fee is too high relative to allocation
                if (
                    _estimatedFeePerPuppet
                        > Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _puppetAllocation)
                ) {
                    continue;
                }

                _puppetAllocations[_i] = _puppetAllocation;
                allocationPuppetList[_allocationAddress][_i] = _puppetAllocation;
                _balances[_i] -= _puppetAllocation;
                _grossAllocation += _puppetAllocation;

                // Update throttle
                lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
            }
        }

        // Update balances in store
        allocationStore.setBalanceList(_params.collateralToken, _params.puppetList, _balances);

        // Validate keeper fee doesn't exceed maximum ratio
        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _grossAllocation),
            Error.Allocation__KeeperFeeExceedsCostFactor(_params.keeperFee, _grossAllocation)
        );

        // Calculate net allocation after keeper fee
        _allocated = _grossAllocation - _params.keeperFee;
        allocationMap[_allocationAddress] = _allocated;

        // Transfer keeper fee to receiver
        allocationStore.transferOut(_params.collateralToken, _params.keeperFeeReceiver, _params.keeperFee);

        // Transfer net allocation to GMX vault
        allocationStore.transferOut(_params.collateralToken, config.gmxOrderVault, _allocated);

        // Log allocation creation
        _logEvent(
            "CreateAllocation",
            abi.encode(_params, _allocationAddress, _grossAllocation, _allocated, _puppetAllocations)
        );

        return (_allocationAddress, _allocated);
    }

    /**
     * @notice Updates allocations when handling keeper fees for adjustments
     * @dev Reduces puppet allocations if they can't afford their share of keeper fee
     * @return _allocationAddress The allocation account address
     * @return _nextAllocated The updated total allocation after deducting insolvencies
     */
    function updateAllocationsForKeeperFee(
        CallAllocation calldata _params
    ) external auth returns (address _allocationAddress, uint _nextAllocated) {
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_params.puppetList, _traderMatchingKey, _params.allocationId);
        _allocationAddress =
            Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));

        uint _currentTotal = allocationMap[_allocationAddress];

        require(_currentTotal > 0, Error.Allocation__InvalidAllocation(_allocationAddress));
        require(_params.keeperFee > 0, Error.Allocation__InvalidKeeperExecutionFeeAmount());
        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _currentTotal),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_params.keeperFee, _currentTotal)
        );

        uint[] memory _puppetAllocations = allocationPuppetList[_allocationAddress];
        uint[] memory _balanceList = allocationStore.getBalanceList(_params.collateralToken, _params.puppetList);

        uint _puppetCount = _params.puppetList.length;
        require(
            _puppetAllocations.length == _puppetCount, 
            Error.Allocation__PuppetListMismatch(_puppetAllocations.length, _puppetCount)
        );
        uint _totalInsolvency = 0;
        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _allocation = _puppetAllocations[_i];
            if (_allocation == 0) continue;

            uint _puppetFeeShare = (_params.keeperFee * _allocation) / _currentTotal;
            uint _balance = _balanceList[_i];

            uint _paidFromBalance = _balance > _puppetFeeShare ? _puppetFeeShare : _balance;
            _balanceList[_i] = _balance - _paidFromBalance;

            uint _unpaidAmount = _puppetFeeShare - _paidFromBalance;
            if (_unpaidAmount > 0) {
                uint _allocationReduction = _allocation > _unpaidAmount ? _unpaidAmount : _allocation;
                _puppetAllocations[_i] = _allocation - _allocationReduction;
                _totalInsolvency += _allocationReduction;
            }
        }

        _nextAllocated = _currentTotal > _totalInsolvency ? _currentTotal - _totalInsolvency : 0;

        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _nextAllocated),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_params.keeperFee, _nextAllocated)
        );

        allocationStore.setBalanceList(_params.collateralToken, _params.puppetList, _balanceList);
        allocationPuppetList[_allocationAddress] = _puppetAllocations;
        allocationMap[_allocationAddress] = _nextAllocated;

        allocationStore.transferOut(_params.collateralToken, _params.keeperFeeReceiver, _params.keeperFee);

        _logEvent(
            "UpdateAllocationForKeeperFee",
            abi.encode(
                _allocationAddress,
                _params.collateralToken,
                _params.keeperFee,
                _currentTotal,
                _nextAllocated,
                _totalInsolvency,
                _balanceList
            )
        );

        return (_allocationAddress, _nextAllocated);
    }

    /**
     * @notice Clears allocation data (used after position is closed)
     */
    function clearAllocation(
        address _allocationAddress
    ) external auth {
        delete allocationMap[_allocationAddress];
        delete allocationPuppetList[_allocationAddress];
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
     * @return _settledAmount Total amount that was settled
     * @return _distributionAmount Amount distributed to puppets after fees
     * @return _platformFeeAmount Platform fee taken
     */
    function settle(
        CallSettle calldata _callParams,
        address[] calldata _puppetList
    ) external auth returns (uint _settledAmount, uint _distributionAmount, uint _platformFeeAmount) {
        uint _puppetCount = _puppetList.length;
        require(_puppetCount > 0, Error.Allocation__PuppetListEmpty());
        require(
            _puppetCount <= config.maxPuppetList,
            Error.Allocation__PuppetListExceedsMaximum(_puppetCount, config.maxPuppetList)
        );

        uint _keeperFee = _callParams.keeperExecutionFee;
        require(_keeperFee > 0, Error.Allocation__InvalidKeeperExecutionFeeAmount());
        address _keeperFeeReceiver = _callParams.keeperFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.Allocation__InvalidKeeperExecutionFeeReceiver());

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId);
        address _allocationAddress =
            Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));

        uint _allocation = allocationMap[_allocationAddress];
        require(_allocation > 0, Error.Allocation__InvalidAllocation(_allocationAddress));

        _settledAmount = _callParams.distributionToken.balanceOf(_allocationAddress);

        (bool _success, bytes memory returnData) = AllocationAccount(_allocationAddress).execute(
            address(_callParams.distributionToken),
            abi.encodeWithSelector(IERC20.transfer.selector, address(allocationStore), _settledAmount),
            config.allocationAccountTransferGasLimit
        );
        require(
            _success,
            Error.Allocation__SettlementTransferFailed(address(_callParams.distributionToken), _allocationAddress)
        );

        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "ERC20 transfer returned false");
        }

        // Update AllocationStore internal accounting and get actual transferred amount
        uint _recordedAmountIn = allocationStore.recordTransferIn(_callParams.distributionToken);

        require(
            _recordedAmountIn >= _settledAmount,
            Error.Allocation__InvalidSettledAmount(_callParams.distributionToken, _recordedAmountIn, _settledAmount)
        );

        require(
            _callParams.keeperExecutionFee
                < Precision.applyFactor(config.maxKeeperFeeToCollectDustRatio, _recordedAmountIn),
            Error.Allocation__KeeperFeeExceedsSettledAmount(_callParams.keeperExecutionFee, _recordedAmountIn)
        );

        _distributionAmount = _recordedAmountIn - _callParams.keeperExecutionFee;

        allocationStore.transferOut(
            _callParams.distributionToken, _callParams.keeperFeeReceiver, _callParams.keeperExecutionFee
        );

        // Calculate platform fee from distribution amount
        if (config.platformSettleFeeFactor > 0) {
            _platformFeeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _distributionAmount);

            if (_platformFeeAmount > _distributionAmount) {
                _platformFeeAmount = _distributionAmount;
            }
            _distributionAmount -= _platformFeeAmount;
            platformFeeMap[_callParams.distributionToken] += _platformFeeAmount;
        }

        uint[] memory _nextBalanceList = allocationStore.getBalanceList(_callParams.distributionToken, _puppetList);
        uint[] memory _puppetAllocations = allocationPuppetList[_allocationAddress];

        for (uint _i = 0; _i < _puppetCount; _i++) {
            _nextBalanceList[_i] += Math.mulDiv(_distributionAmount, _puppetAllocations[_i], _allocation);
        }
        allocationStore.setBalanceList(_callParams.distributionToken, _puppetList, _nextBalanceList);

        _logEvent(
            "Settle",
            abi.encode(
                _callParams,
                _traderMatchingKey,
                _allocationAddress,
                _settledAmount,
                _distributionAmount,
                _platformFeeAmount,
                _nextBalanceList
            )
        );
    }

    /**
     * @notice Collects dust tokens from an allocation account
     * @dev Transfers small amounts of tokens that are below the dust threshold
     * @param _allocationAccount The allocation account to collect dust from
     * @param _dustToken The token to collect
     * @param _receiver The address to receive the dust
     * @return _dustAmount The amount of dust collected
     */
    function collectDust(
        AllocationAccount _allocationAccount,
        IERC20 _dustToken,
        address _receiver
    ) external auth returns (uint _dustAmount) {
        require(_receiver != address(0), Error.Allocation__InvalidReceiver());

        _dustAmount = _dustToken.balanceOf(address(_allocationAccount));
        uint _dustThreshold = tokenDustThresholdAmountMap[_dustToken];

        require(_dustThreshold > 0, Error.Allocation__DustThresholdNotSet(address(_dustToken)));
        require(
            _dustAmount > 0, Error.Allocation__NoDustToCollect(address(_dustToken), address(_allocationAccount))
        );
        require(
            _dustAmount <= _dustThreshold, Error.Allocation__AmountExceedsDustThreshold(_dustAmount, _dustThreshold)
        );

        (bool _success, bytes memory returnData) = _allocationAccount.execute(
            address(_dustToken),
            abi.encodeWithSelector(IERC20.transfer.selector, address(allocationStore), _dustAmount),
            config.allocationAccountTransferGasLimit
        );

        require(_success, Error.Allocation__DustTransferFailed(address(_dustToken), address(_allocationAccount)));

        // Validate ERC20 transfer return value
        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "ERC20 transfer returned false");
        }

        allocationStore.transferOut(_dustToken, _receiver, _dustAmount);

        // Log dust collection event
        _logEvent("CollectDust", abi.encode(_allocationAccount, _dustToken, _receiver, _dustAmount));

        return _dustAmount;
    }

    /**
     * @notice Collects platform fees from AllocationStore
     * @dev This function allows authorized contracts to collect accumulated platform fees
     * @param _token The token to collect fees for
     * @param _receiver The address to receive the collected fees
     * @param _amount The amount of fees to collect (must not exceed accumulated fees)
     */
    function collectFees(IERC20 _token, address _receiver, uint _amount) external auth {
        require(_receiver != address(0), "Invalid receiver");
        require(_amount > 0, "Invalid amount");
        require(_amount <= platformFeeMap[_token], "Amount exceeds accumulated fees");

        platformFeeMap[_token] -= _amount;
        allocationStore.transferOut(_token, _receiver, _amount);

        _logEvent("CollectFees", abi.encode(_token, _receiver, _amount));
    }

    /**
     * @notice Sets dust thresholds for tokens
     */
    function setTokenDustThresholdList(
        IERC20[] calldata _tokenDustThresholdList,
        uint[] calldata _tokenDustThresholdCapList
    ) external auth {
        require(
            _tokenDustThresholdList.length == _tokenDustThresholdCapList.length, "Invalid token dust threshold list"
        );

        // Clear existing thresholds
        for (uint i = 0; i < tokenDustThresholdList.length; i++) {
            delete tokenDustThresholdAmountMap[tokenDustThresholdList[i]];
        }

        // Set new thresholds
        for (uint i = 0; i < _tokenDustThresholdList.length; i++) {
            IERC20 _token = _tokenDustThresholdList[i];
            uint _cap = _tokenDustThresholdCapList[i];

            require(_cap > 0, "Invalid token dust threshold cap");
            require(address(_token) != address(0), "Invalid token address");

            tokenDustThresholdAmountMap[_token] = _cap;
        }

        tokenDustThresholdList = _tokenDustThresholdList;

        // Log dust threshold configuration
        _logEvent("SetTokenDustThreshold", abi.encode(_tokenDustThresholdList, _tokenDustThresholdCapList));
    }

    /**
     * @notice Internal function to set configuration
     * @dev Required by CoreContract
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.platformSettleFeeFactor > 0, "Invalid Platform Settle Fee Factor");
        require(_config.maxKeeperFeeToCollectDustRatio > 0, "Invalid Max Keeper Fee To Collect Dust Ratio");
        require(_config.maxPuppetList > 0, "Invalid Max Puppet List");
        require(_config.maxKeeperFeeToAllocationRatio > 0, "Invalid Max Keeper Fee To Allocation Ratio");
        require(_config.maxKeeperFeeToAdjustmentRatio > 0, "Invalid Max Keeper Fee To Adjustment Ratio");
        require(_config.gmxOrderVault != address(0), "Invalid GMX Order Vault");
        require(_config.allocationAccountTransferGasLimit > 0, "Invalid Token Transfer Gas Limit");

        config = _config;
    }
}
