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

contract Allocation is CoreContract, IExecutor, EIP712 {
    enum IntentType { MasterDeposit, Allocate, Withdraw, Order }

    struct Config {
        uint maxPuppetList;
        uint transferGasLimit;
        uint callGasLimit;
        uint virtualShareOffset;
    }

    struct CallIntent {
        IntentType intentType;
        address account;
        address subaccount;
        address token;
        uint256 amount;
        uint256 acceptablePrice;
        uint256 deadline;
        uint256 nonce;
    }

    struct AssetsInfo {
        uint idleBalance;
        uint positionValue;
        uint total;
    }

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(uint8 intentType,address account,address subaccount,address token,uint256 amount,uint256 acceptablePrice,uint256 deadline,uint256 nonce)"
    );

    Config public config;

    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => mapping(address => uint)) public userShares;

    mapping(address => uint256) public nonces;
    mapping(bytes32 => IERC7579Account) public masterSubaccountMap;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    mapping(bytes32 => bytes32[]) public positionKeyList;
    mapping(address => INpvReader) public npvReaderMap;
    mapping(bytes32 => address) public positionTargetMap;

    mapping(address => address) public sessionSigner;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocation", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(bytes32 _key, uint _totalAssets) public view returns (uint) {
        uint _assets = _totalAssets + config.virtualShareOffset;
        uint _shares = totalShares[_key] + config.virtualShareOffset;
        return Precision.toFactor(_assets, _shares);
    }

    function getUserShares(IERC20 _token, address _subaccount, address _user) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount);
        return userShares[_key][_user];
    }

    function getUserNpv(IERC20 _token, address _subaccount, address _user) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _subaccount);
        uint _shares = userShares[_key][_user];
        if (_shares == 0) return 0;

        AssetsInfo memory _assets = _calcNetPositionsValue(_key, address(_token));
        uint _sharePrice = getSharePrice(_key, _assets.total);
        return Precision.applyFactor(_sharePrice, _shares);
    }

    function getPositionKeyList(bytes32 _key) external view returns (bytes32[] memory) {
        return positionKeyList[_key];
    }

    function setNpvReader(address _target, INpvReader _reader) external auth {
        npvReaderMap[_target] = _reader;
    }

    function createSubaccount(
        address _user,
        address _signer,
        address _subaccount,
        address _token,
        uint _amount
    ) external auth {
        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_token), _subaccount);
        if (address(masterSubaccountMap[_key]) != address(0)) revert Error.Allocation__AlreadyRegistered();
        if (!IERC7579Account(_subaccount).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
            revert Error.Allocation__UnregisteredSubaccount();
        }

        sessionSigner[_user] = _signer;
        masterSubaccountMap[_key] = IERC7579Account(_subaccount);
        masterCollateralList[IERC7579Account(_subaccount)].push(IERC20(_token));

        if (!IERC20(_token).transferFrom(_user, _subaccount, _amount)) {
            revert Error.Allocation__TransferFailed();
        }

        uint _sharePrice = getSharePrice(_key, 0);
        uint _sharesOut = Precision.toFactor(_amount, _sharePrice);
        userShares[_key][_user] += _sharesOut;
        totalShares[_key] += _sharesOut;

        _logEvent("CreateSubaccount", abi.encode(
            _key,
            _user,
            _signer,
            _subaccount,
            _token,
            _amount,
            _sharesOut,
            _sharePrice,
            totalShares[_key]
        ));
    }

    function executeMasterDeposit(
        CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        _verifyIntent(_intent, _signature, IntentType.MasterDeposit);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.subaccount);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        AssetsInfo memory _assets = _calcNetPositionsValue(_key, _intent.token);
        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice > _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooHigh(_sharePrice, _intent.acceptablePrice);
        }

        if (!IERC20(_intent.token).transferFrom(_intent.account, _intent.subaccount, _intent.amount)) {
            revert Error.Allocation__TransferFailed();
        }

        uint _sharesOut = Precision.toFactor(_intent.amount, _sharePrice);
        userShares[_key][_intent.account] += _sharesOut;
        totalShares[_key] += _sharesOut;

        _logEvent("ExecuteMasterDeposit", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _sharesOut,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key]
        ));
    }

    function executeAllocate(
        CallIntent calldata _intent,
        bytes calldata _signature,
        address[] calldata _puppetList,
        uint256[] calldata _amountList
    ) external auth {
        _verifyIntent(_intent, _signature, IntentType.Allocate);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.subaccount);
        AssetsInfo memory _assets = _calcNetPositionsValue(_key, _intent.token);

        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();
        if (_puppetList.length != _amountList.length) {
            revert Error.Allocation__ArrayLengthMismatch(_puppetList.length, _amountList.length);
        }
        if (_puppetList.length > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetList.length, config.maxPuppetList);
        }

        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice > _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooHigh(_sharePrice, _intent.acceptablePrice);
        }

        uint _totalAllocated = 0;

        for (uint _i = 0; _i < _puppetList.length; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _amountList[_i];

            (bytes memory _result, bytes memory _error) = _executeFromExecutor(
                IERC7579Account(_puppet),
                _intent.token,
                config.callGasLimit,
                abi.encodeCall(IERC20.transfer, (_intent.subaccount, _amount))
            );

            if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) {
                _logEvent("ExecuteAllocateFailed", abi.encode(_key, _puppet, _amount, _error));
                continue;
            }

            uint _sharesOut = Precision.toFactor(_amount, _sharePrice);
            userShares[_key][_puppet] += _sharesOut;
            totalShares[_key] += _sharesOut;
            _totalAllocated += _amount;
        }

        _logEvent("ExecuteAllocate", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _puppetList,
            _amountList,
            _totalAllocated,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key]
        ));
    }

    function executeWithdraw(
        CallIntent calldata _intent,
        bytes calldata _signature
    ) external auth {
        _verifyIntent(_intent, _signature, IntentType.Withdraw);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.subaccount);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        AssetsInfo memory _assets = _calcNetPositionsValue(_key, _intent.token);

        uint _userBalance = userShares[_key][_intent.account];
        if (_intent.amount > _userBalance) revert Error.Allocation__InsufficientBalance(_userBalance, _intent.amount);

        uint _sharePrice = getSharePrice(_key, _assets.total);

        if (_intent.acceptablePrice > 0 && _sharePrice < _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooLow(_sharePrice, _intent.acceptablePrice);
        }

        uint _amountOut = Precision.applyFactor(_sharePrice, _intent.amount);

        if (_amountOut > _assets.idleBalance) revert Error.Allocation__InsufficientBalance(_assets.idleBalance, _amountOut);

        userShares[_key][_intent.account] -= _intent.amount;
        totalShares[_key] -= _intent.amount;

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            IERC7579Account(_intent.subaccount),
            _intent.token,
            config.transferGasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.account, _amountOut))
        );

        if (_error.length > 0 || _result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        _logEvent("ExecuteWithdraw", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _amountOut,
            _sharePrice,
            _assets.idleBalance,
            _assets.positionValue,
            totalShares[_key],
            userShares[_key][_intent.account]
        ));
    }

    function executeOrder(
        CallIntent calldata _intent,
        bytes calldata _signature,
        address _target,
        bytes calldata _callData
    ) external auth {
        _verifyIntent(_intent, _signature, IntentType.Order);

        INpvReader _reader = npvReaderMap[_target];
        if (address(_reader) == address(0)) revert Error.Allocation__TargetNotWhitelisted(_target);

        bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.subaccount);
        if (address(masterSubaccountMap[_key]) == address(0)) revert Error.Allocation__UnregisteredSubaccount();

        INpvReader.PositionCallInfo memory _posInfo = _reader.parsePositionCall(_intent.subaccount, _callData);

        // Track new positions on increase
        if (_posInfo.isIncrease && _posInfo.positionKey != bytes32(0) && positionTargetMap[_posInfo.positionKey] == address(0)) {
            positionKeyList[_key].push(_posInfo.positionKey);
            positionTargetMap[_posInfo.positionKey] = _target;
        }

        (bytes memory _result, bytes memory _error) = _executeFromExecutor(
            IERC7579Account(_intent.subaccount),
            _target,
            config.callGasLimit,
            _callData
        );

        uint256 _netValue = _reader.getPositionNetValue(_posInfo.positionKey);

        // Remove closed positions (NPV = 0)
        if (_netValue == 0 && _posInfo.positionKey != bytes32(0)) {
            bytes32[] storage _keys = positionKeyList[_key];
            for (uint _i = 0; _i < _keys.length; ++_i) {
                if (_keys[_i] == _posInfo.positionKey) {
                    _keys[_i] = _keys[_keys.length - 1];
                    _keys.pop();
                    delete positionTargetMap[_posInfo.positionKey];
                    break;
                }
            }
        }

        _logEvent("ExecuteOrder", abi.encode(
            _key,
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _target,
            _callData,
            _posInfo,
            _netValue,
            _result,
            _error
        ));
    }

    function _calcNetPositionsValue(bytes32 _key, address _token) internal view returns (AssetsInfo memory _info) {
        IERC7579Account _subaccount = masterSubaccountMap[_key];
        if (address(_subaccount) == address(0)) return _info;

        _info.idleBalance = IERC20(_token).balanceOf(address(_subaccount));

        bytes32[] storage _keys = positionKeyList[_key];
        for (uint _i = 0; _i < _keys.length; ++_i) {
            bytes32 _positionKey = _keys[_i];
            address _target = positionTargetMap[_positionKey];
            INpvReader _reader = npvReaderMap[_target];
            if (address(_reader) == address(0)) continue;

            uint256 _npv = _reader.getPositionNetValue(_positionKey);
            _info.positionValue += _npv;
        }

        _info.total = _info.idleBalance + _info.positionValue;
    }

    function _verifyIntent(CallIntent calldata _intent, bytes calldata _signature, IntentType _expectedType) internal {
        if (_intent.intentType != _expectedType) revert Error.Allocation__InvalidCallType();
        if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            CALL_INTENT_TYPEHASH,
            uint8(_intent.intentType),
            _intent.account,
            _intent.subaccount,
            _intent.token,
            _intent.amount,
            _intent.acceptablePrice,
            _intent.deadline,
            _intent.nonce
        )));
        address _signer = ECDSA.recover(_hash, _signature);
        if (_signer != _intent.account && _signer != sessionSigner[_intent.account]) {
            revert Error.Allocation__InvalidSignature(_intent.account, _signer);
        }
        if (!IERC7579Account(_intent.subaccount).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
            revert Error.Allocation__UnregisteredSubaccount();
        }

        uint256 _expectedNonce = nonces[_intent.account]++;
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
