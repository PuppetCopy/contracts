// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Allocation} from "./position/Allocation.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

/**
 * @title UserRouter
 * @notice Aggregates user-facing operations for two-phase allocation
 *
 * Flow:
 * 1. Puppet installs Smart Sessions with Allocation as session owner
 * 2. Puppet configures policies (AllowedRecipient, AllowanceRate, Throttle)
 * 3. Master calls allocate() to stage funds from puppets
 * 4. Master calls utilize() to convert allocations to shares before trading
 * 5. Users can withdraw shares or idle allocations
 */
contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    /**
     * @notice Master stages funds from puppets (idle allocations)
     * @dev Funds are transferred but not yet utilized. No shares minted.
     * @param _collateralToken The collateral token
     * @param _puppetList List of puppet accounts to pull from
     * @param _amountList Allocation amounts per puppet
     */
    function allocate(
        IERC20 _collateralToken,
        address[] calldata _puppetList,
        uint[] calldata _amountList
    ) external {
        allocation.allocate(_collateralToken, msg.sender, _puppetList, _amountList);
    }

    /**
     * @notice Master converts allocations to shares (proportionally)
     * @dev Unused allocations are returned to puppets. Shares minted at current price.
     * @param _collateralToken The collateral token
     * @param _puppetList List of puppet accounts to process
     * @param _amountToUtilize Amount to utilize (must be <= totalAllocation)
     */
    function utilize(
        IERC20 _collateralToken,
        address[] calldata _puppetList,
        uint _amountToUtilize
    ) external {
        allocation.utilize(_collateralToken, msg.sender, _puppetList, _amountToUtilize);
    }

    /**
     * @notice Withdraw funds - first from idle allocations, then from shares
     * @dev Idle allocations are returned 1:1. Shares are burned at current share price.
     * @param _collateralToken The collateral token
     * @param _master The master address
     * @param _amount Amount of tokens to withdraw
     */
    function withdraw(IERC20 _collateralToken, address _master, uint _amount) external {
        bytes32 _matchingKey = _getMatchingKey(_collateralToken, _master);
        allocation.withdraw(_collateralToken, _matchingKey, msg.sender, _amount);
    }

    /**
     * @notice Get user's current value based on share price
     * @param _collateralToken The collateral token
     * @param _master The master address
     * @param _user The user to query
     */
    function getUserValue(IERC20 _collateralToken, address _master, address _user) external view returns (uint) {
        return allocation.getUserValue(_collateralToken, _master, _user);
    }

    function _getMatchingKey(IERC20 _collateralToken, address _master) internal pure returns (bytes32) {
        return keccak256(abi.encode(_collateralToken, _master));
    }
}
