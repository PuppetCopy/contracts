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

    struct AllocationParams {
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
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetArray;
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
    function getPuppetAllocations(
        address _allocationAddress
    ) external view returns (uint[] memory) {
        return allocationPuppetArray[_allocationAddress];
    }

    /**
     * @notice Gets allocation address for given parameters
     * @dev Helper function to calculate allocation key and predict address
     */
    function getAllocationAddress(
        IERC20 _collateralToken,
        address _trader,
        address[] memory _puppetList,
        uint _allocationId
    ) public view returns (address) {
        bytes32 traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        bytes32 allocationKey = keccak256(abi.encodePacked(_puppetList, traderMatchingKey, _allocationId));
        return Clones.predictDeterministicAddress(allocationAccountImplementation, allocationKey, address(this));
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
     * @return _totalAllocation The total amount allocated after keeper fee
     */
    function createAllocation(
        MatchingRule _matchingRule,
        AllocationParams memory _params
    ) external auth returns (address _allocationAddress, uint _totalAllocation) {
        uint _puppetCount = _params.puppetList.length;
        require(_puppetCount > 0, Error.MirrorPosition__PuppetListEmpty());

        // Calculate allocation address and create clone
        _allocationAddress =
            getAllocationAddress(_params.collateralToken, _params.trader, _params.puppetList, _params.allocationId);
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey =
            keccak256(abi.encodePacked(_params.puppetList, _traderMatchingKey, _params.allocationId));
        Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);

        // Get rules and balances
        MatchingRule.Rule[] memory _rules = _matchingRule.getRuleList(_traderMatchingKey, _params.puppetList);
        uint[] memory _balances = allocationStore.getBalanceList(_params.collateralToken, _params.puppetList);

        uint _estimatedFeePerPuppet = _params.keeperFee / _puppetCount;
        uint _grossAllocation = 0;

        // Initialize puppet allocations array
        uint[] memory _puppetAllocations = new uint[](_puppetCount);
        allocationPuppetArray[_allocationAddress] = new uint[](_puppetCount);

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
                allocationPuppetArray[_allocationAddress][_i] = _puppetAllocation;
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
            Error.MirrorPosition__KeeperFeeExceedsCostFactor(_params.keeperFee, _grossAllocation)
        );

        // Calculate net allocation after keeper fee
        _totalAllocation = _grossAllocation - _params.keeperFee;
        allocationMap[_allocationAddress] = _totalAllocation;

        // Transfer keeper fee to receiver
        allocationStore.transferOut(_params.collateralToken, _params.keeperFeeReceiver, _params.keeperFee);

        // Transfer net allocation to GMX vault
        allocationStore.transferOut(_params.collateralToken, config.gmxOrderVault, _totalAllocation);

        // Log allocation creation
        _logEvent(
            "CreateAllocation",
            abi.encode(_params, _allocationAddress, _grossAllocation, _totalAllocation, _puppetAllocations)
        );

        return (_allocationAddress, _totalAllocation);
    }

    /**
     * @notice Updates allocations when handling keeper fees for adjustments
     * @dev Reduces puppet allocations if they can't afford their share of keeper fee
     * @return _allocationAddress The allocation account address
     * @return _updatedTotal The new total allocation after deductions
     */
    function updateAllocationsForKeeperFee(
        IERC20 _collateralToken,
        address _trader,
        address[] calldata _puppetList,
        uint _allocationId,
        uint _keeperFee,
        address _keeperFeeReceiver
    ) external auth returns (address _allocationAddress, uint _updatedTotal) {
        // Calculate allocation address internally
        _allocationAddress = getAllocationAddress(_collateralToken, _trader, _puppetList, _allocationId);
        uint[] memory _puppetAllocations = allocationPuppetArray[_allocationAddress];
        uint _currentTotal = allocationMap[_allocationAddress];
        uint _puppetCount = _puppetList.length;

        if (_currentTotal == 0 || _keeperFee == 0) {
            return (_allocationAddress, _currentTotal);
        }

        uint _totalReduction = 0;
        uint[] memory _balances = allocationStore.getBalanceList(_collateralToken, _puppetList);

        for (uint _i = 0; _i < _puppetCount; _i++) {
            if (_puppetAllocations[_i] == 0) continue;

            // Calculate puppet's share of keeper fee proportionally
            uint _puppetFeeShare = (_keeperFee * _puppetAllocations[_i]) / _currentTotal;

            if (_balances[_i] >= _puppetFeeShare) {
                // Puppet can afford their share
                _balances[_i] -= _puppetFeeShare;
            } else if (_balances[_i] > 0) {
                // Partial payment - reduce allocation by unpaid amount
                uint _unpaidAmount = _puppetFeeShare - _balances[_i];
                _balances[_i] = 0;

                if (_puppetAllocations[_i] > _unpaidAmount) {
                    _puppetAllocations[_i] -= _unpaidAmount;
                    _totalReduction += _unpaidAmount;
                } else {
                    _totalReduction += _puppetAllocations[_i];
                    _puppetAllocations[_i] = 0;
                }
            } else {
                // Can't pay anything - reduce allocation by full fee share
                if (_puppetAllocations[_i] > _puppetFeeShare) {
                    _puppetAllocations[_i] -= _puppetFeeShare;
                    _totalReduction += _puppetFeeShare;
                } else {
                    _totalReduction += _puppetAllocations[_i];
                    _puppetAllocations[_i] = 0;
                }
            }
        }

        // Update storage
        allocationStore.setBalanceList(_collateralToken, _puppetList, _balances);
        allocationPuppetArray[_allocationAddress] = _puppetAllocations;

        _updatedTotal = _currentTotal > _totalReduction ? _currentTotal - _totalReduction : 0;
        allocationMap[_allocationAddress] = _updatedTotal;

        // Transfer keeper fee to receiver
        allocationStore.transferOut(_collateralToken, _keeperFeeReceiver, _keeperFee);

        // Log allocation update for keeper fee handling
        _logEvent(
            "UpdateAllocationForKeeperFee",
            abi.encode(_allocationAddress, _collateralToken, _keeperFee, _currentTotal, _updatedTotal, _totalReduction)
        );

        return (_allocationAddress, _updatedTotal);
    }

    /**
     * @notice Clears allocation data (used after position is closed)
     */
    function clearAllocation(
        address _allocationAddress
    ) external auth {
        delete allocationMap[_allocationAddress];
        delete allocationPuppetArray[_allocationAddress];
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
        require(_puppetCount > 0, Error.MirrorPosition__PuppetListEmpty());
        require(
            _puppetCount <= config.maxPuppetList,
            Error.MirrorPosition__PuppetListExceedsMaximum(_puppetCount, config.maxPuppetList)
        );

        uint _keeperFee = _callParams.keeperExecutionFee;
        require(_keeperFee > 0, Error.MirrorPosition__InvalidKeeperExecutionFeeAmount());
        address _keeperFeeReceiver = _callParams.keeperFeeReceiver;
        require(_keeperFeeReceiver != address(0), Error.MirrorPosition__InvalidKeeperExecutionFeeReceiver());

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        address _allocationAddress =
            getAllocationAddress(_callParams.collateralToken, _callParams.trader, _puppetList, _callParams.allocationId);

        uint _allocation = allocationMap[_allocationAddress];
        require(_allocation > 0, Error.MirrorPosition__InvalidAllocation(_allocationAddress));

        _settledAmount = _callParams.distributionToken.balanceOf(_allocationAddress);

        (bool _success, bytes memory returnData) = AllocationAccount(_allocationAddress).execute(
            address(_callParams.distributionToken),
            abi.encodeWithSelector(IERC20.transfer.selector, address(allocationStore), _settledAmount),
            config.allocationAccountTransferGasLimit
        );
        require(
            _success,
            Error.MirrorPosition__SettlementTransferFailed(address(_callParams.distributionToken), _allocationAddress)
        );

        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "ERC20 transfer returned false");
        }

        // Update AllocationStore internal accounting and get actual transferred amount
        uint _recordedAmountIn = allocationStore.recordTransferIn(_callParams.distributionToken);

        require(
            _recordedAmountIn >= _settledAmount,
            Error.MirrorPosition__InvalidSettledAmount(_callParams.distributionToken, _recordedAmountIn, _settledAmount)
        );

        require(
            _callParams.keeperExecutionFee
                < Precision.applyFactor(config.maxKeeperFeeToCollectDustRatio, _recordedAmountIn),
            Error.MirrorPosition__KeeperFeeExceedsSettledAmount(_callParams.keeperExecutionFee, _recordedAmountIn)
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
        uint[] memory _puppetAllocations = allocationPuppetArray[_allocationAddress];

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
        require(_receiver != address(0), Error.MirrorPosition__InvalidReceiver());

        _dustAmount = _dustToken.balanceOf(address(_allocationAccount));
        uint _dustThreshold = tokenDustThresholdAmountMap[_dustToken];

        require(_dustThreshold > 0, Error.MirrorPosition__DustThresholdNotSet(address(_dustToken)));
        require(
            _dustAmount > 0, Error.MirrorPosition__NoDustToCollect(address(_dustToken), address(_allocationAccount))
        );
        require(
            _dustAmount <= _dustThreshold, Error.MirrorPosition__AmountExceedsDustThreshold(_dustAmount, _dustThreshold)
        );

        (bool _success, bytes memory returnData) = _allocationAccount.execute(
            address(_dustToken),
            abi.encodeWithSelector(IERC20.transfer.selector, address(allocationStore), _dustAmount),
            config.allocationAccountTransferGasLimit
        );

        require(_success, Error.MirrorPosition__DustTransferFailed(address(_dustToken), address(_allocationAccount)));

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
