// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Allocation} from "./position/Allocation.sol";
import {IPuppetModule} from "./position/PuppetModule.sol";
import {IERC7579Account} from "./utils/interfaces/IERC7579Account.sol";

/**
 * @title UserRouter
 * @notice Aggregates user-facing operations for puppet subaccounts
 *
 * Puppets interact via their ERC-7579 subaccounts:
 * 1. Install PuppetModule on subaccount
 * 2. Call setPolicy() to follow traders
 * 3. Approve Allocation contract to pull funds
 * 4. Trader's client matches and calls allocate()
 */
contract UserRouter {
    Allocation public immutable allocation;
    IPuppetModule public immutable puppetModule;

    constructor(Allocation _allocation, IPuppetModule _puppetModule) {
        allocation = _allocation;
        puppetModule = _puppetModule;
    }

    // ============ Policy Management (Puppet Operations) ============

    /**
     * @notice Set policy to follow a trader
     * @dev Called by puppet's subaccount: puppetSubaccount.execute(userRouter, setPolicy(...))
     * @param _trader The trader to follow
     * @param _collateralToken The collateral token for matching
     * @param _data Encoded policy parameters (format defined by module)
     */
    function setPolicy(address _trader, IERC20 _collateralToken, bytes calldata _data) external {
        puppetModule.setPolicy(_trader, _collateralToken, _data);
    }

    /**
     * @notice Remove policy for a trader
     * @param _trader The trader to unfollow
     * @param _collateralToken The collateral token
     */
    function removePolicy(address _trader, IERC20 _collateralToken) external {
        puppetModule.removePolicy(_trader, _collateralToken);
    }

    // ============ Allocation Operations (Trader) ============

    /**
     * @notice Allocate capital from puppet subaccounts to trader's position
     * @dev Called by trader or authorized matchmaker
     * @param _collateralToken The collateral token
     * @param _traderSubaccount The trader's smart account (subaccount)
     * @param _traderAllocation Amount the trader is allocating from their own funds
     * @param _puppetSubaccountList List of puppet subaccount addresses
     * @param _puppetAllocationList Requested allocation amounts per puppet
     */
    function allocate(
        IERC20 _collateralToken,
        IERC7579Account _traderSubaccount,
        uint _traderAllocation,
        address[] calldata _puppetSubaccountList,
        uint[] calldata _puppetAllocationList
    ) external {
        allocation.allocate(
            _collateralToken,
            msg.sender,
            _traderSubaccount,
            _traderAllocation,
            _puppetSubaccountList,
            _puppetAllocationList,
            address(puppetModule)
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
     * @notice Realize pending settlements for caller's subaccount
     * @param _collateralToken The collateral token
     * @param _trader The trader address
     */
    function realize(IERC20 _collateralToken, address _trader) external {
        bytes32 _traderMatchingKey = _getTraderMatchingKey(_collateralToken, _trader);
        allocation.realize(_traderMatchingKey, msg.sender);
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
