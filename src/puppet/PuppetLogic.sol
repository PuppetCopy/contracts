// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {PuppetStore} from "./store/PuppetStore.sol";

contract PuppetLogic is CoreContract {
    struct Config {
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    Config config;
    PuppetStore store;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _store,
        Config memory _config
    ) CoreContract("PuppetLogic", "1", _authority, _eventEmitter) {
        store = _store;

        _setConfig(_config);
    }

    function deposit(IERC20 token, address user, uint amount) external auth {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        uint balance = store.increaseBalance(token, user, amount);

        logEvent("deposit()", abi.encode(token, user, balance));
    }

    function withdraw(IERC20 token, address user, address receiver, uint amount) external auth {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        if (amount > store.getBalance(token, user)) revert PuppetLogic__InsufficientBalance();

        uint balance = store.decreaseBalance(token, user, receiver, amount);

        logEvent("withdraw()", abi.encode(token, user, balance));
    }

    function setRule(
        IERC20 collateralToken,
        address puppet,
        address trader,
        PuppetStore.Rule calldata ruleParams
    ) external auth {
        bytes32 ruleKey = PositionUtils.getRuleKey(collateralToken, puppet, trader);
        _validatePuppetTokenAllowance(collateralToken, puppet);

        PuppetStore.Rule memory storedRule = store.getRule(ruleKey);
        PuppetStore.Rule memory rule = _setRule(storedRule, ruleParams);

        store.setRule(ruleKey, rule);

        logEvent("setRule()", abi.encode(ruleKey, rule));
    }

    function setRuleList(
        address puppet,
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList,
        PuppetStore.Rule[] calldata ruleParams
    ) external auth {
        IERC20[] memory verifyAllowanceTokenList = new IERC20[](0);
        uint length = traderList.length;
        bytes32[] memory keyList = new bytes32[](length);

        for (uint i = 0; i < length; i++) {
            keyList[i] = PositionUtils.getRuleKey(collateralTokenList[i], puppet, traderList[i]);
        }

        PuppetStore.Rule[] memory storedRuleList = store.getRuleList(keyList);

        for (uint i = 0; i < length; i++) {
            storedRuleList[i] = _setRule(storedRuleList[i], ruleParams[i]);

            if (isArrayContains(verifyAllowanceTokenList, collateralTokenList[i])) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralTokenList[i];
            }

            logEvent("setRuleList()", abi.encode(keyList[i], storedRuleList[i]));
        }

        store.setRuleList(keyList, storedRuleList);

        _validatePuppetTokenAllowanceList(verifyAllowanceTokenList, puppet);
    }

    function _setRule(
        PuppetStore.Rule memory storedRule,
        PuppetStore.Rule calldata ruleParams
    ) internal view returns (PuppetStore.Rule memory) {
        if (ruleParams.expiry == 0) {
            if (storedRule.expiry == 0) revert PuppetLogic__NotFound();

            storedRule.expiry = 0;

            return storedRule;
        }

        if (ruleParams.expiry < block.timestamp + config.minExpiryDuration) {
            revert PuppetLogic__ExpiredDate();
        }

        if (ruleParams.allowanceRate < config.minAllowanceRate || ruleParams.allowanceRate > config.maxAllowanceRate) {
            revert PuppetLogic__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate);
        }

        storedRule.throttleActivity = ruleParams.throttleActivity;
        storedRule.allowanceRate = ruleParams.allowanceRate;
        storedRule.expiry = ruleParams.expiry;

        return storedRule;
    }

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
        uint tokenAllowance = store.getBalance(token, puppet);
        uint allowanceCap = store.getTokenAllowanceCap(token);

        if (allowanceCap == 0) revert PuppetLogic__TokenNotAllowed();
        if (tokenAllowance > allowanceCap) revert PuppetLogic__AllowanceAboveLimit(allowanceCap);

        return tokenAllowance;
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NotFound();
    error PuppetLogic__TokenNotAllowed();
    error PuppetLogic__AllowanceAboveLimit(uint allowanceCap);
    error PuppetLogic__InvalidAmount();
    error PuppetLogic__InsufficientBalance();
}
