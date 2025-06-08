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
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
        uint minActivityThrottle;
        uint maxActivityThrottle;
    }

    AllocationStore public immutable store;

    Config public config;
    IERC20[] public tokenAllowanceList;

    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => Rule)) public matchingRuleMap;

    function getRuleList(
        bytes32 _traderMatchingKey,
        address[] calldata _puppetList
    ) external view returns (Rule[] memory _ruleList) {
        uint _puppetListCount = _puppetList.length;
        _ruleList = new Rule[](_puppetListCount);

        for (uint i = 0; i < _puppetListCount; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchingRuleMap[_traderMatchingKey][_puppet];
        }
    }

    constructor(IAuthority _authority, AllocationStore _store, Config memory _config) CoreContract(_authority) {
        store = _store;

        _setConfig(abi.encode(_config));
    }

    function deposit(IERC20 _collateralToken, address _depositor, address _user, uint _amount) external auth {
        require(_amount > 0, Error.MatchingRule__InvalidAmount());

        uint allowanceCap = tokenAllowanceCapMap[_collateralToken];
        require(allowanceCap > 0, Error.MatchingRule__TokenNotAllowed());

        uint nextBalance = store.userBalanceMap(_collateralToken, _user) + _amount;
        require(nextBalance <= allowanceCap, Error.MatchingRule__AllowanceAboveLimit(allowanceCap));

        store.transferIn(_collateralToken, _depositor, _amount);
        store.setUserBalance(_collateralToken, _user, nextBalance);

        _logEvent("Deposit", abi.encode(_collateralToken, _depositor, _user, nextBalance, _amount));
    }

    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.MatchingRule__InvalidAmount());

        uint balance = store.userBalanceMap(_collateralToken, _user);

        require(_amount <= balance, Error.MatchingRule__InsufficientBalance());

        uint nextBalance = balance - _amount;

        store.setUserBalance(_collateralToken, _user, nextBalance);
        store.transferOut(_collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    function setRule(
        MirrorPosition mirrorPosition,
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

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        matchingRuleMap[_traderMatchingKey][_user] = _ruleParams;
        mirrorPosition.initializeTraderActivityThrottle(_traderMatchingKey, _user);

        _logEvent("SetMatchingRule", abi.encode(_collateralToken, _traderMatchingKey, _user, _trader, _ruleParams));
    }

    function setTokenAllowanceList(
        IERC20[] calldata _tokenAllowanceList,
        uint[] calldata _tokenDustThresholdCapList
    ) external auth {
        require(_tokenAllowanceList.length == _tokenDustThresholdCapList.length, "Invalid token dust threshold list");

        for (uint i = 0; i < tokenAllowanceList.length; i++) {
            delete tokenAllowanceCapMap[tokenAllowanceList[i]];
        }

        for (uint i = 0; i < _tokenAllowanceList.length; i++) {
            IERC20 _token = _tokenAllowanceList[i];
            uint _cap = _tokenDustThresholdCapList[i];

            require(_cap > 0, "Invalid token allowance cap");
            require(address(_token) != address(0), "Invalid token address");

            tokenAllowanceCapMap[_token] = _cap;
        }

        tokenAllowanceList = _tokenAllowanceList;
    }

    /// @notice  Sets the configuration parameters via governance
    /// @param _data The encoded configuration data
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes memory _data
    ) internal override {
        config = abi.decode(_data, (Config));

        require(config.minExpiryDuration > 0, "Invalid min expiry duration");
        require(config.minAllowanceRate > 0, "Invalid min allowance rate");
        require(config.maxAllowanceRate > config.minAllowanceRate, "Invalid max allowance rate");
        require(config.minActivityThrottle > 0, "Invalid min activity throttle");
        require(config.maxActivityThrottle > config.minActivityThrottle, "Invalid max activity throttle");
    }
}
