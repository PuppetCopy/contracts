// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {RouterProxy} from "./RouterProxy.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/**
 * @title ProxyUserRouter
 * @notice Upgradeable proxy for UserRouter
 */
contract ProxyUserRouter is RouterProxy {
    constructor(IAuthority _authority) RouterProxy(_authority) {}
}
