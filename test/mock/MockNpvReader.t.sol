// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {INpvReader} from "src/position/interface/INpvReader.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockNpvReader is INpvReader {
    mapping(bytes32 => int256) public positionValues;

    function setPositionValue(bytes32 _posKey, int256 _value) external {
        positionValues[_posKey] = _value;
    }

    function getPositionNetValue(bytes32 _positionKey) external view returns (int256) {
        return positionValues[_positionKey];
    }

    function parsePositionKey(address _account, bytes calldata) external pure returns (bytes32) {
        return keccak256(abi.encode(_account, "mock_position"));
    }
}

/// @dev Passthrough reader that returns bytes32(0) for all calls - used for whitelisting non-venue contracts like tokens
contract PassthroughReader is INpvReader {
    function getPositionNetValue(bytes32) external pure returns (int256) {
        return 0;
    }

    function parsePositionKey(address, bytes calldata) external pure returns (bytes32) {
        return bytes32(0);
    }
}

contract MockVenue {
    IERC20 public token;
    uint public amountToTake;

    function setToken(IERC20 _token) external {
        token = _token;
    }

    function setAmountToTake(uint _amount) external {
        amountToTake = _amount;
    }

    function openPosition() external {
        if (amountToTake > 0 && address(token) != address(0)) {
            token.transferFrom(msg.sender, address(this), amountToTake);
        }
    }

    function closePosition(address _to, uint _amount) external {
        token.transfer(_to, _amount);
    }
}
