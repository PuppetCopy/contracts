// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {RouterProxy} from "./RouterProxy.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/**
 * @title UserRouterProxy
 * @notice Upgradeable proxy for UserRouter - separate from MatchmakerRouter's proxy
 */
contract UserRouterProxy is RouterProxy {
    constructor(IAuthority _authority) RouterProxy(_authority) {}
}
