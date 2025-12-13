// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Account} from "./Account.sol";
import {Mirror} from "./Mirror.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Settle is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint platformSettleFeeFactor;
        uint maxMatchmakerFeeToSettleRatio;
        uint maxPuppetList;
        uint allocationAccountTransferGasLimit;
    }

    struct CallSettle {
        IERC20 collateralToken;
        IERC20 distributionToken;
        address matchmakerFeeReceiver;
        address trader;
        uint allocationId;
        uint matchmakerExecutionFee;
        uint amount;
    }

    Config config;
    IERC20[] public tokenDustThresholdList;

    // Platform fee tracking
    mapping(IERC20 token => uint accumulatedFees) public platformFeeMap;
    mapping(IERC20 token => uint) public tokenDustThresholdAmountMap;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function settle(
        Account _account,
        Mirror _mirror,
        CallSettle calldata _callParams,
        address[] calldata _puppetList
    ) external auth returns (uint _distributedAmount, uint _platformFeeAmount) {
        uint _puppetCount = _puppetList.length;
        if (_puppetCount == 0) revert Error.Mirror__PuppetListEmpty();
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Settle__PuppetListExceedsMaximum(_puppetCount, config.maxPuppetList);
        }

        uint _matchmakerFee = _callParams.matchmakerExecutionFee;
        if (_matchmakerFee == 0) revert Error.Settle__InvalidMatchmakerExecutionFeeAmount();
        if (_callParams.matchmakerFeeReceiver == address(0)) revert Error.Settle__InvalidMatchmakerExecutionFeeReceiver();

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_callParams.collateralToken, _callParams.trader);
        address _allocationAddress = _account.getAllocationAddress(
            PositionUtils.getAllocationKey(_puppetList, _traderMatchingKey, _callParams.allocationId)
        );

        uint _allocation = _mirror.allocationMap(_allocationAddress);
        if (_allocation == 0) revert Error.Settle__InvalidAllocation(_allocationAddress);

        _account.transferInAllocation(
            _allocationAddress,
            _callParams.distributionToken,
            _callParams.amount,
            config.allocationAccountTransferGasLimit
        );

        if (
            _callParams.matchmakerExecutionFee
                >= Precision.applyFactor(config.maxMatchmakerFeeToSettleRatio, _callParams.amount)
        ) revert Error.Settle__MatchmakerFeeExceedsSettledAmount(_callParams.matchmakerExecutionFee, _callParams.amount);

        _distributedAmount = _callParams.amount - _callParams.matchmakerExecutionFee;

        _account.transferOut(_callParams.distributionToken, _callParams.matchmakerFeeReceiver, _callParams.matchmakerExecutionFee);

        if (config.platformSettleFeeFactor > 0) {
            _platformFeeAmount = Precision.applyFactor(config.platformSettleFeeFactor, _distributedAmount);

            if (_platformFeeAmount > _distributedAmount) {
                _platformFeeAmount = _distributedAmount;
            }
            _distributedAmount -= _platformFeeAmount;
            platformFeeMap[_callParams.distributionToken] += _platformFeeAmount;
        }

        uint[] memory _nextBalanceList = _account.getBalanceList(_callParams.distributionToken, _puppetList);
        uint[] memory _puppetAllocations = _mirror.getAllocationPuppetList(_allocationAddress);
        if (_puppetAllocations.length != _puppetCount) {
            revert Error.Settle__PuppetListMismatch(_puppetAllocations.length, _puppetCount);
        }

        uint _allocationTotal = 0;
        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _alloc = _puppetAllocations[_i];
            _allocationTotal += _alloc;
            _nextBalanceList[_i] += Math.mulDiv(_distributedAmount, _alloc, _allocation);
        }
        if (_allocationTotal != _allocation) revert Error.Settle__InvalidAllocation(_allocationAddress);
        _account.setBalanceList(_callParams.distributionToken, _puppetList, _nextBalanceList);

        _logEvent(
            "Settle",
            abi.encode(
                _callParams.collateralToken,
                _callParams.distributionToken,
                _callParams.matchmakerFeeReceiver,
                _callParams.trader,
                _callParams.allocationId,
                _callParams.matchmakerExecutionFee,
                _allocationAddress,
                _traderMatchingKey,
                _distributedAmount,
                _platformFeeAmount,
                _nextBalanceList
            )
        );
    }

    function collectAllocationAccountDust(
        Account _account,
        address _allocationAccount,
        IERC20 _dustToken,
        address _receiver,
        uint _amount
    ) external auth returns (uint _dustAmount) {
        if (_receiver == address(0)) revert Error.Settle__InvalidReceiver();

        uint _dustThreshold = tokenDustThresholdAmountMap[_dustToken];
        if (_dustThreshold == 0) revert Error.Settle__DustThresholdNotSet(address(_dustToken));
        if (_amount > _dustThreshold) revert Error.Settle__AmountExceedsDustThreshold(_amount, _dustThreshold);

        _account.transferInAllocation(_allocationAccount, _dustToken, _amount, config.allocationAccountTransferGasLimit);

        _account.transferOut(_dustToken, _receiver, _amount);

        _logEvent(
            "CollectAllocationAccountDust",
            abi.encode(_dustToken, _allocationAccount, _receiver, _dustThreshold, _amount)
        );

        return _amount;
    }

    function collectPlatformFees(Account _account, IERC20 _token, address _receiver, uint _amount) external auth {
        if (_receiver == address(0)) revert("Invalid receiver");
        if (_amount == 0) revert("Invalid amount");
        if (_amount > platformFeeMap[_token]) revert("Amount exceeds accumulated fees");

        platformFeeMap[_token] -= _amount;
        _account.transferOut(_token, _receiver, _amount);

        _logEvent("CollectPlatformFees", abi.encode(_token, _receiver, _amount));
    }

    function setTokenDustThresholdList(
        IERC20[] calldata _tokenDustThresholdList,
        uint[] calldata _tokenDustThresholdCapList
    ) external auth {
        if (_tokenDustThresholdList.length != _tokenDustThresholdCapList.length) {
            revert("Invalid token dust threshold list");
        }

        for (uint i = 0; i < tokenDustThresholdList.length; i++) {
            delete tokenDustThresholdAmountMap[tokenDustThresholdList[i]];
        }

        for (uint i = 0; i < _tokenDustThresholdList.length; i++) {
            IERC20 _token = _tokenDustThresholdList[i];
            uint _cap = _tokenDustThresholdCapList[i];

            if (_cap == 0) revert("Invalid token dust threshold cap");
            if (address(_token) == address(0)) revert("Invalid token address");

            tokenDustThresholdAmountMap[_token] = _cap;
        }

        tokenDustThresholdList = _tokenDustThresholdList;

        _logEvent("SetTokenDustThreshold", abi.encode(_tokenDustThresholdList, _tokenDustThresholdCapList));
    }

    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.platformSettleFeeFactor == 0) revert("Invalid Platform Settle Fee Factor");
        if (_config.maxMatchmakerFeeToSettleRatio == 0) revert("Invalid Max Matchmaker Fee To Settle Ratio");
        if (_config.maxPuppetList == 0) revert("Invalid Max Puppet List");
        if (_config.allocationAccountTransferGasLimit == 0) revert("Invalid Token Transfer Gas Limit");

        config = _config;
    }
}
