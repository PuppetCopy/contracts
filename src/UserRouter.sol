// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

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
 * 3. Master (7579 account) calls allocate() via this router
 * 4. Allocation executes transfers from puppets → master
 * 5. Users can sync/withdraw through this router
 */
contract UserRouter {
    Allocation public immutable allocation;

    constructor(Allocation _allocation) {
        allocation = _allocation;
    }

    // ============ Allocation (Master) ============

    /**
     * @notice Master gathers allocations from puppets
     * @dev Allocation contract executes transfers from puppet accounts.
     *      Puppet policies validate each transfer.
     * @param _collateralToken The collateral token
     * @param _masterAllocation Master's own capital (skin in the game)
     * @param _puppetList List of puppet accounts to pull from
     * @param _allocationList Allocation amounts per puppet
     */
    function allocate(
        IERC20 _collateralToken,
        uint _masterAllocation,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external {
        allocation.allocate(
            _collateralToken,
            msg.sender,
            _masterAllocation,
            _puppetList,
            _allocationList
        );
    }

    // ============ Settlement Operations ============

    /**
     * @notice Sync pending settlements for caller's subaccount (lazy claim)
     * @param _collateralToken The collateral token
     * @param _master The master address
     */
    function syncAllocation(IERC20 _collateralToken, address _master) external {
        bytes32 _matchingKey = _getMatchingKey(_collateralToken, _master);
        allocation.withdraw(_collateralToken, _matchingKey, msg.sender, 0);
    }

    /**
     * @notice Withdraw allocation back to puppet's subaccount
     * @param _collateralToken The collateral token
     * @param _master The master address
     * @param _amount Amount to withdraw from allocation
     */
    function withdrawAllocation(IERC20 _collateralToken, address _master, uint _amount) external {
        bytes32 _matchingKey = _getMatchingKey(_collateralToken, _master);
        allocation.withdraw(_collateralToken, _matchingKey, msg.sender, _amount);
    }

    // ============ Internal ============

    function _getMatchingKey(IERC20 _collateralToken, address _master) internal pure returns (bytes32) {
        return keccak256(abi.encode(_collateralToken, _master));
    }
}
