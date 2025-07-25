// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Mirror} from "./Mirror.sol";

contract Rule is CoreContract {
    struct RuleParams {
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

    Config config;

    mapping(bytes32 traderMatchingKey => mapping(address puppet => RuleParams)) public matchingRuleMap;

    constructor(
        IAuthority _authority,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getRuleList(
        bytes32 _traderMatchingKey,
        address[] calldata _puppetList
    ) external view returns (RuleParams[] memory _ruleList) {
        uint _puppetListCount = _puppetList.length;
        _ruleList = new RuleParams[](_puppetListCount);

        for (uint i = 0; i < _puppetListCount; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchingRuleMap[_traderMatchingKey][_puppet];
        }
    }

    function setRule(
        Mirror mirror,
        IERC20 _collateralToken,
        address _user,
        address _trader,
        RuleParams calldata _ruleParams
    ) external auth {
        require(
            _ruleParams.throttleActivity >= config.minActivityThrottle
                && _ruleParams.throttleActivity <= config.maxActivityThrottle,
            Error.Rule__InvalidActivityThrottle(config.minActivityThrottle, config.maxActivityThrottle)
        );

        require(
            _ruleParams.expiry >= config.minExpiryDuration,
            Error.Rule__InvalidExpiryDuration(config.minExpiryDuration)
        );

        require(
            _ruleParams.allowanceRate >= config.minAllowanceRate && _ruleParams.allowanceRate <= config.maxAllowanceRate,
            Error.Rule__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate)
        );

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        matchingRuleMap[_traderMatchingKey][_user] = _ruleParams;
        mirror.initializeTraderActivityThrottle(_traderMatchingKey, _user);

        _logEvent("SetMatchingRule", abi.encode(_collateralToken, _traderMatchingKey, _user, _trader, _ruleParams));
    }

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