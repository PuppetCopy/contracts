// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetStore} from "./store/PuppetStore.sol";

contract RulebookLogic is CoreContract {
    struct MatchRule {
        uint allowanceRate;
        uint throttleActivity;
        uint expiry;
    }

    struct Config {
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
        uint minAllocationActivity;
        uint maxAllocationActivity;
        IERC20[] tokenAllowanceList;
        uint[] tokenAllowanceAmountList;
    }

    Config public config;

    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(bytes32 matchKey => mapping(address puppet => MatchRule)) public matchRuleMap;

    PuppetStore immutable store;

    function getRuleList(
        bytes32 _matchKey,
        address[] calldata _puppetList
    ) external view returns (MatchRule[] memory _ruleList) {
        uint _puppetListCount = _puppetList.length;
        _ruleList = new MatchRule[](_puppetListCount);

        for (uint i = 0; i < _puppetListCount; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchRuleMap[_matchKey][_puppet];
        }
    }

    constructor(IAuthority _authority, PuppetStore _store) CoreContract("RulebookLogic", "1", _authority) {
        store = _store;
    }

    function deposit(IERC20 _collateralToken, address _user, uint amount) external auth {
        require(amount > 0, Error.RulebookLogic__InvalidAmount());

        uint allowanceCap = tokenAllowanceCapMap[_collateralToken];
        require(allowanceCap > 0, Error.RulebookLogic__TokenNotAllowed());

        uint nextBalance = store.userBalanceMap(_collateralToken, _user) + amount;
        require(nextBalance <= allowanceCap, Error.RulebookLogic__AllowanceAboveLimit(allowanceCap));

        store.transferIn(_collateralToken, _user, amount);
        store.setUserBalance(_collateralToken, _user, nextBalance);

        _logEvent("Deposit", abi.encode(_collateralToken, _user, nextBalance, amount));
    }

    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.RulebookLogic__InvalidAmount());

        uint balance = store.userBalanceMap(_collateralToken, _user);

        require(_amount <= balance, Error.RulebookLogic__InsufficientBalance());

        uint nextBalance = balance - _amount;

        store.setUserBalance(_collateralToken, _user, nextBalance);
        store.transferOut(_collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, nextBalance, _amount));
    }

    function setMatchRuleList(
        IERC20[] calldata _collateralTokenList,
        address[] calldata _traderList,
        MatchRule[] calldata _ruleParamList,
        address _puppet
    ) external auth {
        uint _traderListCount = _traderList.length;
        require(_traderListCount == _ruleParamList.length, Error.RulebookLogic__InvalidLength());

        bytes32[] memory _matchKeyList = new bytes32[](_traderListCount);

        for (uint i = 0; i < _traderListCount; i++) {
            MatchRule memory _ruleParams = _ruleParamList[i];
            IERC20 collateralToken = _collateralTokenList[i];

            require(
                _ruleParams.throttleActivity >= config.minAllocationActivity
                    && _ruleParams.throttleActivity <= config.maxAllocationActivity,
                Error.RulebookLogic__InvalidActivityThrottle(config.minAllocationActivity, config.maxAllocationActivity)
            );

            // require(
            //     _ruleParams.expiry >= config.minExpiryDuration,
            //     Error.RulebookLogic__InvalidExpiryDuration(config.minExpiryDuration)
            // );

            require(
                _ruleParams.allowanceRate >= config.minAllowanceRate
                    && _ruleParams.allowanceRate <= config.maxAllowanceRate,
                Error.RulebookLogic__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate)
            );

            bytes32 key = PositionUtils.getMatchKey(collateralToken, _traderList[i]);
            _matchKeyList[i] = key;
        }

        uint _keyListLength = _matchKeyList.length;
        require(_keyListLength == _ruleParamList.length, Error.Store__InvalidLength());

        for (uint i = 0; i < _keyListLength; i++) {
            bytes32 _key = _matchKeyList[i];
            matchRuleMap[_key][_puppet] = _ruleParamList[i];
            // // pre-store to save gas during inital allocation or-and reset throttle activity
            // if (activityThrottleMap[_key][_puppet] == 0) {
            //     activityThrottleMap[_key][_puppet] = 1;
            // }
        }

        _logEvent(
            "SetMatchRuleList", abi.encode(_collateralTokenList, _puppet, _traderList, _matchKeyList, _ruleParamList)
        );
    }

    // governance
    /// @notice  Sets the configuration parameters for the PuppetLogic contract.
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));

        require(
            config.tokenAllowanceList.length == config.tokenAllowanceAmountList.length,
            Error.RulebookLogic__InvalidLength()
        );

        for (uint i; i < config.tokenAllowanceList.length; i++) {
            tokenAllowanceCapMap[config.tokenAllowanceList[i]] = config.tokenAllowanceAmountList[i];
        }
    }
}
