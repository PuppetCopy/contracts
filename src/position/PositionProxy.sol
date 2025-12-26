// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PositionProxy
 * @notice Minimal proxy for isolated position funds
 * @dev Address is deterministic via CREATE2 - no storage needed
 */
contract PositionProxy {
    address immutable _owner;

    constructor() {
        _owner = msg.sender;
    }

    function transfer(IERC20 _token, address _to, uint256 _amount) external {
        require(msg.sender == _owner);
        _token.transfer(_to, _amount);
    }

    receive() external payable {}
}

/**
 * @title PositionProxyFactory
 * @notice Factory for deterministic position proxy deployment
 */
library PositionProxyFactory {
    bytes32 constant BYTECODE_HASH = keccak256(type(PositionProxy).creationCode);

    function computeAddress(bytes32 _salt) internal view returns (address) {
        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, BYTECODE_HASH)
        ))));
    }

    function getOrCreate(bytes32 _salt) internal returns (address proxy) {
        proxy = computeAddress(_salt);
        if (proxy.code.length == 0) {
            proxy = address(new PositionProxy{salt: _salt}());
        }
    }
}
