// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {Account} from "./position/Account.sol";
import {Allocation} from "./position/Allocation.sol";
import {Subscribe} from "./position/Subscribe.sol";

/**
 * @title UserRouter
 * @notice Aggregates user-facing operations for Account, Subscribe, and Allocation
 * @dev Deployed as implementation behind UserRouterProxy
 */
contract UserRouter is Multicall {
    Account public immutable account;
    Subscribe public immutable subscribe;
    Allocation public immutable allocation;

    constructor(
        Account _account,
        Subscribe _subscribe,
        Allocation _allocation
    ) {
        account = _account;
        subscribe = _subscribe;
        allocation = _allocation;
    }

    // ============ Account Operations ============

    /**
     * @notice Deposit collateral tokens into user's account
     * @param _collateralToken The token to deposit
     * @param _amount Amount to deposit
     */
    function deposit(IERC20 _collateralToken, uint _amount) external {
        account.deposit(_collateralToken, msg.sender, msg.sender, _amount);
    }

    /**
     * @notice Deposit collateral tokens on behalf of another user
     * @param _collateralToken The token to deposit
     * @param _user The user to credit
     * @param _amount Amount to deposit
     */
    function depositFor(IERC20 _collateralToken, address _user, uint _amount) external {
        account.deposit(_collateralToken, msg.sender, _user, _amount);
    }

    /**
     * @notice Withdraw collateral tokens from user's account
     * @param _collateralToken The token to withdraw
     * @param _receiver Address to receive tokens
     * @param _amount Amount to withdraw
     */
    function withdraw(IERC20 _collateralToken, address _receiver, uint _amount) external {
        account.withdraw(_collateralToken, msg.sender, _receiver, _amount);
    }

    // ============ Subscribe Operations ============

    /**
     * @notice Set subscription rule to follow a trader
     * @param _collateralToken The collateral token for matching
     * @param _trader The trader to follow
     * @param _ruleParams Subscription parameters (allowanceRate, throttleActivity, expiry)
     */
    function rule(
        IERC20 _collateralToken,
        address _trader,
        Subscribe.RuleParams calldata _ruleParams
    ) external {
        subscribe.rule(allocation, _collateralToken, msg.sender, _trader, _ruleParams);
    }

    // ============ Allocation Operations (Trader) ============

    /**
     * @notice Allocate capital with puppets for trading
     * @param _collateralToken The collateral token
     * @param _subaccount The trader's smart account (subaccount)
     * @param _traderAllocation Amount the trader is allocating
     * @param _puppetList List of puppets to include
     */
    function allocate(
        IERC20 _collateralToken,
        address _subaccount,
        uint _traderAllocation,
        address[] calldata _puppetList
    ) external {
        allocation.allocate(
            account,
            subscribe,
            _collateralToken,
            msg.sender,
            _subaccount,
            _traderAllocation,
            _puppetList
        );
    }

    /**
     * @notice Trigger settlement for a trader matching key
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     */
    function settle(IERC20 _collateralToken, address _trader) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.settle(_traderMatchingKey, _collateralToken);
    }

    /**
     * @notice Realize pending settlements for user
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     */
    function realize(IERC20 _collateralToken, address _trader) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.realize(_traderMatchingKey, msg.sender);
    }

    /**
     * @notice Withdraw from allocation back to account balance
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     * @param _amount Amount to withdraw from allocation
     */
    function withdrawAllocation(IERC20 _collateralToken, address _trader, uint _amount) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.withdraw(account, _collateralToken, _traderMatchingKey, msg.sender, _amount);
    }

    // ============ Internal ============

    function _getTraderMatchingKey(IERC20 _collateralToken, address _trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(_collateralToken, _trader));
    }
}
