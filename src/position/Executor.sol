// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IExecutor, MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, ModePayload, CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {IVenueValidator} from "./interface/IVenueValidator.sol";
import {Position} from "./Position.sol";
import {Allocation} from "./Allocation.sol";

contract Executor is CoreContract, IExecutor, EIP712 {
    struct Config {
        Allocation allocation;
        Position position;
        uint callGasLimit;
    }

    struct Intent {
        Allocation.IntentType intentType;
        address account;
        IERC7579Account subaccount;
        IERC20 token;
        uint256 amount;
        uint256 acceptableNetValue;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 public constant INTENT_TYPEHASH = keccak256(
        "Intent(uint8 intentType,address account,address subaccount,address token,uint256 amount,uint256 acceptableNetValue,uint256 deadline,uint256 nonce)"
    );

    Config public config;

    mapping(address account => uint256) public nonceMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Executor", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    // ============================================================
    // Execute Order
    // ============================================================

    function executeOrder(
        Intent calldata _intent,
        bytes calldata _signature,
        address _target,
        bytes calldata _callData
    ) external auth {
        _verifyIntent(_intent, _signature, Allocation.IntentType.Order);

        bytes32 _key = PositionUtils.getMatchingKey(_intent.token, _intent.subaccount);
        if (address(config.allocation.masterSubaccountMap(_key)) == address(0)) {
            revert Error.Executor__UnregisteredSubaccount();
        }

        (uint256 _allocation, uint256 _positionValue, uint256 _netValue, Position.PositionInfo[] memory _positions) =
            config.position.calcNetPositionsValue(_intent.subaccount, _intent.token, _key);

        if (_intent.acceptableNetValue > 0 && _netValue < _intent.acceptableNetValue) {
            revert Error.Executor__NetValueBelowAcceptable(_netValue, _intent.acceptableNetValue);
        }

        Position.Venue memory _venue = config.position.getVenue(_target);
        if (address(_venue.validator) == address(0)) {
            revert Error.Executor__TargetNotWhitelisted(_target);
        }

        _venue.validator.validate(_intent.subaccount, _intent.token, _intent.amount, _callData);

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _intent.subaccount,
            _target,
            config.callGasLimit,
            _callData
        );

        IVenueValidator.PositionInfo memory _posInfo = _venue.validator.getPositionInfo(_intent.subaccount, _callData);

        config.position.updatePosition(_key, _posInfo.positionKey, _venue, _posInfo.netValue);

        _logEvent("ExecuteOrder", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptableNetValue,
            _target,
            _callData,
            _posInfo.positionKey,
            _posInfo.netValue,
            _allocation,
            _positionValue,
            _positions,
            _result,
            _error
        ));
    }

    // ============================================================
    // Intent Verification
    // ============================================================

    function _verifyIntent(Intent calldata _intent, bytes calldata _signature, Allocation.IntentType _expectedType) internal {
        if (_intent.intentType != _expectedType) revert Error.Executor__InvalidIntentType();
        if (block.timestamp > _intent.deadline) revert Error.Executor__IntentExpired(_intent.deadline, block.timestamp);

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            INTENT_TYPEHASH,
            uint8(_intent.intentType),
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptableNetValue,
            _intent.deadline,
            _intent.nonce
        )));

        address _signer = ECDSA.recover(_hash, _signature);
        address _sessionSigner = config.allocation.sessionSignerMap(_intent.account);

        if (_signer != _intent.account && _signer != _sessionSigner) {
            revert Error.Executor__InvalidSignature(_intent.account, _signer);
        }

        if (!_intent.subaccount.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
            revert Error.Executor__ModuleNotInstalled();
        }

        uint256 _expectedNonce = nonceMap[_intent.account]++;
        if (_expectedNonce != _intent.nonce) revert Error.Executor__InvalidNonce(_expectedNonce, _intent.nonce);
    }

    // ============================================================
    // Module Execution
    // ============================================================

    function _executeFromExecutor(
        IERC7579Account _from,
        address _to,
        uint _gas,
        bytes memory _data
    ) internal returns (bytes memory _result, bytes memory _error) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gas}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            _result = _results[0];
        } catch (bytes memory _reason) {
            _error = _reason;
        }
    }

    // ============================================================
    // IExecutor Module Implementation
    // ============================================================

    function isModuleType(uint256 _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address _subaccount) external view returns (bool) {
        return IERC7579Account(_subaccount).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "");
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external {}

    // ============================================================
    // Config
    // ============================================================

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (address(_config.allocation) == address(0)) revert Error.Executor__InvalidAllocation();
        if (address(_config.position) == address(0)) revert Error.Executor__InvalidPosition();
        if (_config.callGasLimit == 0) revert Error.Executor__InvalidCallGasLimit();
        config = _config;
    }
}
