// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IVenueValidator} from "src/position/interface/IVenueValidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockVenueValidator is IVenueValidator {
    mapping(bytes32 => uint256) public positionValues;

    bool public shouldRevertValidation;
    string public revertReason;

    function setPositionValue(bytes32 _posKey, uint256 _value) external {
        positionValues[_posKey] = _value;
    }

    function setShouldRevertValidation(bool _shouldRevert, string memory _reason) external {
        shouldRevertValidation = _shouldRevert;
        revertReason = _reason;
    }

    function validatePreCallSingle(
        address _subaccount,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes memory) {
        if (shouldRevertValidation) revert(revertReason);
        bytes32 posKey = keccak256(abi.encode(_subaccount, "mock_position"));
        if (positionValues[posKey] == type(uint256).max) revert("MockVenueValidator: validation failed");
        return "";
    }

    function validatePreCallBatch(
        address _subaccount,
        Execution[] calldata
    ) external view override returns (bytes memory) {
        if (shouldRevertValidation) revert(revertReason);
        bytes32 posKey = keccak256(abi.encode(_subaccount, "mock_position"));
        if (positionValues[posKey] == type(uint256).max) revert("MockVenueValidator: validation failed");
        return "";
    }

    function processPostCall(
        address,
        bytes calldata
    ) external override {}

    function getPositionNetValue(bytes32 _positionKey) external view returns (uint256) {
        return positionValues[_positionKey];
    }

    function getPositionInfo(IERC7579Account _subaccount, bytes calldata) external view returns (PositionInfo memory _info) {
        _info.positionKey = keccak256(abi.encode(address(_subaccount), "mock_position"));
        _info.netValue = positionValues[_info.positionKey];
    }
}

/// @dev Passthrough validator that returns bytes32(0) for all calls - used for whitelisting non-venue contracts like tokens
contract PassthroughValidator is IVenueValidator {
    function validatePreCallSingle(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes memory) {
        return "";
    }

    function validatePreCallBatch(
        address,
        Execution[] calldata
    ) external pure override returns (bytes memory) {
        return "";
    }

    function processPostCall(
        address,
        bytes calldata
    ) external override {}

    function getPositionNetValue(bytes32) external pure returns (uint256) {
        return 0;
    }

    function getPositionInfo(IERC7579Account, bytes calldata) external pure returns (PositionInfo memory _info) {
        _info.positionKey = bytes32(0);
        _info.netValue = 0;
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
