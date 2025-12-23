// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CoreContract} from "../utils/CoreContract.sol";

interface IERC7579Account {
    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata additionalContext) external view returns (bool);
}
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Error} from "./../utils/Error.sol";
import {Precision} from "./../utils/Precision.sol";
import {Account} from "./Account.sol";
import {Subscribe} from "./Subscribe.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/// @notice Tracks trader + puppet allocations with O(1) lazy utilization tracking
contract Allocation is CoreContract {
    struct Config {
        uint maxPuppetList;
    }

    Config public config;

    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public allocationBalance;
    mapping(bytes32 traderMatchingKey => uint) public totalAllocation;
    mapping(bytes32 traderMatchingKey => uint) public totalUtilization;

    mapping(bytes32 traderMatchingKey => uint) public currentEpoch;
    mapping(bytes32 traderMatchingKey => mapping(uint epoch => uint)) public epochRemaining;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userEpoch;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userRemainingCheckpoint;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userAllocationSnapshot;

    mapping(bytes32 traderMatchingKey => uint) public cumulativeSettlementPerUtilization;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userSettlementCheckpoint;

    mapping(bytes32 traderMatchingKey => address) public subaccountMap;
    mapping(bytes32 traderMatchingKey => uint) public subaccountRecordedBalance;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint)) public lastActivityThrottleMap;

    mapping(address subaccount => address trader) public subaccountTraderMap;
    mapping(address subaccount => IERC20[]) internal _subaccountTokenList;
    mapping(address subaccount => bool) public registeredSubaccount;

    uint constant PRECISION = 1e30;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSubaccountTokenList(address _subaccount) external view returns (IERC20[] memory) {
        return _subaccountTokenList[_subaccount];
    }

    function getUserUtilization(bytes32 _traderMatchingKey, address _user) public view returns (uint) {
        uint _snapshot = userAllocationSnapshot[_traderMatchingKey][_user];
        if (_snapshot == 0) return 0;

        uint _userEpoch = userEpoch[_traderMatchingKey][_user];
        uint _currentEpoch = currentEpoch[_traderMatchingKey];

        if (_userEpoch < _currentEpoch) return _snapshot;

        uint _checkpoint = userRemainingCheckpoint[_traderMatchingKey][_user];
        uint _current = epochRemaining[_traderMatchingKey][_currentEpoch];

        if (_current >= _checkpoint) return 0;

        return (_snapshot * (_checkpoint - _current)) / _checkpoint;
    }

    function getAvailableAllocation(bytes32 _traderMatchingKey, address _user) external view returns (uint) {
        uint _allocation = allocationBalance[_traderMatchingKey][_user];
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);

        if (_utilization >= _allocation) return 0;
        return _allocation - _utilization;
    }

    function pendingSettlement(bytes32 _traderMatchingKey, address _user) external view returns (uint) {
        return pendingSettlement(_traderMatchingKey, _user, getUserUtilization(_traderMatchingKey, _user));
    }

    function pendingSettlement(bytes32 _traderMatchingKey, address _user, uint _utilization) public view returns (uint) {
        if (_utilization == 0) return 0;

        uint _cumulative = cumulativeSettlementPerUtilization[_traderMatchingKey];
        uint _lastCheckpoint = userSettlementCheckpoint[_traderMatchingKey][_user];

        if (_cumulative <= _lastCheckpoint) return 0;

        return (_utilization * (_cumulative - _lastCheckpoint)) / PRECISION;
    }

    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    function registerSubaccount(address _subaccount, address _hook) external auth {
        if (!IERC7579Account(_subaccount).isModuleInstalled(4, _hook, "")) {
            revert Error.Allocation__UnregisteredSubaccount();
        }
        registeredSubaccount[_subaccount] = true;
    }

    function allocate(
        Account _account,
        Subscribe _subscribe,
        IERC20 _collateralToken,
        address _trader,
        address _subaccount,
        uint _traderAllocation,
        address[] calldata _puppetList
    ) external auth {
        if (!registeredSubaccount[_subaccount]) revert Error.Allocation__UnregisteredSubaccount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, config.maxPuppetList);
        }

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);

        uint _epoch = currentEpoch[_traderMatchingKey];
        if (epochRemaining[_traderMatchingKey][_epoch] == 0) {
            bool _firstInit = _epoch == 0
                && totalUtilization[_traderMatchingKey] == 0
                && totalAllocation[_traderMatchingKey] == 0;

            if (_firstInit) {
                epochRemaining[_traderMatchingKey][0] = PRECISION;
            } else {
                ++_epoch;
                currentEpoch[_traderMatchingKey] = _epoch;
                epochRemaining[_traderMatchingKey][_epoch] = PRECISION;
            }
        }

        if (subaccountMap[_traderMatchingKey] == address(0)) {
            subaccountMap[_traderMatchingKey] = _subaccount;
            subaccountTraderMap[_subaccount] = _trader;
            _subaccountTokenList[_subaccount].push(_collateralToken);
        }

        uint _traderBalance = _account.userBalanceMap(_collateralToken, _trader);
        if (_traderBalance < _traderAllocation) {
            revert Error.Allocation__InsufficientTraderBalance(_traderBalance, _traderAllocation);
        }

        uint _puppetTotalAllocation = 0;
        uint[] memory _puppetAllocationList = new uint[](_puppetCount);
        uint[] memory _puppetUtilizationList = new uint[](_puppetCount);
        uint[] memory _nextBalanceList = _account.getBalanceList(_collateralToken, _puppetList);

        if (_puppetCount > 0) {
            Subscribe.RuleParams[] memory _rules = _subscribe.getRuleList(_traderMatchingKey, _puppetList);

            for (uint _i = 0; _i < _puppetCount; ++_i) {
                address _puppet = _puppetList[_i];
                Subscribe.RuleParams memory _rule = _rules[_i];

                if (_rule.expiry <= block.timestamp) continue;
                if (block.timestamp < lastActivityThrottleMap[_traderMatchingKey][_puppet]) continue;

                uint _puppetAllocation = Precision.applyBasisPoints(_rule.allowanceRate, _nextBalanceList[_i]);
                if (_puppetAllocation == 0) continue;

                uint _newPuppetAllocation = allocationBalance[_traderMatchingKey][_puppet] + _puppetAllocation;
                allocationBalance[_traderMatchingKey][_puppet] = _newPuppetAllocation;
                _puppetUtilizationList[_i] = _updateUserCheckpoints(_traderMatchingKey, _puppet, _newPuppetAllocation);

                _puppetAllocationList[_i] = _puppetAllocation;
                _nextBalanceList[_i] -= _puppetAllocation;
                _puppetTotalAllocation += _puppetAllocation;

                lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
            }
        }

        uint _totalAllocation = _traderAllocation + _puppetTotalAllocation;
        if (_totalAllocation == 0) {
            revert Error.Allocation__ZeroAllocation();
        }

        uint _newTraderAllocation = allocationBalance[_traderMatchingKey][_trader] + _traderAllocation;
        allocationBalance[_traderMatchingKey][_trader] = _newTraderAllocation;
        uint _traderUtilization = _updateUserCheckpoints(_traderMatchingKey, _trader, _newTraderAllocation);
        totalAllocation[_traderMatchingKey] += _totalAllocation;

        _account.setUserBalance(_collateralToken, _trader, _traderBalance - _traderAllocation);
        if (_puppetCount > 0) {
            _account.setBalanceList(_collateralToken, _puppetList, _nextBalanceList);
        }
        _account.transferOut(_collateralToken, _subaccount, _totalAllocation);
        subaccountRecordedBalance[_traderMatchingKey] += _totalAllocation;

        _logEvent(
            "Allocate",
            abi.encode(
                _traderMatchingKey,
                _collateralToken,
                _trader,
                _subaccount,
                _traderAllocation,
                _newTraderAllocation,
                _traderUtilization,
                _puppetTotalAllocation,
                _totalAllocation,
                _puppetList,
                _puppetAllocationList,
                _puppetUtilizationList
            )
        );
    }

    function utilize(bytes32 _traderMatchingKey, uint _utilization) external auth {
        _utilize(_traderMatchingKey, _utilization);
    }

    function syncSettlement(address _subaccount) external auth {
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];
        uint _length = _tokens.length;

        for (uint _i = 0; _i < _length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_token, _trader);

            if (totalUtilization[_traderMatchingKey] == 0) continue;

            uint _actualBalance = _token.balanceOf(_subaccount);
            uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];
            if (_actualBalance <= _recordedBalance) continue;

            _settle(_traderMatchingKey, _token, _subaccount, _actualBalance, _recordedBalance);
        }
    }

    function syncUtilization(address _subaccount) external auth {
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];
        uint _length = _tokens.length;

        for (uint _i = 0; _i < _length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_token, _trader);

            uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];
            if (_recordedBalance == 0) continue;

            uint _actualBalance = _token.balanceOf(_subaccount);
            if (_actualBalance >= _recordedBalance) continue;

            uint _outflow = _recordedBalance - _actualBalance;
            _utilize(_traderMatchingKey, _outflow);
        }
    }

    function _utilize(bytes32 _traderMatchingKey, uint _utilization) internal {
        uint _totalAlloc = totalAllocation[_traderMatchingKey];
        if (_totalAlloc == 0) revert Error.Allocation__ZeroAllocation();

        uint _epoch = currentEpoch[_traderMatchingKey];
        uint _remaining = epochRemaining[_traderMatchingKey][_epoch];
        uint _newRemaining = (_remaining * (_totalAlloc - _utilization)) / _totalAlloc;
        epochRemaining[_traderMatchingKey][_epoch] = _newRemaining;

        uint _newTotalUtilization = totalUtilization[_traderMatchingKey] + _utilization;
        uint _newTotalAllocation = _totalAlloc - _utilization;
        totalUtilization[_traderMatchingKey] = _newTotalUtilization;
        totalAllocation[_traderMatchingKey] = _newTotalAllocation;
        subaccountRecordedBalance[_traderMatchingKey] -= _utilization;

        _logEvent(
            "Utilize",
            abi.encode(_traderMatchingKey, _epoch, _utilization, _newRemaining, _newTotalUtilization, _newTotalAllocation)
        );
    }

    function settle(bytes32 _traderMatchingKey, IERC20 _collateralToken) external auth {
        if (totalUtilization[_traderMatchingKey] == 0) revert Error.Allocation__NoUtilization();

        address _subaccount = subaccountMap[_traderMatchingKey];
        uint _actualBalance = _collateralToken.balanceOf(_subaccount);
        uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];

        _settle(_traderMatchingKey, _collateralToken, _subaccount, _actualBalance, _recordedBalance);
    }

    function _settle(
        bytes32 _traderMatchingKey,
        IERC20 _collateralToken,
        address _subaccount,
        uint _actualBalance,
        uint _recordedBalance
    ) internal {
        uint _totalUtil = totalUtilization[_traderMatchingKey];
        uint _settledAllocation = _actualBalance - _recordedBalance;
        subaccountRecordedBalance[_traderMatchingKey] = _actualBalance;

        uint _deltaPerUtilization = (_settledAllocation * PRECISION) / _totalUtil;
        uint _newCumulative = cumulativeSettlementPerUtilization[_traderMatchingKey] + _deltaPerUtilization;
        cumulativeSettlementPerUtilization[_traderMatchingKey] = _newCumulative;

        _logEvent(
            "Settle",
            abi.encode(_traderMatchingKey, _collateralToken, _subaccount, _settledAllocation, _totalUtil, _deltaPerUtilization, _newCumulative)
        );
    }

    function realize(bytes32 _traderMatchingKey, address _user) external auth returns (uint _realized) {
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);
        _realized = pendingSettlement(_traderMatchingKey, _user, _utilization);

        if (_utilization == 0 && _realized == 0) return 0;

        uint _epoch = currentEpoch[_traderMatchingKey];

        if (_realized == 0 && userEpoch[_traderMatchingKey][_user] < _epoch) {
            uint _allocation = allocationBalance[_traderMatchingKey][_user];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] = cumulativeSettlementPerUtilization[_traderMatchingKey];

            _logEvent("Realize", abi.encode(_traderMatchingKey, _user, _epoch, 0, 0, _allocation));
            return 0;
        }

        if (_utilization > 0) {
            totalUtilization[_traderMatchingKey] -= _utilization;
        }

        if (_realized > 0) {
            totalAllocation[_traderMatchingKey] += _realized;
        }

        uint _newAllocation = allocationBalance[_traderMatchingKey][_user] + _realized - _utilization;
        allocationBalance[_traderMatchingKey][_user] = _newAllocation;

        userEpoch[_traderMatchingKey][_user] = _epoch;
        userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
        userAllocationSnapshot[_traderMatchingKey][_user] = _newAllocation;
        userSettlementCheckpoint[_traderMatchingKey][_user] = cumulativeSettlementPerUtilization[_traderMatchingKey];

        _logEvent("Realize", abi.encode(_traderMatchingKey, _user, _epoch, _realized, _utilization, _newAllocation));
    }

    function withdraw(
        Account _account,
        IERC20 _collateralToken,
        bytes32 _traderMatchingKey,
        address _user,
        uint _amount
    ) external auth {
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);
        uint _realized = 0;

        uint _allocation = allocationBalance[_traderMatchingKey][_user];

        if (_utilization > 0) {
            _realized = pendingSettlement(_traderMatchingKey, _user, _utilization);
            if (_realized == 0) {
                revert Error.Allocation__UtilizationNotSettled(_utilization);
            }

            totalUtilization[_traderMatchingKey] -= _utilization;
            totalAllocation[_traderMatchingKey] += _realized;
            _allocation = _allocation + _realized - _utilization;
            allocationBalance[_traderMatchingKey][_user] = _allocation;

            uint _epoch = currentEpoch[_traderMatchingKey];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] = cumulativeSettlementPerUtilization[_traderMatchingKey];
        }
        if (_allocation < _amount) {
            revert Error.Allocation__InsufficientAllocation(_allocation, _amount);
        }

        uint _newAllocation = _allocation - _amount;
        allocationBalance[_traderMatchingKey][_user] = _newAllocation;
        totalAllocation[_traderMatchingKey] -= _amount;
        _updateUserCheckpoints(_traderMatchingKey, _user, _newAllocation, 0);

        uint _currentBalance = _account.userBalanceMap(_collateralToken, _user);
        _account.setUserBalance(_collateralToken, _user, _currentBalance + _amount);

        _logEvent(
            "Withdraw",
            abi.encode(
                _traderMatchingKey,
                _collateralToken,
                _user,
                _amount,
                _realized,
                _utilization,
                _newAllocation
            )
        );
    }

    function _updateUserCheckpoints(
        bytes32 _traderMatchingKey,
        address _user,
        uint _allocation
    ) internal returns (uint _utilization) {
        _utilization = getUserUtilization(_traderMatchingKey, _user);
        _updateUserCheckpoints(_traderMatchingKey, _user, _allocation, _utilization);
    }

    function _updateUserCheckpoints(
        bytes32 _traderMatchingKey,
        address _user,
        uint _allocation,
        uint _utilization
    ) internal {
        if (_utilization == 0) {
            uint _epoch = currentEpoch[_traderMatchingKey];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] = cumulativeSettlementPerUtilization[_traderMatchingKey];
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        config = _config;
    }
}
