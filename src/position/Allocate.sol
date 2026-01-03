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
import {Match} from "./Match.sol";
import {Position} from "./Position.sol";
import {IStage} from "./interface/IStage.sol";

/// @title Allocate
/// @notice ERC-7579 Executor module for share-based fund allocation to master subaccounts
contract Allocate is CoreContract, IExecutor, EIP712 {
    struct Config {
        address masterHook;
        uint maxPuppetList;
        uint withdrawGasLimit;
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

    struct SubaccountInfo {
        address account;
        address signer;
        IERC20 baseToken;
        bytes32 name;
        bool disposed;
        uint nonce;
    }

    mapping(IERC7579Account subaccount => SubaccountInfo) public registeredMap;

    mapping(IERC7579Account subaccount => uint) public totalSharesMap;
    mapping(IERC7579Account subaccount => mapping(address account => uint)) public shareBalanceMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocate", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(IERC7579Account _subaccount, uint _totalAssets) public view returns (uint) {
        uint _totalShares = totalSharesMap[_subaccount];
        if (_totalShares == 0) return Precision.FLOAT_PRECISION;
        if (_totalAssets == 0) revert Error.Allocate__ZeroAssets();
        return Precision.toFactor(_totalAssets, _totalShares);
    }

    function getUserShares(IERC7579Account _subaccount, address _account) external view returns (uint) {
        return shareBalanceMap[_subaccount][_account];
    }

    function hasRemainingShares(IERC7579Account _subaccount) external view returns (bool) {
        return totalSharesMap[_subaccount] > 0;
    }

    function getSubaccountInfo(IERC7579Account _subaccount) external view returns (SubaccountInfo memory) {
        return registeredMap[_subaccount];
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
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_subaccount) }
        if (!account7579CodeHashMap[_codeHash]) revert Error.Allocate__InvalidAccountCodeHash();
        if (!_subaccount.isModuleInstalled(MODULE_TYPE_HOOK, config.masterHook, "")) revert Error.Allocate__MasterHookNotInstalled();
        if (address(registeredMap[_subaccount].baseToken) != address(0)) revert Error.Allocate__AlreadyRegistered();
        if (tokenCapMap[_baseToken] == 0) revert Error.Allocate__TokenNotAllowed();
        if (_baseToken.balanceOf(address(_subaccount)) == 0) revert Error.Allocate__ZeroAssets();

        registeredMap[_subaccount] = SubaccountInfo(_account, _signer, _baseToken, _name, false, 0);

        _logEvent("RegisterMasterSubaccount", abi.encode(_subaccount, _account, _signer, _baseToken, _name));
    }

    struct AllocateContext {
        uint netValue;
        uint allocation;
        uint sharePrice;
        uint totalShares;
        uint userShares;
        uint allocated;
    }

    function executeAllocate(
        Position _position,
        Match _match,
        CallIntent calldata _intent,
        bytes calldata _signature,
        address[] calldata _puppetList,
        uint[] calldata _amountList,
        PositionParams calldata _positionParams
    ) external auth {
        SubaccountInfo memory _info = _verifyIntent(_intent, _signature, _positionParams);
        if (_info.disposed) revert Error.Allocate__SubaccountFrozen();

        if (_puppetList.length != _amountList.length) {
            revert Error.Allocate__ArrayLengthMismatch(_puppetList.length, _amountList.length);
        }
        if (_puppetList.length > config.maxPuppetList) {
            revert Error.Allocate__PuppetListTooLarge(_puppetList.length, config.maxPuppetList);
        }

        AllocateContext memory _ctx;
        IERC7579Account _subaccount = _intent.subaccount;
        IERC20 _baseToken = _info.baseToken;

        _ctx.allocation = _baseToken.balanceOf(address(_subaccount));
        _ctx.netValue = _ctx.allocation + _position.getNetValue(
            address(_subaccount), _baseToken, _positionParams.stages, _positionParams.positionKeys
        );

        if (_ctx.netValue > _intent.acceptableNetValue) {
            revert Error.Allocate__NetValueAboveMax(_ctx.netValue, _intent.acceptableNetValue);
        }

        _ctx.sharePrice = getSharePrice(_subaccount, _ctx.netValue);
        _ctx.totalShares = totalSharesMap[_subaccount];
        _ctx.userShares = shareBalanceMap[_subaccount][_intent.account];

        if (_intent.amount != 0) {
            uint _balanceBefore = _baseToken.balanceOf(address(_subaccount));
            if (!_baseToken.transferFrom(_intent.account, address(_subaccount), _intent.amount)) {
                revert Error.Allocate__TransferFailed();
            }
            uint _recordedIn = _baseToken.balanceOf(address(_subaccount)) - _balanceBefore;
            if (_recordedIn != _intent.amount) revert Error.Allocate__AmountMismatch(_intent.amount, _recordedIn);
            uint _shares = Precision.toFactor(_recordedIn, _ctx.sharePrice);
            if (_shares == 0) revert Error.Allocate__ZeroShares();
            _ctx.userShares += _shares;
            shareBalanceMap[_subaccount][_intent.account] = _ctx.userShares;
            _ctx.totalShares += _shares;
        }

        if (_puppetList.length > 0) {
            address _stage = _positionParams.stages.length > 0 ? address(_positionParams.stages[0]) : address(0);
            Match.MatchParams memory _matchParams = Match.MatchParams({
                subaccount: address(_subaccount),
                master: _intent.account,
                chainId: block.chainid,
                stage: _stage,
                collateral: _baseToken
            });
            uint[] memory _allocatedAmounts = _match.executeMatch(_matchParams, _puppetList, _amountList);

            for (uint _i; _i < _puppetList.length; ++_i) {
                uint _amount = _allocatedAmounts[_i];
                if (_amount > 0) {
                    uint _shares = Precision.toFactor(_amount, _ctx.sharePrice);
                    if (_shares > 0) {
                        shareBalanceMap[_subaccount][_puppetList[_i]] += _shares;
                        _ctx.totalShares += _shares;
                        _ctx.allocated += _amount;
                    }
                }
            }
        }

        _ctx.allocation += _intent.amount + _ctx.allocated;
        if (_ctx.allocation > tokenCapMap[_baseToken]) {
            revert Error.Allocate__DepositExceedsCap(_ctx.allocation, tokenCapMap[_baseToken]);
        }
        totalSharesMap[_subaccount] = _ctx.totalShares;

        _logEvent(
            "ExecuteAllocate",
            abi.encode(
                _subaccount,
                _intent.account,
                _baseToken,
                _intent.amount,
                _puppetList,
                _amountList,
                _ctx.allocation,
                _ctx.netValue,
                _ctx.allocated,
                _ctx.sharePrice,
                _ctx.userShares,
                _ctx.totalShares,
                _intent.nonce
            )
        );
    }

    function executeWithdraw(
        Position _position,
        CallIntent calldata _intent,
        bytes calldata _signature,
        PositionParams calldata _positionParams
    ) external auth {
        SubaccountInfo memory _info = _verifyIntent(_intent, _signature, _positionParams);
        IERC20 _baseToken = _info.baseToken;
        IERC7579Account _subaccount = _intent.subaccount;

        uint _allocation = _baseToken.balanceOf(address(_subaccount));
        uint _positionValue = _position.getNetValue(
            address(_subaccount),
            _baseToken,
            _positionParams.stages,
            _positionParams.positionKeys
        );
        uint _netValue = _allocation + _positionValue;

        if (_netValue < _intent.acceptableNetValue) {
            revert Error.Allocate__NetValueBelowMin(_netValue, _intent.acceptableNetValue);
        }

        uint _sharePrice = getSharePrice(_subaccount, _netValue);
        uint _sharesBurnt = Precision.toFactor(_intent.amount, _sharePrice);
        if (_sharesBurnt == 0) revert Error.Allocate__ZeroShares();
        uint _amountOut = Precision.applyFactor(_sharePrice, _sharesBurnt);

        uint _prevUserShares = shareBalanceMap[_subaccount][_intent.account];
        if (_sharesBurnt > _prevUserShares) revert Error.Allocate__InsufficientBalance();
        if (_amountOut > _allocation) revert Error.Allocate__InsufficientLiquidity();

        _subaccount.executeFromExecutor{gas: config.withdrawGasLimit}(
            MODE_TRY,
            ExecutionLib.encodeSingle(address(_baseToken), 0, abi.encodeCall(IERC20.transfer, (_intent.account, _amountOut)))
        );

        uint _actualOut = _allocation - _baseToken.balanceOf(address(_subaccount));
        if (_actualOut != _amountOut) revert Error.Allocate__AmountMismatch(_amountOut, _actualOut);
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
    ) internal returns (SubaccountInfo memory _info) {
        if (block.timestamp > _intent.deadline) {
            revert Error.Allocate__IntentExpired(_intent.deadline, block.timestamp);
        }

        if (keccak256(abi.encode(_positionParams)) != _intent.positionParamsHash) {
            revert Error.Allocate__NetValueParamsMismatch();
        }

        IERC7579Account _subaccount = _intent.subaccount;
        _info = registeredMap[_subaccount];
        if (address(_info.baseToken) == address(0)) revert Error.Allocate__UnregisteredSubaccount();
        if (address(_intent.token) != address(_info.baseToken)) revert Error.Allocate__TokenMismatch();
        if (tokenCapMap[_info.baseToken] == 0) revert Error.Allocate__TokenNotAllowed();

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

        uint _expectedNonce = registeredMap[_subaccount].nonce++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocate__InvalidNonce(_expectedNonce, _intent.nonce);

        if (
            !SignatureChecker.isValidSignatureNow(_intent.account, _hash, _signature)
                && (_info.signer == address(0) || !SignatureChecker.isValidSignatureNow(_info.signer, _hash, _signature))
        ) {
            revert Error.Allocate__InvalidSignature(_intent.account, _info.signer);
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.masterHook == address(0)) revert Error.Allocate__InvalidMasterHook();
        if (_config.maxPuppetList == 0) revert Error.Allocate__InvalidMaxPuppetList();
        if (_config.withdrawGasLimit == 0) revert Error.Allocate__InvalidGasLimit();
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
        if (address(registeredMap[_subaccount].baseToken) == address(0)) return;
        if (registeredMap[_subaccount].disposed) return;

        registeredMap[_subaccount].disposed = true;

        _logEvent("DisposeSubaccount", abi.encode(_subaccount));
    }

    function onUninstall(bytes calldata) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        if (address(registeredMap[_subaccount].baseToken) == address(0)) return;

        registeredMap[_subaccount].disposed = true;

        _logEvent("Uninstall", abi.encode(_subaccount));
    }
}
