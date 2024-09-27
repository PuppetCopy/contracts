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
        uint minAllowanceRate;
        uint maxAllowanceRate;
        IERC20[] tokenAllowanceList;
        uint[] tokenAllowanceAmountList;
    }

    Config public config;
    PuppetStore store;

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
        address trader,
        PuppetStore.RouteAllocationRule calldata ruleParams
    ) external auth {
        bytes32 routeKey = PositionUtils.getRouteKey(collateralToken, trader);
        _validatePuppetTokenAllowance(collateralToken, puppet);

        PuppetStore.RouteAllocationRule memory storedRule = store.getAllocationRule(routeKey, puppet);
        PuppetStore.RouteAllocationRule memory rule = _setRule(storedRule, ruleParams);

        store.setRouteAllocationRule(routeKey, puppet, rule);

        logEvent("SetRule", abi.encode(routeKey, collateralToken, puppet, trader, rule));
    }

    function setAllocationRuleList(
        IERC20[] calldata collateralTokenList,
        address puppet,
        address[] calldata traderList,
        PuppetStore.RouteAllocationRule[] calldata ruleParams
    ) external auth {
        IERC20[] memory verifyAllowanceTokenList = new IERC20[](0);
        uint length = traderList.length;
        bytes32[] memory keyList = new bytes32[](length);

        for (uint i = 0; i < length; i++) {
            keyList[i] = PositionUtils.getRouteKey(collateralTokenList[i], traderList[i]);
        }

        PuppetStore.RouteAllocationRule[] memory storedRuleList = store.getPuppetAllocationRuleList(puppet, keyList);

        for (uint i = 0; i < length; i++) {
            storedRuleList[i] = _setRule(storedRuleList[i], ruleParams[i]);

            IERC20 collateralToken = collateralTokenList[i];

            if (isArrayContains(verifyAllowanceTokenList, collateralToken)) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralToken;
            }

            logEvent("SetRuleList", abi.encode(keyList[i], collateralToken, puppet, traderList, storedRuleList[i]));
        }

        _validatePuppetTokenAllowanceList(verifyAllowanceTokenList, puppet);

        store.setRouteAllocationRuleList(puppet, keyList, storedRuleList);
    }

    function _setRule(
        PuppetStore.RouteAllocationRule memory storedRule,
        PuppetStore.RouteAllocationRule calldata ruleParams
    ) internal view returns (PuppetStore.RouteAllocationRule memory) {
        if (ruleParams.expiry == 0) {
            if (storedRule.expiry == 0) revert Error.PuppetLogic__NotFound();

            storedRule.expiry = 0;

            return storedRule;
        }

        if (ruleParams.expiry < block.timestamp + config.minExpiryDuration) {
            revert Error.PuppetLogic__ExpiredDate();
        }

        if (ruleParams.allowanceRate < config.minAllowanceRate || ruleParams.allowanceRate > config.maxAllowanceRate) {
            revert Error.PuppetLogic__InvalidAllowanceRate(config.minAllowanceRate, config.maxAllowanceRate);
        }

        storedRule.throttleActivity = ruleParams.throttleActivity;
        storedRule.allowanceRate = ruleParams.allowanceRate;
        storedRule.expiry = ruleParams.expiry;

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
