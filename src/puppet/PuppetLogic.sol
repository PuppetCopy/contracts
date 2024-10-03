// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

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
        uint minRouteRate;
        uint maxRouteRate;
        uint minAllocationActivity;
        uint maxAllocationActivity;
        uint concurrentPositionLimit;
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

    function deposit(IERC20 token, address user, uint amount) external auth {
        if (amount == 0) revert Error.PuppetLogic__InvalidAmount();

        uint balance = store.increaseBalance(token, user, amount);

        logEvent("Deposit", abi.encode(token, user, balance));
    }

    function withdraw(IERC20 token, address user, address receiver, uint amount) external auth {
        if (amount == 0) revert Error.PuppetLogic__InvalidAmount();

        if (amount > store.getUserBalance(token, user)) revert Error.PuppetLogic__InsufficientBalance();

        uint balance = store.decreaseBalance(token, user, receiver, amount);

        logEvent("Withdraw", abi.encode(token, user, balance));
    }

    function setAllocationRule(
        IERC20 collateralToken,
        address puppet,
        PuppetStore.AllocationRule calldata ruleParams
    ) external auth {
        PuppetStore.AllocationRule memory rule = store.getAllocationRule(puppet);

        store.setAllocationRule(puppet, ruleParams);

        logEvent("SetAllocationRule", abi.encode(collateralToken, puppet, rule));
    }

    function setMatchRule(
        IERC20 collateralToken,
        address puppet,
        address trader,
        PuppetStore.MatchRule calldata ruleParams
    ) external auth {
        bytes32 matchKey = PositionUtils.getMatchKey(collateralToken, trader);
        _validatePuppetTokenAllowance(collateralToken, puppet);

        PuppetStore.MatchRule memory storedRule = store.getMatchRule(matchKey, puppet);
        PuppetStore.MatchRule memory rule = _setRouteRule(storedRule, ruleParams);

        store.setMatchRule(matchKey, puppet, rule);

        logEvent("SetMatchRule", abi.encode(matchKey, collateralToken, puppet, trader, rule));
    }

    function setMatchRuleList(
        IERC20[] calldata collateralTokenList,
        address puppet,
        address[] calldata traderList,
        PuppetStore.MatchRule[] calldata ruleParams
    ) external auth {
        IERC20[] memory verifyAllowanceTokenList = new IERC20[](0);
        uint length = traderList.length;
        bytes32[] memory matchKeyList = new bytes32[](length);
        for (uint i = 0; i < length; i++) {
            matchKeyList[i] = PositionUtils.getMatchKey(collateralTokenList[i], traderList[i]);
        }

        PuppetStore.MatchRule[] memory storedRuleList = store.getPuppetRouteRuleList(puppet, matchKeyList);

        for (uint i = 0; i < length; i++) {
            storedRuleList[i] = _setRouteRule(storedRuleList[i], ruleParams[i]);

            IERC20 collateralToken = collateralTokenList[i];

            if (isArrayContains(verifyAllowanceTokenList, collateralToken)) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralToken;
            }

            logEvent("SetMatchRuleList", abi.encode(matchKeyList[i], collateralToken, puppet, traderList, storedRuleList[i]));
        }

        _validatePuppetTokenAllowanceList(verifyAllowanceTokenList, puppet);

        store.setRouteRuleList(puppet, matchKeyList, storedRuleList);
    }

    function _setRouteRule(
        PuppetStore.MatchRule memory storedRule,
        PuppetStore.MatchRule calldata ruleParams
    ) internal view returns (PuppetStore.MatchRule memory) {
        if (ruleParams.allowanceRate < config.minRouteRate || ruleParams.allowanceRate > config.maxRouteRate) {
            revert Error.PuppetLogic__InvalidAllowanceRate(config.minRouteRate, config.maxRouteRate);
        }

        // storedRule.throttleActivity = ruleParams.throttleActivity;
        storedRule.allowanceRate = ruleParams.allowanceRate;

        return storedRule;
    }

    // internal

    function isArrayContains(IERC20[] memory array, IERC20 value) internal pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }

        return false;
    }

    function _validatePuppetTokenAllowanceList(IERC20[] memory tokenList, address puppet) internal view {
        for (uint i = 0; i < tokenList.length; i++) {
            _validatePuppetTokenAllowance(tokenList[i], puppet);
        }
    }

    function _validatePuppetTokenAllowance(IERC20 token, address puppet) internal view returns (uint) {
        uint tokenAllowance = store.getUserBalance(token, puppet);
        uint allowanceCap = store.getTokenAllowanceCap(token);

        if (allowanceCap == 0) revert Error.PuppetLogic__TokenNotAllowed();
        if (tokenAllowance > allowanceCap) revert Error.PuppetLogic__AllowanceAboveLimit(allowanceCap);

        return tokenAllowance;
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
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
