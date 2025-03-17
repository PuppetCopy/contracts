// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {Error} from "../shared/Error.sol";
import {SubaccountStore} from "../shared/SubaccountStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

contract MatchRule is CoreContract {
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
        IERC20[] tokenAllowanceList;
        uint[] tokenAllowanceAmountList;
    }

    Config public config;

    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(bytes32 matchKey => mapping(address puppet => Rule)) public matchRuleMap;

    SubaccountStore immutable subaccountStore;

    function getRuleList(
        bytes32 _matchKey,
        address[] calldata _puppetList
    ) external view returns (Rule[] memory _ruleList) {
        uint _puppetListCount = _puppetList.length;
        _ruleList = new Rule[](_puppetListCount);

        for (uint i = 0; i < _puppetListCount; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchRuleMap[_matchKey][_puppet];
        }
    }

    constructor(IAuthority _authority, SubaccountStore _store) CoreContract("MatchRule", _authority) {
        subaccountStore = _store;
    }

    function deposit(IERC20 _collateralToken, address _user, uint _amount) external auth {
        require(_amount > 0, Error.MatchRule__InvalidAmount());

        uint allowanceCap = tokenAllowanceCapMap[_collateralToken];
        require(allowanceCap > 0, Error.MatchRule__TokenNotAllowed());

        uint nextBalance = subaccountStore.userBalanceMap(_collateralToken, _user) + _amount;
        require(nextBalance <= allowanceCap, Error.MatchRule__AllowanceAboveLimit(allowanceCap));

        subaccountStore.transferIn(_collateralToken, _user, _amount);
        subaccountStore.setUserBalance(_collateralToken, _user, nextBalance);

        _logEvent("Deposit", abi.encode(_collateralToken, _user, nextBalance, _amount));
    }

    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.MatchRule__InvalidAmount());

        uint balance = subaccountStore.userBalanceMap(_collateralToken, _user);

        require(_amount <= balance, Error.MatchRule__InsufficientBalance());

        uint nextBalance = balance - _amount;

        subaccountStore.setUserBalance(_collateralToken, _user, nextBalance);
        subaccountStore.transferOut(_collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, nextBalance, _amount));
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
            Error.MatchRule__InvalidActivityThrottle(config.minActivityThrottle, config.maxActivityThrottle)
        );

        require(
            _ruleParams.expiry >= config.minExpiryDuration,
            Error.MatchRule__InvalidExpiryDuration(config.minExpiryDuration)
        );

        require(
            _ruleParams.allowanceRate >= config.minAllowanceRate && _ruleParams.allowanceRate <= config.maxAllowanceRate,
            Error.MatchRule__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate)
        );

        bytes32 _matchKey = PositionUtils.getMatchKey(_collateralToken, _trader);
        matchRuleMap[_matchKey][_user] = _ruleParams;

        _logEvent("SetMatchRule", abi.encode(_collateralToken, _matchKey, _user, _trader, _ruleParams));
    }

    // governance
    /// @notice  Sets the configuration parameters for the PuppetLogic contract.
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes calldata _data
    ) internal override {
        config = abi.decode(_data, (Config));

        require(
            config.tokenAllowanceList.length == config.tokenAllowanceAmountList.length, Error.MatchRule__InvalidLength()
        );

        for (uint i; i < config.tokenAllowanceList.length; i++) {
            tokenAllowanceCapMap[config.tokenAllowanceList[i]] = config.tokenAllowanceAmountList[i];
        }
    }
}
