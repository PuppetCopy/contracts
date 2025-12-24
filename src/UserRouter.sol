// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Allocation} from "./position/Allocation.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";

/**
 * @title UserRouter
 * @notice Aggregates user-facing operations for allocation
 *
 * Flow:
 * 1. Puppet installs Smart Sessions with Allocation as session owner
 * 2. Puppet configures policies (AllowedRecipient, AllowanceRate, Throttle)
 * 3. Trader (7579 account) calls allocate() via this router
 * 4. Allocation executes transfers from puppets → trader
 * 5. Users can sync/withdraw through this router
 */
contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    // ============ Allocation (Trader) ============

    /**
     * @notice Trader gathers allocations from puppets
     * @dev Allocation contract executes transfers from puppet accounts.
     *      Puppet policies validate each transfer.
     * @param _collateralToken The collateral token
     * @param _traderAllocation Trader's own allocation amount
     * @param _puppetList List of puppet accounts to pull from
     * @param _allocationList Allocation amounts per puppet
     */
    function allocate(
        IERC20 _collateralToken,
        uint _traderAllocation,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external {
        allocation.allocate(
            _collateralToken,
            msg.sender,
            _traderAllocation,
            _puppetList,
            _allocationList
        );
    }

    // ============ Settlement Operations ============

    /**
     * @notice Sync pending settlements for caller's subaccount (lazy claim)
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     */
    function syncAllocation(IERC20 _collateralToken, address _trader) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.withdraw(_collateralToken, _traderMatchingKey, msg.sender, 0);
    }

    /**
     * @notice Withdraw allocation back to puppet's subaccount
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     * @param _amount Amount to withdraw from allocation
     */
    function withdrawAllocation(IERC20 _collateralToken, address _trader, uint _amount) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.withdraw(_collateralToken, _traderMatchingKey, msg.sender, _amount);
    }

    // ============ Internal ============

    function _getTraderMatchingKey(IERC20 _collateralToken, address _trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(_collateralToken, _trader));
    }
}
