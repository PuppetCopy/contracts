// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IStage} from "src/position/interface/IStage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStage is IStage {
    mapping(bytes32 => uint) public positionValues;

    bool public shouldRevertValidation;
    string public revertReason;

    function setPositionValue(bytes32 _posKey, uint _value) external {
        positionValues[_posKey] = _value;
    }

    function setShouldRevertValidation(bool _shouldRevert, string memory _reason) external {
        shouldRevertValidation = _shouldRevert;
        revertReason = _reason;
    }

    function open(address _subaccount, bytes calldata)
        external
        view
        override
        returns (bytes32 positionKey, bytes memory hookData)
    {
        if (shouldRevertValidation) revert(revertReason);
        positionKey = keccak256(abi.encode(_subaccount, "mock_position"));
        if (positionValues[positionKey] == type(uint).max) revert("MockStage: validation failed");
        hookData = "";
    }

    function close(address _subaccount, bytes calldata)
        external
        view
        override
        returns (bytes32 positionKey, bytes memory hookData)
    {
        if (shouldRevertValidation) revert(revertReason);
        positionKey = keccak256(abi.encode(_subaccount, "mock_position"));
        hookData = "";
    }

    function settle(address, bytes32, bytes calldata) external override {}

    function getValue(bytes32 _positionKey) external view override returns (uint) {
        return positionValues[_positionKey];
    }
}

contract MockVenue {
    IERC20 public token;
    uint public amountToTake;
    bool public shouldRevert;

    function setToken(IERC20 _token) external {
        token = _token;
    }

    function setAmountToTake(uint _amount) external {
        amountToTake = _amount;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function openPosition() external returns (bool) {
        if (shouldRevert) revert("MockVenue: forced revert");
        if (amountToTake > 0 && address(token) != address(0)) {
            token.transferFrom(msg.sender, address(this), amountToTake);
        }
        return true;
    }

    function closePosition(address _to, uint _amount) external {
        token.transfer(_to, _amount);
    }
}
