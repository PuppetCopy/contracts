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
import {Precision} from "../utils/Precision.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {INpvReader} from "./interface/INpvReader.sol";

contract Shares is CoreContract, IExecutor, EIP712 {
    enum IntentType { MasterDeposit, Allocate, Withdraw, Trade }

    struct Config {
        INpvReader npvReader;
        uint maxPuppetList;
        uint transferGasLimit;
        uint callGasLimit;
        uint virtualShareOffset;
    }

    struct CallIntent {
        IntentType intentType;
        address user;
        address master;
        address token;
        uint256 amount;
        uint256 acceptablePrice;
        uint256 deadline;
        uint256 nonce;
    }

    struct CallAllocateParams {
        address[] puppetList;
        uint256[] amountList;
    }

    struct CallPosition {
        address master;
        address target;
        bytes callData;
        uint256 deadline;
        uint256 nonce;
    }

    struct AssetsInfo {
        uint idleBalance;
        uint positionValue;
        uint total;
    }

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(uint8 intentType,address user,address master,address token,uint256 amount,uint256 acceptablePrice,uint256 deadline,uint256 nonce)"
    );

    bytes32 public constant CALL_POSITION_TYPEHASH = keccak256(
        "CallPosition(address master,address target,bytes callData,uint256 deadline,uint256 nonce)"
    );

    Config public config;
    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => mapping(address => uint)) public userShares;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;
    mapping(bytes32 => bytes32[]) public positionKeys;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Shares", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(bytes32 _key, uint _totalAssets) public view returns (uint) {
        uint _assets = _totalAssets + config.virtualShareOffset;
        uint _shares = totalShares[_key] + config.virtualShareOffset;
        return Precision.toFactor(_assets, _shares);
    }

    function getUserShares(IERC20 _token, address _master, address _user) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _master);
        return userShares[_key][_user];
    }

    function getUserNpv(IERC20 _token, address _master, address _user) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _master);
        uint _shares = userShares[_key][_user];
        if (_shares == 0) return 0;

        AssetsInfo memory _assets = calcNetPositionsValue(_key, address(_token));
        uint _sharePrice = getSharePrice(_key, _assets.total);
        return Precision.applyFactor(_sharePrice, _shares);
    }

    function getPositionKeys(bytes32 _key) external view returns (bytes32[] memory) {
        return positionKeys[_key];
    }

    function addPositionKey(bytes32 _key, bytes32 _positionKey) external auth {
        positionKeys[_key].push(_positionKey);
    }

    function removePositionKey(bytes32 _key, bytes32 _positionKey) external auth {
        bytes32[] storage _keys = positionKeys[_key];
        for (uint _i = 0; _i < _keys.length; ++_i) {
            if (_keys[_i] == _positionKey) {
                _keys[_i] = _keys[_keys.length - 1];
                _keys.pop();
                return;
            }
        }
    }

    function masterDeposit(
        CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        if (_intent.intentType != IntentType.MasterDeposit) revert Error.Allocation__InvalidCallType();
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);
        _verifyIntent(_intent, _signature);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.master);
        AssetsInfo memory _assets = calcNetPositionsValue(_key, _intent.token);

        if (_intent.user != _intent.master) revert Error.Allocation__InvalidSignature(_intent.master, _intent.user);

        if (address(subaccountMap[_key]) == address(0)) {
            IERC7579Account _master = IERC7579Account(_intent.master);
            if (!_master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
                revert Error.Allocation__UnregisteredSubaccount();
            }
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(IERC20(_intent.token));
        }

        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice > _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooHigh(_sharePrice, _intent.acceptablePrice);
        }

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            IERC7579Account(_intent.master),
            _intent.token,
            config.callGasLimit,
            abi.encodeCall(IERC20.transfer, (address(subaccountMap[_key]), _intent.amount))
        );

        if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        uint _sharesOut = Precision.toFactor(_intent.amount, _sharePrice);
        userShares[_key][_intent.master] += _sharesOut;
        totalShares[_key] += _sharesOut;

        _logEvent("MasterDeposit", abi.encode(
            _key,
            _intent.token,
            _intent.master,
            _intent.amount,
            _sharesOut,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key]
        ));
    }

    function allocate(
        CallIntent calldata _intent,
        bytes calldata _signature,
        CallAllocateParams calldata _params
    ) external auth {
        if (_intent.intentType != IntentType.Allocate) revert Error.Allocation__InvalidCallType();
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);
        _verifyIntent(_intent, _signature);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.master);
        AssetsInfo memory _assets = calcNetPositionsValue(_key, _intent.token);

        if (_intent.user != _intent.master) revert Error.Allocation__InvalidSignature(_intent.master, _intent.user);
        if (address(subaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();
        if (_params.puppetList.length != _params.amountList.length) {
            revert Error.Allocation__ArrayLengthMismatch(_params.puppetList.length, _params.amountList.length);
        }
        if (_params.puppetList.length > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_params.puppetList.length, config.maxPuppetList);
        }

        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice > _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooHigh(_sharePrice, _intent.acceptablePrice);
        }

        uint _totalAllocated = 0;

        for (uint _i = 0; _i < _params.puppetList.length; ++_i) {
            address _puppet = _params.puppetList[_i];
            uint _amount = _params.amountList[_i];

            (bytes memory _result, bytes memory _error) = _executeFromExecutor(
                IERC7579Account(_puppet),
                _intent.token,
                config.callGasLimit,
                abi.encodeCall(IERC20.transfer, (address(subaccountMap[_key]), _amount))
            );

            if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) {
                _logEvent("AllocateFailed", abi.encode(_key, _puppet, _amount, _error));
                continue;
            }

            uint _sharesOut = Precision.toFactor(_amount, _sharePrice);
            userShares[_key][_puppet] += _sharesOut;
            totalShares[_key] += _sharesOut;
            _totalAllocated += _amount;
        }

        _logEvent("Allocate", abi.encode(
            _key,
            _intent.token,
            _intent.master,
            _params.puppetList,
            _params.amountList,
            _totalAllocated,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key]
        ));
    }

    function withdraw(
        CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        if (_intent.intentType != IntentType.Withdraw) revert Error.Allocation__InvalidCallType();
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);
        _verifyIntent(_intent, _signature);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.master);
        AssetsInfo memory _assets = calcNetPositionsValue(_key, _intent.token);

        uint _userBalance = userShares[_key][_intent.user];
        if (_intent.amount > _userBalance) revert Error.Allocation__InsufficientBalance(_userBalance, _intent.amount);

        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice < _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooLow(_sharePrice, _intent.acceptablePrice);
        }

        uint _amountOut = Precision.applyFactor(_sharePrice, _intent.amount);

        if (_amountOut > _assets.idleBalance) revert Error.Allocation__InsufficientBalance(_assets.idleBalance, _amountOut);

        userShares[_key][_intent.user] -= _intent.amount;
        totalShares[_key] -= _intent.amount;

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            subaccountMap[_key],
            _intent.token,
            config.transferGasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.user, _amountOut))
        );

        if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        _logEvent("Withdraw", abi.encode(
            _key,
            _intent.token,
            _intent.master,
            _intent.user,
            _intent.amount,
            _amountOut,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key],
            userShares[_key][_intent.user]
        ));
    }

    function callPosition(
        CallPosition calldata _call,
        bytes calldata _signature
    ) external auth {
        if (block.timestamp > _call.deadline) revert Error.Allocation__IntentExpired(_call.deadline, block.timestamp);

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            CALL_POSITION_TYPEHASH,
            _call.master,
            _call.target,
            keccak256(_call.callData),
            _call.deadline,
            _call.nonce
        )));
        address _signer = ECDSA.recover(_hash, _signature);
        if (_signer != _call.master) revert Error.Allocation__InvalidSignature(_call.master, _signer);

        uint256 _expectedNonce = nonces[_call.master]++;
        if (_expectedNonce != _call.nonce) revert Error.Allocation__InvalidNonce(_expectedNonce, _call.nonce);

        IERC7579Account _subaccount = IERC7579Account(_call.master);

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _subaccount,
            _call.target,
            config.callGasLimit,
            _call.callData
        );

        _logEvent("CallPosition", abi.encode(
            _call.master,
            _call.target,
            _call.callData,
            _result,
            _error
        ));
    }

    function calcNetPositionsValue(bytes32 _key, address _token) internal view returns (AssetsInfo memory _info) {
        IERC7579Account _subaccount = subaccountMap[_key];
        if (address(_subaccount) == address(0)) return _info;

        _info.idleBalance = IERC20(_token).balanceOf(address(_subaccount));

        bytes32[] storage _keys = positionKeys[_key];
        for (uint _i = 0; _i < _keys.length; ++_i) {
            int256 _npv = config.npvReader.getPositionNetValue(_keys[_i]);
            if (_npv > 0) _info.positionValue += uint256(_npv);
        }

        _info.total = _info.idleBalance + _info.positionValue;
    }

    function _verifyIntent(CallIntent calldata _intent, bytes calldata _signature) internal {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            CALL_INTENT_TYPEHASH,
            uint8(_intent.intentType),
            _intent.user,
            _intent.master,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _intent.deadline,
            _intent.nonce
        )));
        address _signer = ECDSA.recover(_hash, _signature);

        if (_signer != _intent.user) revert Error.Allocation__InvalidSignature(_intent.user, _signer);
        uint256 _expectedNonce = nonces[_intent.user]++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocation__InvalidNonce(_expectedNonce, _intent.nonce);
    }

    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gas, bytes memory _data) internal returns (bytes memory _result, bytes memory _error) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gas}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            _result = _results[0];
        } catch (bytes memory _reason) {
            _error = _reason;
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert Error.Allocation__InvalidMaxPuppetList();
        if (_config.transferGasLimit == 0) revert Error.Allocation__InvalidTransferGasLimit();
        if (_config.callGasLimit == 0) revert Error.Allocation__InvalidCallGasLimit();
        config = _config;
    }

    function isModuleType(uint256 _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address _smartAccount) external view returns (bool) {
        return masterCollateralList[IERC7579Account(_smartAccount)].length > 0;
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external {
        IERC7579Account _master = IERC7579Account(msg.sender);
        if (!_master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) return;

        IERC20[] memory _tokens = masterCollateralList[_master];
        for (uint _i = 0; _i < _tokens.length; ++_i) {
            bytes32 _key = PositionUtils.getMatchingKey(_tokens[_i], address(_master));
            uint _shares = totalShares[_key];
            if (_shares > 0) revert Error.Allocation__ActiveShares(_shares);
        }
        delete masterCollateralList[_master];
    }
}
