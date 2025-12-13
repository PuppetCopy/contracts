// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {RouterProxy} from "./RouterProxy.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/**
 * @title MatchmakerRouterProxy
 * @notice Upgradeable proxy for MatchmakerRouter - separate from UserRouter's proxy
 */
contract MatchmakerRouterProxy is RouterProxy {
    constructor(IAuthority _authority) RouterProxy(_authority) {}
}
