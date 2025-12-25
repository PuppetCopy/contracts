// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";

/**
 * @title IPuppetPolicy
 * @notice Interface with PolicySet event for Puppet policy contracts
 */
interface IPuppetPolicy {
    /**
     * @notice Emitted when a policy is configured for an account
     * @param id The config ID for this policy instance
     * @param multiplexer The SmartSession address that called the policy
     * @param account The smart account the policy applies to
     */
    event PolicySet(ConfigId indexed id, address indexed multiplexer, address indexed account);
}
