// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {Access} from "./utils/auth/Access.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

/**
 * @title RouterProxy
 * @notice An upgradeable proxy that delegates calls to a replaceable Router
 *         contract (the implementation). This uses OpenZeppelin's ERC1967Upgrade
 *         to manage the implementation address.
 */
contract RouterProxy is Proxy, Access, Multicall {
    constructor(
        IAuthority _authority
    ) Access(_authority) {}

    function update(
        address _impl
    ) external auth {
        ERC1967Utils.upgradeToAndCall(_impl, "");
    }

    /**
     * @dev Returns the current implementation address.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }

    receive() external payable {}
}
