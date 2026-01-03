// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {
    IExecutor,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {
    ModeLib,
    ModeCode,
    ModePayload,
    CALLTYPE_SINGLE,
    EXECTYPE_TRY,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT
} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";
import {Position} from "./Position.sol";
import {IStage} from "./interface/IStage.sol";

/// @title Allocation
/// @notice ERC-7579 Executor module for share-based fund allocation to master subaccounts
contract Allocation is CoreContract, IExecutor, EIP712 {
    struct Config {
        Position position;
        address masterHook;
        uint maxPuppetList;
        uint transferGasLimit;
    }

    struct PositionParams {
        IStage[] stages;
        bytes32[][] positionKeys;
    }

    struct CallIntent {
        address account;
        IERC7579Account subaccount;
        IERC20 token;
        uint amount;
        uint triggerNetValue;
        uint acceptableNetValue;
        bytes32 positionParamsHash;
        uint deadline;
        uint nonce;
    }

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(address account,address subaccount,address token,uint256 amount,uint256 triggerNetValue,uint256 acceptableNetValue,bytes32 positionParamsHash,uint256 deadline,uint256 nonce)"
    );

    ModeCode internal constant MODE_TRY =
        ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00))));
    ModeCode internal constant MODE_STRICT = ModeCode.wrap(
        bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00)))
    );

    Config public config;

    mapping(IERC20 token => uint) public tokenCapMap;
    mapping(bytes32 codeHash => bool) public account7579CodeHashMap;

    mapping(IERC7579Account subaccount => bool) public registeredMap;
    mapping(IERC7579Account subaccount => address) public sessionSignerMap;
    mapping(IERC7579Account subaccount => IERC20) public baseTokenMap;
    mapping(IERC7579Account subaccount => bool) public disposedMap;
    mapping(IERC7579Account subaccount => uint) public nonceMap;

    mapping(IERC7579Account subaccount => uint) public totalSharesMap;
    mapping(IERC7579Account subaccount => mapping(address account => uint)) public shareBalanceMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocation", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(IERC7579Account _subaccount, uint _totalAssets) public view returns (uint) {
        uint _totalShares = totalSharesMap[_subaccount];
        if (_totalShares == 0) return Precision.FLOAT_PRECISION;
        if (_totalAssets == 0) revert Error.Allocation__ZeroAssets();
        return Precision.toFactor(_totalAssets, _totalShares);
    }

    function getUserShares(IERC7579Account _subaccount, address _account) external view returns (uint) {
        return shareBalanceMap[_subaccount][_account];
    }

    function hasRemainingShares(IERC7579Account _subaccount) external view returns (bool) {
        return totalSharesMap[_subaccount] > 0;
    }

    function setTokenCap(IERC20 _token, uint _cap) external auth {
        tokenCapMap[_token] = _cap;
        _logEvent("SetTokenCap", abi.encode(_token, _cap));
    }

    function setCodeHash(bytes32 _codeHash, bool _allowed) external auth {
        account7579CodeHashMap[_codeHash] = _allowed;
        _logEvent("SetCodeHash", abi.encode(_codeHash, _allowed));
    }

    function registerMasterSubaccount(
        address _account,
        address _signer,
        IERC7579Account _subaccount,
        IERC20 _baseToken,
        bytes32 _name
    ) external {
        bytes32 codeHash;
        assembly { codeHash := extcodehash(_subaccount) }
        if (!account7579CodeHashMap[codeHash]) revert Error.Allocation__InvalidAccountCodeHash();
        if (!_subaccount.isModuleInstalled(MODULE_TYPE_HOOK, config.masterHook, "")) revert Error.Allocation__MasterHookNotInstalled();
        if (registeredMap[_subaccount]) revert Error.Allocation__AlreadyRegistered();
        if (tokenCapMap[_baseToken] == 0) revert Error.Allocation__TokenNotAllowed();
        if (_baseToken.balanceOf(address(_subaccount)) == 0) revert Error.Allocation__ZeroAssets();

        registeredMap[_subaccount] = true;
        sessionSignerMap[_subaccount] = _signer;
        baseTokenMap[_subaccount] = _baseToken;

        _logEvent("RegisterMasterSubaccount", abi.encode(_subaccount, _account, _signer, _baseToken, _name));
    }

    function executeAllocate(
        CallIntent calldata _intent,
        bytes calldata _signature,
        IERC7579Account[] calldata _puppetList,
        uint[] calldata _amountList,
        PositionParams calldata _positionParams
    ) external auth {
        IERC20 _baseToken = _verifyIntent(_intent, _signature, _positionParams);
        IERC7579Account _subaccount = _intent.subaccount;
        if (disposedMap[_subaccount]) revert Error.Allocation__SubaccountFrozen();

        uint _len = _puppetList.length;
        if (_len != _amountList.length) revert Error.Allocation__ArrayLengthMismatch(_len, _amountList.length);
        if (_len > config.maxPuppetList) revert Error.Allocation__PuppetListTooLarge(_len, config.maxPuppetList);

        address _subaccountAddr = address(_subaccount);
        uint _allocation = _baseToken.balanceOf(_subaccountAddr);
        uint _positionValue = config.position.getNetValue(
            _subaccountAddr,
            _baseToken,
            _positionParams.stages,
            _positionParams.positionKeys
        );
        uint _netValue = _allocation + _positionValue;

        if (_netValue > _intent.acceptableNetValue) {
            revert Error.Allocation__NetValueAboveMax(_netValue, _intent.acceptableNetValue);
        }

        uint _sharePrice = getSharePrice(_subaccount, _netValue);
        uint _totalShares = totalSharesMap[_subaccount];
        address _account = _intent.account;
        uint _userShares = shareBalanceMap[_subaccount][_account];
        uint _intentAmount = _intent.amount;
        IERC20 _token = _intent.token;

        if (_intentAmount != 0) {
            uint _balanceBefore = _token.balanceOf(_subaccountAddr);
            if (!_token.transferFrom(_account, _subaccountAddr, _intentAmount)) {
                revert Error.Allocation__TransferFailed();
            }
            uint _recordedIn = _token.balanceOf(_subaccountAddr) - _balanceBefore;
            if (_recordedIn != _intentAmount) revert Error.Allocation__AmountMismatch(_intentAmount, _recordedIn);
            uint _shares = Precision.toFactor(_recordedIn, _sharePrice);
            if (_shares == 0) revert Error.Allocation__ZeroShares();
            _userShares += _shares;
            shareBalanceMap[_subaccount][_account] = _userShares;
            _totalShares += _shares;
        }

        uint _allocated;
        uint _gasLimit = config.transferGasLimit;
        for (uint _i; _i < _len; ++_i) {
            IERC7579Account _puppet = _puppetList[_i];
            if (address(_puppet) != _subaccountAddr) {
                uint _amount = _amountList[_i];
                uint _shares = Precision.toFactor(_amount, _sharePrice);

                if (_shares != 0) {
                    uint _balanceBefore = _token.balanceOf(_subaccountAddr);
                    (bool _success,) = address(_token).call{gas: _gasLimit}(
                        abi.encodeCall(IERC20.transferFrom, (address(_puppet), _subaccountAddr, _amount))
                    );
                    if (_success) {
                        uint _recordedIn = _token.balanceOf(_subaccountAddr) - _balanceBefore;
                        if (_recordedIn != _amount) revert Error.Allocation__AmountMismatch(_amount, _recordedIn);
                        shareBalanceMap[_subaccount][address(_puppet)] += _shares;
                        _totalShares += _shares;
                        _allocated += _recordedIn;
                    } else {
                        _logEvent("ExecuteAllocateFailed", abi.encode(_subaccount, _token, _puppet, _amount));
                    }
                }
            }
        }

        _allocation += _intentAmount + _allocated;
        uint _cap = tokenCapMap[_baseToken];
        if (_allocation > _cap) revert Error.Allocation__DepositExceedsCap(_allocation, _cap);
        totalSharesMap[_subaccount] = _totalShares;

        _logEvent(
            "ExecuteAllocate",
            abi.encode(
                _subaccount,
                _account,
                _token,
                _intentAmount,
                _puppetList,
                _amountList,
                _allocation,
                _positionValue,
                _allocated,
                _sharePrice,
                _userShares,
                _totalShares,
                _intent.nonce
            )
        );
    }

    function executeWithdraw(
        CallIntent calldata _intent,
        bytes calldata _signature,
        PositionParams calldata _positionParams
    ) external auth {
        IERC20 _baseToken = _verifyIntent(_intent, _signature, _positionParams);
        IERC7579Account _subaccount = _intent.subaccount;

        uint _allocation = _baseToken.balanceOf(address(_subaccount));
        uint _positionValue = config.position.getNetValue(
            address(_subaccount),
            _baseToken,
            _positionParams.stages,
            _positionParams.positionKeys
        );
        uint _netValue = _allocation + _positionValue;

        if (_netValue < _intent.acceptableNetValue) {
            revert Error.Allocation__NetValueBelowMin(_netValue, _intent.acceptableNetValue);
        }

        uint _sharePrice = getSharePrice(_subaccount, _netValue);
        uint _sharesBurnt = Precision.toFactor(_intent.amount, _sharePrice);
        if (_sharesBurnt == 0) revert Error.Allocation__ZeroShares();
        uint _amountOut = Precision.applyFactor(_sharePrice, _sharesBurnt);

        uint _prevUserShares = shareBalanceMap[_subaccount][_intent.account];
        if (_sharesBurnt > _prevUserShares) revert Error.Allocation__InsufficientBalance();
        if (_amountOut > _allocation) revert Error.Allocation__InsufficientLiquidity();

        _subaccount.executeFromExecutor{gas: config.transferGasLimit}(
            MODE_TRY,
            ExecutionLib.encodeSingle(address(_baseToken), 0, abi.encodeCall(IERC20.transfer, (_intent.account, _amountOut)))
        );

        uint _actualOut = _allocation - _baseToken.balanceOf(address(_subaccount));
        if (_actualOut != _amountOut) revert Error.Allocation__AmountMismatch(_amountOut, _actualOut);
        _allocation -= _actualOut;

        uint _userShares = _prevUserShares - _sharesBurnt;
        uint _totalShares = totalSharesMap[_subaccount] - _sharesBurnt;
        shareBalanceMap[_subaccount][_intent.account] = _userShares;
        totalSharesMap[_subaccount] = _totalShares;

        _logEvent(
            "ExecuteWithdraw",
            abi.encode(
                _subaccount,
                _intent.account,
                _intent.token,
                _intent.amount,
                _allocation,
                _positionValue,
                _amountOut,
                _sharesBurnt,
                _sharePrice,
                _userShares,
                _totalShares,
                _intent.nonce
            )
        );
    }

    function _verifyIntent(
        CallIntent calldata _intent,
        bytes calldata _signature,
        PositionParams calldata _positionParams
    ) internal returns (IERC20 _baseToken) {
        if (block.timestamp > _intent.deadline) {
            revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);
        }

        if (keccak256(abi.encode(_positionParams)) != _intent.positionParamsHash) {
            revert Error.Allocation__NetValueParamsMismatch();
        }

        IERC7579Account _subaccount = _intent.subaccount;
        if (!registeredMap[_subaccount]) revert Error.Allocation__UnregisteredSubaccount();
        _baseToken = baseTokenMap[_subaccount];
        if (address(_intent.token) != address(_baseToken)) revert Error.Allocation__TokenMismatch();
        if (tokenCapMap[_baseToken] == 0) revert Error.Allocation__TokenNotAllowed();

        bytes32 _hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CALL_INTENT_TYPEHASH,
                    _intent.account,
                    _intent.subaccount,
                    _intent.token,
                    _intent.amount,
                    _intent.triggerNetValue,
                    _intent.acceptableNetValue,
                    _intent.positionParamsHash,
                    _intent.deadline,
                    _intent.nonce
                )
            )
        );

        uint _expectedNonce = nonceMap[_subaccount]++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocation__InvalidNonce(_expectedNonce, _intent.nonce);

        // Signature must be valid for either account owner or session signer
        // SignatureChecker supports both EOA (ECDSA) and smart accounts (ERC-1271)
        // Short-circuit: if owner sig valid, skip session signer check
        address _sessionSigner = sessionSignerMap[_subaccount];
        if (
            !SignatureChecker.isValidSignatureNow(_intent.account, _hash, _signature)
                && (_sessionSigner == address(0) || !SignatureChecker.isValidSignatureNow(_sessionSigner, _hash, _signature))
        ) {
            revert Error.Allocation__InvalidSignature(_intent.account, _sessionSigner);
        }
    }


    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (address(_config.position) == address(0)) revert Error.Allocation__InvalidPosition();
        if (_config.masterHook == address(0)) revert Error.Allocation__InvalidMasterHook();
        if (_config.maxPuppetList == 0) revert Error.Allocation__InvalidMaxPuppetList();
        if (_config.transferGasLimit == 0) revert Error.Allocation__InvalidGasLimit();
        config = _config;
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external {}

    function disposeSubaccount(IERC7579Account _subaccount) external {
        if (!registeredMap[_subaccount]) return;
        if (disposedMap[_subaccount]) return;

        disposedMap[_subaccount] = true;

        _logEvent("DisposeSubaccount", abi.encode(_subaccount));
    }

    function onUninstall(bytes calldata) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        if (!registeredMap[_subaccount]) return;

        disposedMap[_subaccount] = true;

        _logEvent("Uninstall", abi.encode(_subaccount));
    }
}
