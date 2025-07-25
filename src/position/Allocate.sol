// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {AllocationAccount} from "../shared/AllocationAccount.sol";
import {AllocationStore} from "../shared/AllocationStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Rule} from "./Rule.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title Allocate
 * @notice Handles allocation creation and management across core contracts
 * @dev Core contract for allocation logic and user balance management
 */
contract Allocate is CoreContract, ReentrancyGuardTransient {
    struct Config {
        uint transferOutGasLimit;
        uint maxPuppetList;
        uint maxKeeperFeeToAllocationRatio;
        uint maxKeeperFeeToAdjustmentRatio;
    }

    AllocationStore public immutable allocationStore;
    address public immutable allocationAccountImplementation;

    Config config;

    // Allocation tracking
    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;

    // User balance tracking
    mapping(IERC20 token => mapping(address user => uint)) public userBalanceMap;

    // Deposit configuration
    IERC20[] public tokenAllowanceList;
    mapping(IERC20 token => uint) tokenAllowanceCapMap;

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

    /**
     * @notice Get puppet allocation list for an allocation
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
     * @notice Get balance list for multiple users and a token
     */
    function getBalanceList(IERC20 _token, address[] calldata _userList) external view returns (uint[] memory) {
        uint _accountListLength = _userList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_userList[i]];
        }
        return _balanceList;
    }

    /**
     * @notice Set balance list for multiple users and a token
     */
    function setBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _balanceList
    ) external auth {
        uint _accountListLength = _accountList.length;
        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }

    /**
     * @notice Deposit tokens for a user
     */
    function deposit(IERC20 _collateralToken, address _depositor, address _user, uint _amount) external auth {
        require(_amount > 0, Error.Deposit__InvalidAmount());

        uint allowanceCap = tokenAllowanceCapMap[_collateralToken];
        require(allowanceCap > 0, Error.Deposit__TokenNotAllowed());

        uint nextBalance = userBalanceMap[_collateralToken][_user] + _amount;
        require(nextBalance <= allowanceCap, Error.Deposit__AllowanceAboveLimit(allowanceCap));

        allocationStore.transferIn(_collateralToken, _depositor, _amount);
        userBalanceMap[_collateralToken][_user] = nextBalance;

        _logEvent("Deposit", abi.encode(_collateralToken, _depositor, _user, nextBalance, _amount));
    }

    /**
     * @notice Withdraw tokens for a user
     */
    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.Deposit__InvalidAmount());

        uint balance = userBalanceMap[_collateralToken][_user];

        require(_amount <= balance, Error.Deposit__InsufficientBalance());

        uint nextBalance = balance - _amount;

        userBalanceMap[_collateralToken][_user] = nextBalance;
        allocationStore.transferOut(config.transferOutGasLimit, _collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    /**
     * @notice Set token allowance list for deposits
     */
    function setTokenAllowanceList(
        IERC20[] calldata _tokenAllowanceList,
        uint[] calldata _tokenAllowanceCapList
    ) external auth {
        require(_tokenAllowanceList.length == _tokenAllowanceCapList.length, "Invalid token allowance list");

        for (uint i = 0; i < tokenAllowanceList.length; i++) {
            delete tokenAllowanceCapMap[tokenAllowanceList[i]];
        }

        for (uint i = 0; i < _tokenAllowanceList.length; i++) {
            IERC20 _token = _tokenAllowanceList[i];
            uint _cap = _tokenAllowanceCapList[i];

            require(_cap > 0, "Invalid token allowance cap");
            require(address(_token) != address(0), "Invalid token address");

            tokenAllowanceCapMap[_token] = _cap;
        }

        tokenAllowanceList = _tokenAllowanceList;
    }

    /**
     * @notice Initialize trader activity throttle - called by Rule contract
     */
    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    /**
     * @notice Execute a call through an AllocationAccount
     * @param _allocationAddress The allocation account address
     * @param _target The target contract to call
     * @param _callData The call data to execute
     * @param _gasLimit The gas limit for the call
     * @return success Whether the call was successful
     * @return returnData The data returned from the call
     */
    function execute(
        address _allocationAddress,
        address _target,
        bytes calldata _callData,
        uint _gasLimit
    ) external auth returns (bool success, bytes memory returnData) {
        return AllocationAccount(_allocationAddress).execute(_target, _callData, _gasLimit);
    }

    /**
     * @notice Creates a new allocation for position mirroring and transfers funds to destination
     * @param _ruleContract Rule contract to get puppet rules
     * @param _collateralToken Token used for collateral
     * @param _trader Trader address
     * @param _allocationId Unique allocation identifier
     * @param _keeperFee Fee paid to keeper
     * @param _keeperFeeReceiver Address to receive keeper fee
     * @param _puppetList List of puppet addresses
     * @param _destination Destination address to transfer allocated funds to
     * @return _allocationAddress The created allocation address
     * @return _allocated Total amount allocated after fees
     * @return _allocatedList Individual puppet allocation amounts
     */
    function createAllocation(
        Rule _ruleContract,
        IERC20 _collateralToken,
        address _trader,
        uint _allocationId,
        uint _keeperFee,
        address _keeperFeeReceiver,
        address[] calldata _puppetList,
        address _destination
    ) external auth nonReentrant returns (address _allocationAddress, uint _allocated, uint[] memory _allocatedList) {
        uint _puppetCount = _puppetList.length;
        require(_puppetCount > 0, Error.Allocation__PuppetListEmpty());
        require(_puppetCount <= config.maxPuppetList, "Puppet list too large");

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        bytes32 _allocationKey = PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _allocationId);

        _allocationAddress = Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);

        // Get rules and process allocations in single loop
        Rule.RuleParams[] memory _rules = _ruleContract.getRuleList(_traderMatchingKey, _puppetList);
        uint _feePerPuppet = _keeperFee / _puppetCount;
        _allocatedList = new uint[](_puppetCount);
        allocationPuppetList[_allocationAddress] = new uint[](_puppetCount);
        _allocated = 0;

        for (uint _i = 0; _i < _puppetCount; _i++) {
            address _puppet = _puppetList[_i];
            Rule.RuleParams memory _rule = _rules[_i];
            uint _balance = userBalanceMap[_collateralToken][_puppet];

            if (
                _rule.expiry > block.timestamp
                    && block.timestamp >= lastActivityThrottleMap[_traderMatchingKey][_puppet]
            ) {
                uint _puppetAllocation = Precision.applyBasisPoints(_rule.allowanceRate, _balance);

                if (_feePerPuppet > Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _puppetAllocation)) {
                    continue;
                }

                _allocatedList[_i] = _puppetAllocation;
                allocationPuppetList[_allocationAddress][_i] = _puppetAllocation;
                userBalanceMap[_collateralToken][_puppet] = _balance - _puppetAllocation;
                _allocated += _puppetAllocation;
                lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
            }
        }

        require(
            _keeperFee < Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _allocated),
            Error.Allocation__KeeperFeeExceedsCostFactor(_keeperFee, _allocated)
        );

        _allocated -= _keeperFee;
        allocationMap[_allocationAddress] = _allocated;

        // Transfer keeper fee
        allocationStore.transferOut(config.transferOutGasLimit, _collateralToken, _keeperFeeReceiver, _keeperFee);

        // Transfer allocated funds to destination
        allocationStore.transferOut(config.transferOutGasLimit, _collateralToken, _destination, _allocated);
    }

    /**
     * @notice Updates allocation for position adjustments
     * @param _collateralToken Token used for collateral
     * @param _keeperFee Fee paid to keeper
     * @param _keeperFeeReceiver Address to receive keeper fee
     * @param _puppetList List of puppet addresses
     * @param _allocationAddress Address of the allocation to update
     * @return _updatedAllocation Updated total allocation amount
     * @return _keeperExecutionFeeInsolvency Amount of allocation lost due to fee insolvency
     * @return _allocationList Updated individual puppet allocations
     */
    function updateAllocation(
        IERC20 _collateralToken,
        uint _keeperFee,
        address _keeperFeeReceiver,
        address[] calldata _puppetList,
        address _allocationAddress
    )
        external
        auth
        nonReentrant
        returns (uint _updatedAllocation, uint _keeperExecutionFeeInsolvency, uint[] memory _allocationList)
    {
        _updatedAllocation = allocationMap[_allocationAddress];

        require(_updatedAllocation > 0, Error.Allocation__InvalidAllocation(_allocationAddress));
        require(_keeperFee > 0, Error.Allocation__InvalidKeeperExecutionFeeAmount());
        require(
            _keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _updatedAllocation),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_keeperFee, _updatedAllocation)
        );

        _allocationList = allocationPuppetList[_allocationAddress];
        uint _puppetCount = _puppetList.length;

        require(
            _allocationList.length == _puppetCount,
            Error.Allocation__PuppetListMismatch(_allocationList.length, _puppetCount)
        );
        require(
            _updatedAllocation > _keeperFee,
            Error.Allocation__InsufficientAllocationForKeeperFee(_updatedAllocation, _keeperFee)
        );

        uint _remainingKeeperFeeToCollect = _keeperFee;
        _keeperExecutionFeeInsolvency = 0;

        // Process fee collection and balance updates in single loop
        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _puppetAllocation = _allocationList[_i];
            if (_puppetAllocation == 0) continue;

            uint _balance = userBalanceMap[_collateralToken][_puppetList[_i]];
            uint _remainingPuppets = _puppetCount - _i;
            uint _executionFee = (_remainingKeeperFeeToCollect + _remainingPuppets - 1) / _remainingPuppets;

            if (_executionFee > _remainingKeeperFeeToCollect) {
                _executionFee = _remainingKeeperFeeToCollect;
            }

            if (_balance >= _executionFee) {
                userBalanceMap[_collateralToken][_puppetList[_i]] = _balance - _executionFee;
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

        _updatedAllocation -= _keeperExecutionFeeInsolvency;

        require(
            _keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _updatedAllocation),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_keeperFee, _updatedAllocation)
        );
        allocationPuppetList[_allocationAddress] = _allocationList;
        allocationMap[_allocationAddress] = _updatedAllocation;

        // Transfer keeper fee
        allocationStore.transferOut(config.transferOutGasLimit, _collateralToken, _keeperFeeReceiver, _keeperFee);
    }

    /**
     * @notice Internal function to set configuration
     * @dev Required by CoreContract
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.transferOutGasLimit > 0, "Invalid transfer out gas limit");
        require(_config.maxPuppetList > 0, "Invalid max puppet list");
        require(_config.maxKeeperFeeToAllocationRatio > 0, "Invalid max keeper fee to allocation ratio");
        require(_config.maxKeeperFeeToAdjustmentRatio > 0, "Invalid max keeper fee to adjustment ratio");

        config = _config;
    }
}
