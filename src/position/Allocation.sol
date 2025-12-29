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
import {IVenueValidator} from "./interface/IVenueValidator.sol";
import {Position} from "./Position.sol";

contract Allocation is CoreContract, IExecutor, EIP712 {

    struct Config {
        Position position;
        uint maxPuppetList;
        uint gasLimit;
        uint virtualShareOffset;
    }

    struct CallIntent {
        address account;
        IERC7579Account subaccount;
        bytes32 subaccountName;
        IERC20 token;
        uint256 amount;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(address account,address subaccount,bytes32 subaccountName,address token,uint256 amount,uint256 deadline,uint256 nonce)"
    );

    Config public config;

    mapping(IERC20 token => uint) public tokenCapMap;

    mapping(bytes32 matchingKey => uint256) public nonceMap;
    mapping(bytes32 matchingKey => address) public sessionSignerMap;
    mapping(bytes32 matchingKey => IERC7579Account) public masterSubaccountMap;
    mapping(bytes32 matchingKey => bool) public frozenMap;

    mapping(bytes32 matchingKey => uint) public totalSharesMap;
    mapping(bytes32 matchingKey => mapping(address account => uint)) public shareBalanceMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocation", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(bytes32 _key, uint _totalAssets) public view returns (uint) {
        uint _assets = _totalAssets + config.virtualShareOffset;
        uint _shares = totalSharesMap[_key] + config.virtualShareOffset;
        return Precision.toFactor(_assets, _shares);
    }

    function getUserShares(IERC20 _token, IERC7579Account _subaccount, bytes32 _name, address _account) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount, _name);
        return shareBalanceMap[_key][_account];
    }

    function setTokenCap(IERC20 _token, uint _cap) external auth {
        tokenCapMap[_token] = _cap;
        _logEvent("SetTokenCap", abi.encode(_token, _cap));
    }

    function createMasterSubaccount(
        address _account,
        address _signer,
        IERC7579Account _subaccount,
        IERC20 _token,
        bytes32 _subaccountName
    ) external auth {
        if (!_subaccount.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) revert Error.Allocation__UnregisteredSubaccount();
        uint _cap = tokenCapMap[_token];
        if (_cap == 0) revert Error.Allocation__TokenNotAllowed();

        uint _balance = _token.balanceOf(address(_subaccount));
        if (_balance == 0) revert Error.Allocation__ZeroAmount();
        if (_balance > _cap) revert Error.Allocation__DepositExceedsCap(_balance, _cap);

        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount, _subaccountName);
        if (address(masterSubaccountMap[_key]) != address(0)) revert Error.Allocation__AlreadyRegistered();

        sessionSignerMap[_key] = _signer;
        masterSubaccountMap[_key] = _subaccount;
        shareBalanceMap[_key][_account] = _balance;
        totalSharesMap[_key] = _balance;

        _logEvent("CreateMasterSubaccount", abi.encode(
            _key,
            _account,
            _signer,
            _subaccount,
            _subaccountName,
            _token,
            _balance
        ));
    }

    function executeAllocate(
        CallIntent calldata _intent,
        bytes calldata _signature,
        IERC7579Account[] calldata _puppetList,
        uint256[] calldata _amountList
    ) external auth {
        bytes32 _key = _verifyIntent(_intent, _signature);
        uint _cap = tokenCapMap[_intent.token];
        if (frozenMap[_key]) revert Error.Allocation__SubaccountFrozen();
        if (_cap == 0) revert Error.Allocation__TokenNotAllowed();
        if (_puppetList.length != _amountList.length) revert Error.Allocation__ArrayLengthMismatch(_puppetList.length, _amountList.length);
        if (_puppetList.length > config.maxPuppetList) revert Error.Allocation__PuppetListTooLarge(_puppetList.length, config.maxPuppetList);

        uint _allocation = _intent.token.balanceOf(address(_intent.subaccount));
        (uint _positionValue, Position.PositionInfo[] memory _positions) = config.position.snapshotNetValue(_key);
        uint _sharePrice = getSharePrice(_key, _allocation + _positionValue);
        uint _totalShares = totalSharesMap[_key];
        uint _userShares = shareBalanceMap[_key][_intent.account];

        if (_intent.amount > 0) {
            if (!_intent.token.transferFrom(_intent.account, address(_intent.subaccount), _intent.amount)) revert Error.Allocation__TransferFailed();
            uint _shares = Precision.toFactor(_intent.amount, _sharePrice);
            if (_shares == 0) revert Error.Allocation__ZeroShares();
            _userShares += _shares;
            shareBalanceMap[_key][_intent.account] = _userShares;
            _totalShares += _shares;
        }

        uint _allocated = 0;
        uint _gasLimit = config.gasLimit;
        for (uint _i = 0; _i < _puppetList.length; ++_i) {
            IERC7579Account _puppet = _puppetList[_i];
            if (address(_puppet) == address(_intent.subaccount)) continue;
            uint _amount = _amountList[_i];

            (bytes memory _result, bytes memory _error) = _executeFromExecutor(_puppet, address(_intent.token), _gasLimit, abi.encodeCall(IERC20.transfer, (address(_intent.subaccount), _amount)));
            if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) {
                _logEvent("ExecuteAllocateFailed", abi.encode(_key, _puppet, _amount, _error));
                continue;
            }

            uint _shares = Precision.toFactor(_amount, _sharePrice);
            if (_shares == 0) revert Error.Allocation__ZeroShares();
            shareBalanceMap[_key][address(_puppet)] += _shares;
            _totalShares += _shares;
            _allocated += _amount;
        }

        _allocation += _intent.amount + _allocated;
        if (_allocation > _cap) revert Error.Allocation__DepositExceedsCap(_allocation, _cap);
        totalSharesMap[_key] = _totalShares;

        _logEvent("ExecuteAllocate", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.subaccountName,
            _intent.token,
            _intent.amount,
            _puppetList,
            _amountList,
            _allocation,
            _positionValue,
            _positions,
            _allocated,
            _sharePrice,
            _userShares,
            _totalShares
        ));
    }

    function executeWithdraw(
        CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        bytes32 _key = _verifyIntent(_intent, _signature);

        uint _allocation = _intent.token.balanceOf(address(_intent.subaccount));
        (uint _positionValue, Position.PositionInfo[] memory _positions) = config.position.snapshotNetValue(_key);
        uint _netValue = _allocation + _positionValue;

        uint _sharePrice = getSharePrice(_key, _netValue);
        uint _sharesBurnt = Precision.toFactor(_intent.amount, _sharePrice);
        if (_sharesBurnt == 0) revert Error.Allocation__ZeroShares();
        uint _amountOut = Precision.applyFactor(_sharePrice, _sharesBurnt);

        uint _prevUserShares = shareBalanceMap[_key][_intent.account];
        if (_sharesBurnt > _prevUserShares) revert Error.Allocation__InsufficientBalance();
        if (_amountOut < _intent.amount) revert Error.Allocation__InsufficientBalance();
        if (_amountOut > _allocation) revert Error.Allocation__InsufficientLiquidity();

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _intent.subaccount,
            address(_intent.token),
            config.gasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.account, _amountOut))
        );
        if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        uint _userShares = _prevUserShares - _sharesBurnt;
        uint _totalShares = totalSharesMap[_key] - _sharesBurnt;
        shareBalanceMap[_key][_intent.account] = _userShares;
        totalSharesMap[_key] = _totalShares;

        _logEvent("ExecuteWithdraw", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.subaccountName,
            _intent.token,
            _intent.amount,
            _allocation - _amountOut,
            _positionValue,
            _positions,
            _amountOut,
            _sharesBurnt,
            _sharePrice,
            _userShares,
            _totalShares
        ));
    }

    function executeOrder(
        CallIntent calldata _intent,
        bytes calldata _signature,
        address _target,
        bytes calldata _callData
    ) external auth {
        bytes32 _key = _verifyIntent(_intent, _signature);
        if (frozenMap[_key]) revert Error.Allocation__SubaccountFrozen();

        Position.Venue memory _venue = config.position.validateCall(_intent.subaccount, _intent.token, _intent.amount, _target, _callData);

        uint _balanceBefore = _intent.token.balanceOf(address(_intent.subaccount));

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _intent.subaccount,
            _target,
            config.gasLimit,
            _callData
        );

        if (_error.length > 0 || _result.length == 0) {
            _logEvent("ExecuteOrderFailed", abi.encode(_key, _intent.account, _target, _callData, _error));
            return;
        }

        uint _allocation = _intent.token.balanceOf(address(_intent.subaccount));
        if (_intent.amount > 0) {
            uint _spent = _balanceBefore - _allocation;
            if (_spent != _intent.amount) revert Error.Allocation__AmountMismatch(_intent.amount, _spent);
        }

        IVenueValidator.PositionInfo memory _posInfo = _venue.validator.getPositionInfo(_intent.subaccount, _callData);
        bytes32 _positionKey = _posInfo.positionKey;
        uint _positionValue = _posInfo.netValue;

        config.position.updatePosition(_key, _positionKey, _venue, _positionValue);

        _logEvent("ExecuteOrder", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.subaccountName,
            _intent.token,
            _intent.amount,
            _allocation,
            _target,
            _venue,
            _positionKey,
            _positionValue,
            _result
        ));
    }

    function _verifyIntent(CallIntent calldata _intent, bytes calldata _signature) internal returns (bytes32 _key) {
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            CALL_INTENT_TYPEHASH,
            _intent.account,
            _intent.subaccount,
            _intent.subaccountName,
            _intent.token,
            _intent.amount,
            _intent.deadline,
            _intent.nonce
        )));
        _key = PositionUtils.getMatchingKey(_intent.token, _intent.subaccount, _intent.subaccountName);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        uint256 _expectedNonce = nonceMap[_key]++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocation__InvalidNonce(_expectedNonce, _intent.nonce);

        address _signer = ECDSA.recover(_hash, _signature);
        if (_signer != _intent.account && _signer != sessionSignerMap[_key]) {
            revert Error.Allocation__InvalidSignature(_intent.account, _signer);
        }
    }

    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gasLimit, bytes memory _data) internal returns (bytes memory _result, bytes memory _error) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gasLimit}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            _result = _results[0];
        } catch (bytes memory _reason) {
            _error = _reason;
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (address(_config.position) == address(0)) revert Error.Allocation__InvalidPosition();
        if (_config.maxPuppetList == 0) revert Error.Allocation__InvalidMaxPuppetList();
        if (_config.gasLimit == 0) revert Error.Allocation__InvalidGasLimit();
        config = _config;
    }

    function isModuleType(uint256 _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata _data) external {
        (IERC20 _token, bytes32 _subaccountName) = abi.decode(_data, (IERC20, bytes32));
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount, _subaccountName);
        if (address(masterSubaccountMap[_key]) == address(0)) return;

        frozenMap[_key] = true;

        _logEvent("Uninstall", abi.encode(_key, _subaccount, _token, _subaccountName));
    }
}
