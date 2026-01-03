// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IStage, Call} from "src/position/interface/IStage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallType} from "modulekit/accounts/common/lib/ModeLib.sol";

contract MockStage is IStage {
    mapping(bytes32 => uint) public positionValues;
    mapping(bytes32 => address) public positionOwners;
    mapping(bytes32 => bool) public pendingOrders;

    bool public shouldRevertValidation;
    string public revertReason;
    bytes32 public mockPositionKey;

    function setPositionValue(bytes32 _posKey, uint _value) external {
        positionValues[_posKey] = _value;
    }

    function setPositionOwner(bytes32 _posKey, address _owner) external {
        positionOwners[_posKey] = _owner;
    }

    function setOrderPending(bytes32 _orderKey, bool _pending) external {
        pendingOrders[_orderKey] = _pending;
    }

    function setMockPositionKey(bytes32 _posKey) external {
        mockPositionKey = _posKey;
    }

    function setShouldRevertValidation(bool _shouldRevert, string memory _reason) external {
        shouldRevertValidation = _shouldRevert;
        revertReason = _reason;
    }

    IERC20 public mockToken;

    function setMockToken(IERC20 _token) external {
        mockToken = _token;
    }

    function validate(address, address, uint, CallType, bytes calldata)
        external
        view
        override
        returns (IERC20 token, bytes memory hookData)
    {
        if (shouldRevertValidation) revert(revertReason);
        if (positionValues[mockPositionKey] == type(uint).max) revert("MockStage: validation failed");
        token = mockToken;
        hookData = abi.encode(mockPositionKey);
    }

    function verify(address, IERC20, uint, uint, bytes calldata) external pure override {}

    function getPositionValue(bytes32 _positionKey, IERC20) external view override returns (uint) {
        return positionValues[_positionKey];
    }

    function verifyPositionOwner(bytes32 _positionKey, address _subaccount) external view override returns (bool) {
        return positionOwners[_positionKey] == _subaccount;
    }

    function isOrderPending(bytes32 _orderKey, address) external view override returns (bool) {
        return pendingOrders[_orderKey];
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
