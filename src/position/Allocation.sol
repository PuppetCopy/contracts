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

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(uint8 intentType,address account,address subaccount,address token,uint256 amount,uint256 acceptableNetValue,uint256 deadline,uint256 nonce)"
    );

    Config public config;

    mapping(address account => uint256) public nonceMap;
    mapping(address account => address signer) public sessionSignerMap;

    mapping(bytes32 matchingKey => IERC7579Account) public masterSubaccountMap;
    mapping(address subaccount => IERC20) public subaccountCollateralMap;

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

    function getUserShares(IERC20 _token, IERC7579Account _subaccount, address _account) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount);
        return shareBalanceMap[_key][_account];
    }

    function createMasterSubaccount(
        address _account,
        address _signer,
        IERC7579Account _subaccount,
        IERC20 _token,
        uint _amount
    ) external auth {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount);
        if (address(masterSubaccountMap[_key]) != address(0)) revert Error.Allocation__AlreadyRegistered();
        if (!_subaccount.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
            revert Error.Allocation__UnregisteredSubaccount();
        }

        sessionSignerMap[_account] = _signer;
        masterSubaccountMap[_key] = _subaccount;
        subaccountCollateralMap[address(_subaccount)] = _token;

        if (!_token.transferFrom(_account, address(_subaccount), _amount)) {
            revert Error.Allocation__TransferFailed();
        }

        uint _sharePrice = getSharePrice(_key, 0);
        uint _shares = Precision.toFactor(_amount, _sharePrice);
        shareBalanceMap[_key][_account] = _shares;
        totalSharesMap[_key] = _shares;

        _logEvent("CreateMasterSubaccount", abi.encode(
            _key,
            _account,
            _signer,
            _subaccount,
            _token,
            _amount,
            _sharePrice,
            _shares
        ));
    }

    function executeAllocate(
        Position.CallIntent calldata _intent,
        bytes calldata _signature,
        IERC7579Account[] calldata _puppetList,
        uint256[] calldata _amountList
    ) external auth {
        _verifyIntent(_intent, _signature);

        (bytes32 _key,,, uint256 _netValue,) = config.position.snapshotNetValue(_intent);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();
        if (_puppetList.length != _amountList.length) {
            revert Error.Allocation__ArrayLengthMismatch(_puppetList.length, _amountList.length);
        }
        if (_puppetList.length > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetList.length, config.maxPuppetList);
        }

        uint _sharePrice = getSharePrice(_key, _netValue);
        uint _totalShares = totalSharesMap[_key];

        // Master deposit
        if (_intent.amount > 0) {
            if (!_intent.token.transferFrom(_intent.account, address(_intent.subaccount), _intent.amount)) {
                revert Error.Allocation__TransferFailed();
            }
            uint _shares = Precision.toFactor(_intent.amount, _sharePrice);
            shareBalanceMap[_key][_intent.account] += _shares;
            _totalShares += _shares;
        }

        // Puppet allocations
        uint _totalAllocated = 0;
        for (uint _i = 0; _i < _puppetList.length; ++_i) {
            IERC7579Account _puppet = _puppetList[_i];
            uint _amount = _amountList[_i];

            (bytes memory _result, bytes memory _error) = _executeFromExecutor(
                _puppet,
                address(_intent.token),
                config.gasLimit,
                abi.encodeCall(IERC20.transfer, (address(_intent.subaccount), _amount))
            );

            if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) {
                _logEvent("ExecuteAllocateFailed", abi.encode(_key, _puppet, _amount, _error));
                continue;
            }

            uint _shares = Precision.toFactor(_amount, _sharePrice);
            shareBalanceMap[_key][address(_puppet)] += _shares;
            _totalShares += _shares;
            _totalAllocated += _amount;
        }

        totalSharesMap[_key] = _totalShares;

        _logEvent("ExecuteAllocate", abi.encode(
            _key,
            _puppetList,
            _amountList,
            _totalAllocated,
            _sharePrice,
            _totalShares
        ));
    }

    function executeWithdraw(
        Position.CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        _verifyIntent(_intent, _signature);

        (bytes32 _key,,, uint256 _netValue,) = config.position.snapshotNetValue(_intent);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        uint _sharePrice = getSharePrice(_key, _netValue);
        uint _sharesToBurn = Precision.toFactor(_intent.amount, _sharePrice);
        uint _amountOut = Precision.applyFactor(_sharePrice, _sharesToBurn);

        uint _userShares = shareBalanceMap[_key][_intent.account];
        if (_sharesToBurn > _userShares) revert Error.Allocation__InsufficientBalance();
        if (_amountOut < _intent.amount) revert Error.Allocation__InsufficientBalance();

        uint _nextUserShares = _userShares - _sharesToBurn;
        uint _nextTotalShares = totalSharesMap[_key] - _sharesToBurn;

        shareBalanceMap[_key][_intent.account] = _nextUserShares;
        totalSharesMap[_key] = _nextTotalShares;

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _intent.subaccount,
            address(_intent.token),
            config.gasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.account, _amountOut))
        );

        if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        _logEvent("ExecuteWithdraw", abi.encode(_key, _amountOut, _sharesToBurn, _sharePrice, _nextTotalShares));
    }

    function executeOrder(
        Position.CallIntent calldata _intent,
        bytes calldata _signature,
        address _target,
        bytes calldata _callData
    ) external auth {
        _verifyIntent(_intent, _signature);

        bytes32 _key = PositionUtils.getMatchingKey(_intent.token, _intent.subaccount);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        Position.Venue memory _venue = config.position.validateCall(_intent.subaccount, _intent.token, _intent.amount, _target, _callData);

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            _intent.subaccount,
            _target,
            config.gasLimit,
            _callData
        );

        IVenueValidator.PositionInfo memory _posInfo = _venue.validator.getPositionInfo(_intent.subaccount, _callData);

        config.position.updatePosition(_key, _posInfo.positionKey, _venue, _posInfo.netValue);

        _logEvent("ExecuteOrder", abi.encode(
            _key,
            _venue,
            _target,
            _posInfo.positionKey,
            _posInfo.netValue,
            _result,
            _error
        ));
    }

    function _verifyIntent(Position.CallIntent calldata _intent, bytes calldata _signature) internal {
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            CALL_INTENT_TYPEHASH,
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
        if (_signer != _intent.account && _signer != sessionSignerMap[_intent.account]) {
            revert Error.Allocation__InvalidSignature(_intent.account, _signer);
        }
        if (!_intent.subaccount.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
            revert Error.Allocation__UnregisteredSubaccount();
        }

        uint256 _expectedNonce = nonceMap[_intent.account]++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocation__InvalidNonce(_expectedNonce, _intent.nonce);
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

    function isInitialized(address _subaccount) external view returns (bool) {
        return address(subaccountCollateralMap[_subaccount]) != address(0);
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external {
        IERC20 _token = subaccountCollateralMap[msg.sender];
        if (address(_token) == address(0)) return;

        bytes32 _key = PositionUtils.getMatchingKey(_token, IERC7579Account(msg.sender));
        uint _shares = totalSharesMap[_key];
        if (_shares > 0) revert Error.Allocation__ActiveShares(_shares);

        delete subaccountCollateralMap[msg.sender];
    }
}
