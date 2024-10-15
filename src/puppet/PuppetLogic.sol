// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetStore} from "./store/PuppetStore.sol";

contract PuppetLogic is CoreContract {
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

    PuppetStore immutable store;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _store
    ) CoreContract("PuppetLogic", "1", _authority, _eventEmitter) {
        store = _store;
    }

    function deposit(IERC20 collateralToken, address user, uint amount) external auth {
        if (amount == 0) revert Error.PuppetLogic__InvalidAmount();

        validatePuppetTokenAllowance(collateralToken, user, amount);

        uint balance = store.getUserBalance(collateralToken, user);
        uint nextBalance = balance + amount;

        store.transferIn(collateralToken, user, amount);
        store.setBalance(collateralToken, user, nextBalance);

        logEvent("Deposit", abi.encode(collateralToken, user, nextBalance, amount));
    }

    function withdraw(IERC20 collateralToken, address user, address receiver, uint amount) external auth {
        if (amount == 0) revert Error.PuppetLogic__InvalidAmount();
        uint balance = store.getUserBalance(collateralToken, user);

        if (amount > balance) revert Error.PuppetLogic__InsufficientBalance();
        uint nextBalance = balance - amount;

        store.setBalance(collateralToken, user, nextBalance);
        store.transferOut(collateralToken, receiver, amount);

        logEvent("Withdraw", abi.encode(collateralToken, user, nextBalance, amount));
    }

    function setMatchRule(
        IERC20 collateralToken,
        PuppetStore.MatchRule calldata ruleParams,
        address puppet,
        address trader
    ) external auth {
        bytes32 key = PositionUtils.getMatchKey(collateralToken, trader);
        _validateRuleParams(ruleParams);

        store.setMatchRule(key, puppet, ruleParams);

        logEvent("SetMatchRule", abi.encode(puppet, trader, key, ruleParams));
    }

    function setMatchRuleList(
        IERC20[] calldata collateralTokenList,
        address[] calldata traderList,
        PuppetStore.MatchRule[] calldata ruleParamList,
        address puppet
    ) external auth {
        uint length = traderList.length;
        if (length != ruleParamList.length) revert Error.PuppetLogic__InvalidLength();

        bytes32[] memory matchKeyList = new bytes32[](length);

        for (uint i = 0; i < length; i++) {
            PuppetStore.MatchRule memory rule = ruleParamList[i];
            IERC20 collateralToken = collateralTokenList[i];

            _validateRuleParams(rule);
            bytes32 key = PositionUtils.getMatchKey(collateralToken, traderList[i]);
            matchKeyList[i] = key;
        }

        store.setMatchRuleList(puppet, matchKeyList, ruleParamList);

        logEvent("SetMatchRuleList", abi.encode(puppet, traderList, matchKeyList, ruleParamList));
    }

    // internal

    function validatePuppetTokenAllowance(
        IERC20 token,
        address puppet,
        uint deltaAmount
    ) internal view returns (uint) {
        uint tokenAllowance = store.getUserBalance(token, puppet);
        uint allowanceCap = store.getTokenAllowanceCap(token);

        if (allowanceCap == 0) revert Error.PuppetLogic__TokenNotAllowed();
        if (tokenAllowance + deltaAmount > allowanceCap) revert Error.PuppetLogic__AllowanceAboveLimit(allowanceCap);

        return tokenAllowance;
    }

    function _validateRuleParams(
        PuppetStore.MatchRule memory ruleParams
    ) internal view {
        if (
            ruleParams.throttleActivity < config.minAllocationActivity
                || ruleParams.throttleActivity > config.maxAllocationActivity
        ) {
            revert Error.PuppetLogic__InvalidActivityThrottle(
                config.minAllocationActivity, config.maxAllocationActivity
            );
        }

        if (ruleParams.allowanceRate < config.minAllowanceRate || ruleParams.allowanceRate > config.maxAllowanceRate) {
            revert Error.PuppetLogic__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate);
        }
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(
        Config calldata _config
    ) external auth {
        if (_config.tokenAllowanceList.length != _config.tokenAllowanceAmountList.length) {
            revert Error.PuppetLogic__InvalidLength();
        }

        for (uint i; i < _config.tokenAllowanceList.length; i++) {
            store.setTokenAllowanceCap(_config.tokenAllowanceList[i], _config.tokenAllowanceAmountList[i]);
        }

        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
