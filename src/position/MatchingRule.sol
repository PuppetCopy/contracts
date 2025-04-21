// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {AllocationStore} from "../shared/AllocationStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MirrorPosition} from "./MirrorPosition.sol";

contract MatchingRule is CoreContract {
    struct Rule {
        uint allowanceRate;
        uint throttleActivity;
        uint expiry;
    }

    struct Config {
        IERC20[] tokenAllowanceList;
        uint[] tokenAllowanceCapList;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
        uint minActivityThrottle;
        uint maxActivityThrottle;
    }

    Config public config;

    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(bytes32 matchingKey => mapping(address puppet => Rule)) public matchingRuleMap;

    MirrorPosition immutable public mirrorPosition;
    AllocationStore immutable public allocationStore;

    function getRuleList(
        bytes32 _matchingKey,
        address[] calldata _puppetList
    ) external view returns (Rule[] memory _ruleList) {
        uint _puppetListCount = _puppetList.length;
        _ruleList = new Rule[](_puppetListCount);

        for (uint i = 0; i < _puppetListCount; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchingRuleMap[_matchingKey][_puppet];
        }
    }

    constructor(
        IAuthority _authority,
        AllocationStore _store,
        MirrorPosition _mirrorPosition
    ) CoreContract(_authority) {
        allocationStore = _store;
        mirrorPosition = _mirrorPosition;
    }

    function deposit(IERC20 _collateralToken, address _user, uint _amount) external auth {
        require(_amount > 0, Error.MatchingRule__InvalidAmount());

        uint allowanceCap = tokenAllowanceCapMap[_collateralToken];
        require(allowanceCap > 0, Error.MatchingRule__TokenNotAllowed());

        uint nextBalance = allocationStore.userBalanceMap(_collateralToken, _user) + _amount;
        require(nextBalance <= allowanceCap, Error.MatchingRule__AllowanceAboveLimit(allowanceCap));

        allocationStore.transferIn(_collateralToken, _user, _amount);
        allocationStore.setUserBalance(_collateralToken, _user, nextBalance);

        _logEvent("Deposit", abi.encode(_collateralToken, _user, nextBalance, _amount));
    }

    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.MatchingRule__InvalidAmount());

        uint balance = allocationStore.userBalanceMap(_collateralToken, _user);

        require(_amount <= balance, Error.MatchingRule__InsufficientBalance());

        uint nextBalance = balance - _amount;

        allocationStore.setUserBalance(_collateralToken, _user, nextBalance);
        allocationStore.transferOut(_collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    function setRule(
        IERC20 _collateralToken,
        address _user,
        address _trader,
        Rule calldata _ruleParams
    ) external auth {
        require(
            _ruleParams.throttleActivity >= config.minActivityThrottle
                && _ruleParams.throttleActivity <= config.maxActivityThrottle,
            Error.MatchingRule__InvalidActivityThrottle(config.minActivityThrottle, config.maxActivityThrottle)
        );

        require(
            _ruleParams.expiry >= config.minExpiryDuration,
            Error.MatchingRule__InvalidExpiryDuration(config.minExpiryDuration)
        );

        require(
            _ruleParams.allowanceRate >= config.minAllowanceRate && _ruleParams.allowanceRate <= config.maxAllowanceRate,
            Error.MatchingRule__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate)
        );

        bytes32 _matchingKey = PositionUtils.getMatchingKey(_collateralToken, _trader);
        matchingRuleMap[_matchingKey][_user] = _ruleParams;
        mirrorPosition.initializeTraderActivityThrottle(_matchingKey, _user);

        _logEvent("SetMatchingRule", abi.encode(_collateralToken, _matchingKey, _user, _trader, _ruleParams));
    }

    /// @notice  Sets the configuration parameters via governance
    /// @param _data The encoded configuration data
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes calldata _data
    ) internal override {
        for (uint i; i < config.tokenAllowanceList.length; i++) {
            delete tokenAllowanceCapMap[config.tokenAllowanceList[i]];
        }

        config = abi.decode(_data, (Config));

        require(config.tokenAllowanceList.length == config.tokenAllowanceCapList.length, "Invalid token allowance list");
        require(config.tokenAllowanceList.length > 0, "Empty token allowance list");
        require(config.minExpiryDuration > 0, "Invalid min expiry duration");
        require(config.minAllowanceRate > 0, "Invalid min allowance rate");
        require(config.maxAllowanceRate > config.minAllowanceRate, "Invalid max allowance rate");
        require(config.minActivityThrottle > 0, "Invalid min activity throttle");
        require(config.maxActivityThrottle > config.minActivityThrottle, "Invalid max activity throttle");
    
        for (uint i; i < config.tokenAllowanceList.length; i++) {
            tokenAllowanceCapMap[config.tokenAllowanceList[i]] = config.tokenAllowanceCapList[i];
        }
    }
}
