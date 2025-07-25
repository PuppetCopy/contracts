// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Account} from "../shared/Account.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Mirror} from "./Mirror.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title Settle
 * @notice Handles settlement and distribution of funds for puppet copy trading positions
 * @dev Manages the settlement process when positions are closed or partially closed
 */
contract Settle is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint platformSettleFeeFactor;
        uint maxKeeperFeeToSettleRatio;
        uint maxPuppetList;
        uint allocationAccountTransferGasLimit;
    }

    struct CallSettle {
        IERC20 collateralToken;
        IERC20 distributionToken;
        address keeperFeeReceiver;
        address trader;
        uint allocationId;
        uint keeperExecutionFee;
    }

    Config config;
    IERC20[] public tokenDustThresholdList;

    // Platform fee tracking
    mapping(IERC20 token => uint accumulatedFees) public platformFeeMap;
    mapping(IERC20 token => uint) public tokenDustThresholdAmountMap;

    constructor(
        IAuthority _authority,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Settles and distributes funds received for a specific allocation instance.
     * @dev This function is called by a Keeper when funds related to a closed or partially closed
     * GMX position (identified by the allocation instance) are available in the AllocationAccount.
     * It retrieves the specified `distributeToken` balance from the account, transfers it to the
     * central `AllocationStore`, deducts a Keeper fee (paid to msg.sender) and a platform fee and distributes the
     * remaining amount to the participating Puppets' balances within the `AllocationStore` based on their original
     * contribution ratios (`allocationPuppetMap`).
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
        Mirror _mirror,
        Account _account,
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
        address _allocationAddress = _account.getAllocationAddress(_puppetList, _traderMatchingKey, _callParams.allocationId);

        uint _allocation = _mirror.allocationMap(_allocationAddress);
        require(_allocation > 0, Error.Allocation__InvalidAllocation(_allocationAddress));

        _settledAmount = _account.transferInAllocation(
            _allocationAddress, _callParams.distributionToken, config.allocationAccountTransferGasLimit
        );

        require(
            _callParams.keeperExecutionFee < Precision.applyFactor(config.maxKeeperFeeToSettleRatio, _settledAmount),
            Error.Allocation__KeeperFeeExceedsSettledAmount(_callParams.keeperExecutionFee, _settledAmount)
        );

        _distributionAmount = _settledAmount - _callParams.keeperExecutionFee;

        _account.transferOut(
            _callParams.distributionToken, _callParams.keeperFeeReceiver, _callParams.keeperExecutionFee
        );

        if (config.platformSettleFeeFactor > 0) {
            _platformFeeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _distributionAmount);

            if (_platformFeeAmount > _distributionAmount) {
                _platformFeeAmount = _distributionAmount;
            }
            _distributionAmount -= _platformFeeAmount;
            platformFeeMap[_callParams.distributionToken] += _platformFeeAmount;
        }

        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.distributionToken, _puppetList);
        uint[] memory _puppetAllocations = _mirror.getAllocationPuppetList(_allocationAddress);

        for (uint _i = 0; _i < _puppetCount; _i++) {
            _nextBalanceList[_i] += Math.mulDiv(_distributionAmount, _puppetAllocations[_i], _allocation);
        }
        _account.setBalanceList(_callParams.distributionToken, _puppetList, _nextBalanceList);

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
        Account _account,
        address _allocationAccount,
        IERC20 _dustToken,
        address _receiver
    ) external auth returns (uint _dustAmount) {
        require(_receiver != address(0), Error.Allocation__InvalidReceiver());

        _dustAmount = _dustToken.balanceOf(_allocationAccount);
        uint _dustThreshold = tokenDustThresholdAmountMap[_dustToken];

        require(_dustThreshold > 0, Error.Allocation__DustThresholdNotSet(address(_dustToken)));
        require(_dustAmount > 0, Error.Allocation__NoDustToCollect(address(_dustToken), _allocationAccount));
        require(
            _dustAmount <= _dustThreshold, Error.Allocation__AmountExceedsDustThreshold(_dustAmount, _dustThreshold)
        );

        _dustAmount = _account.transferInAllocation(
            _allocationAccount,
            _dustToken,
            config.allocationAccountTransferGasLimit
        );

        _account.transferOut(_dustToken, _receiver, _dustAmount);

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
    function collectFees(Account _account, IERC20 _token, address _receiver, uint _amount) external auth {
        require(_receiver != address(0), "Invalid receiver");
        require(_amount > 0, "Invalid amount");
        require(_amount <= platformFeeMap[_token], "Amount exceeds accumulated fees");

        platformFeeMap[_token] -= _amount;
        _account.transferOut(_token, _receiver, _amount);

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
        require(_config.maxKeeperFeeToSettleRatio > 0, "Invalid Max Keeper Fee To Settle Ratio");
        require(_config.maxPuppetList > 0, "Invalid Max Puppet List");
        require(_config.allocationAccountTransferGasLimit > 0, "Invalid Token Transfer Gas Limit");

        config = _config;
    }
}
