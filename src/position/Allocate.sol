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
import {PositionParams, MasterAccountInfo, CallIntent} from "./interface/ITypes.sol";

/// @title Allocate
/// @notice ERC-7579 Executor module for share-based fund allocation to master accounts
contract Allocate is CoreContract, IExecutor, EIP712 {
    struct Config {
        address masterHook;
        uint maxPuppetList;
        uint withdrawGasLimit;
    }

    bytes32 public constant CALL_INTENT_TYPEHASH = keccak256(
        "CallIntent(address user,address signer,address masterAccount,address token,uint256 amount,uint256 triggerNetValue,uint256 acceptableNetValue,bytes32 positionParamsHash,uint256 deadline,uint256 nonce)"
    );

    ModeCode internal constant MODE_TRY    = ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00))));
    ModeCode internal constant MODE_STRICT = ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00))));

    Config public config;

    mapping(IERC20 token => uint) public tokenCapMap;

    /// @notice Whitelist of allowed ERC-7579 smart account implementation code hashes
    /// @dev SECURITY: Only trusted 7579 implementations should be whitelisted.
    /// The code hash is validated in createMasterAccount() to prevent malicious
    /// smart account implementations from being registered.
    ///
    /// Rhinestone SDK validator addresses (see sdk/dist/src/modules/validators/core.js):
    /// - OWNABLE_VALIDATOR (default): 0x000000000013fdb5234e4e3162a810f54d9f7e98
    /// - Nexus 1.2.0 specific:        0x00000000d12897ddadc2044614a9677b191a2d95
    ///
    /// TODO(security): Before mainnet launch:
    /// 1. Audit and whitelist specific Nexus implementation bytecode hashes
    /// 2. Document the exact factory + implementation addresses being allowed
    /// 3. Consider versioning strategy for future implementation upgrades
    /// 4. Coordinate with website/wallet.ts which must use matching SDK config
    mapping(bytes32 codeHash => bool) public account7579CodeHashMap;

    mapping(IERC7579Account masterAccount => MasterAccountInfo) public registeredMap;

    mapping(IERC7579Account masterAccount => uint) public totalSharesMap;
    mapping(IERC7579Account masterAccount => mapping(address account => uint)) public shareBalanceMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocate", "1") {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSharePrice(IERC7579Account _masterAccount, uint _totalAssets) public view returns (uint) {
        uint _totalShares = totalSharesMap[_masterAccount];
        if (_totalShares == 0) return Precision.FLOAT_PRECISION;
        if (_totalAssets == 0) revert Error.Allocate__ZeroAssets();
        return Precision.toFactor(_totalAssets, _totalShares);
    }

    function getUserShares(IERC7579Account _masterAccount, address _account) external view returns (uint) {
        return shareBalanceMap[_masterAccount][_account];
    }

    function hasRemainingShares(IERC7579Account _masterAccount) external view returns (bool) {
        return totalSharesMap[_masterAccount] > 0;
    }

    function getMasterAccountInfo(IERC7579Account _masterAccount) external view returns (MasterAccountInfo memory) {
        return registeredMap[_masterAccount];
    }

    function setTokenCap(IERC20 _token, uint _cap) external auth {
        tokenCapMap[_token] = _cap;
        _logEvent("SetTokenCap", abi.encode(_token, _cap));
    }

    function setCodeHash(bytes32 _codeHash, bool _allowed) external auth {
        account7579CodeHashMap[_codeHash] = _allowed;
        _logEvent("SetCodeHash", abi.encode(_codeHash, _allowed));
    }

    function createMasterAccount(
        address _user,
        address _signer,
        IERC7579Account _masterAccount,
        IERC20 _baseToken,
        bytes32 _name
    ) external auth {
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_masterAccount) }
        if (!account7579CodeHashMap[_codeHash]) revert Error.Allocate__InvalidAccountCodeHash();
        // Module checks removed - called from MasterHook.onInstall via UserRouter (sender check enforced there)
        // Modules may not be marked installed yet during onInstall callback
        // if (!_masterAccount.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) revert Error.Allocate__ExecutorNotInstalled();
        if (address(registeredMap[_masterAccount].baseToken) != address(0)) revert Error.Allocate__AlreadyRegistered();
        if (tokenCapMap[_baseToken] == 0) revert Error.Allocate__TokenNotAllowed();

        registeredMap[_masterAccount] = MasterAccountInfo(_user, _signer, _baseToken, _name, false, 0, address(0));

        uint _initialBalance = _baseToken.balanceOf(address(_masterAccount));
        if (_initialBalance > tokenCapMap[_baseToken]) revert Error.Allocate__DepositExceedsCap(_initialBalance, tokenCapMap[_baseToken]);
        shareBalanceMap[_masterAccount][_user] = _initialBalance;
        totalSharesMap[_masterAccount] = _initialBalance;

        _logEvent("CreateMasterAccount", abi.encode(_masterAccount, _user, _signer, _baseToken, _name, _initialBalance));
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
        IERC7579Account[] calldata _puppetList,
        uint[] calldata _amountList,
        PositionParams calldata _positionParams
    ) external auth {
        MasterAccountInfo memory _info = _verifyIntent(_intent, _signature, _positionParams);

        if (_intent.user != _info.user) revert Error.Allocate__InvalidMasterAccountOwner(_info.user, _intent.user);
        if (_intent.signer != _info.user && _intent.signer != _info.signer) revert Error.Allocate__UnauthorizedSigner(_intent.signer);
        if (_info.disposed) revert Error.Allocate__MasterAccountFrozen();
        if (_puppetList.length != _amountList.length) revert Error.Allocate__ArrayLengthMismatch(_puppetList.length, _amountList.length);
        if (_puppetList.length > config.maxPuppetList) revert Error.Allocate__PuppetListTooLarge(_puppetList.length, config.maxPuppetList);

        AllocateContext memory _ctx;
        IERC7579Account _masterAccount = _intent.masterAccount;
        IERC20 _baseToken = _info.baseToken;

        _ctx.allocation = _baseToken.balanceOf(address(_masterAccount));
        _ctx.netValue = _ctx.allocation
            + _position.getNetValue(
                address(_masterAccount), _baseToken, _positionParams.stages, _positionParams.positionKeys
            );

        if (_ctx.netValue > _intent.acceptableNetValue) revert Error.Allocate__NetValueAboveMax(_ctx.netValue, _intent.acceptableNetValue);

        _ctx.sharePrice = getSharePrice(_masterAccount, _ctx.netValue);
        _ctx.totalShares = totalSharesMap[_masterAccount];
        _ctx.userShares = shareBalanceMap[_masterAccount][_intent.user];

        if (_intent.amount != 0) {
            uint _balanceBefore = _baseToken.balanceOf(address(_masterAccount));
            if (!_baseToken.transferFrom(_intent.user, address(_masterAccount), _intent.amount)) {
                revert Error.Allocate__TransferFailed();
            }
            uint _recordedIn = _baseToken.balanceOf(address(_masterAccount)) - _balanceBefore;
            if (_recordedIn != _intent.amount) revert Error.Allocate__AmountMismatch(_intent.amount, _recordedIn);
            uint _shares = Precision.toFactor(_recordedIn, _ctx.sharePrice);
            if (_shares == 0) revert Error.Allocate__ZeroShares();
            _ctx.userShares += _shares;
            shareBalanceMap[_masterAccount][_intent.user] = _ctx.userShares;
            _ctx.totalShares += _shares;
        }

        _info.stage = _positionParams.stages.length > 0 ? address(_positionParams.stages[0]) : address(0);

        (uint[] memory _matchedAmountList, uint _totalMatched) = _match.recordMatchAmountList(
            _baseToken, _info.stage, address(_masterAccount), _puppetList, _amountList
        );

        _ctx.allocation += _intent.amount + _totalMatched;
        if (_ctx.allocation > tokenCapMap[_baseToken]) revert Error.Allocate__DepositExceedsCap(_ctx.allocation, tokenCapMap[_baseToken]);

        uint[] memory _allocatedList = new uint[](_puppetList.length);

        for (uint _i; _i < _puppetList.length; ++_i) {
            uint _amount = _matchedAmountList[_i];
            if (_amount == 0) continue;

            IERC7579Account _puppet = _puppetList[_i];
            uint _balanceBefore = _baseToken.balanceOf(address(_masterAccount));

            try _puppet.executeFromExecutor{gas: config.withdrawGasLimit}(
                MODE_TRY,
                ExecutionLib.encodeSingle(
                    address(_baseToken), 0, abi.encodeCall(IERC20.transfer, (address(_masterAccount), _amount))
                )
            ) {} catch {
                continue;
            }

            uint _transferred = _baseToken.balanceOf(address(_masterAccount)) - _balanceBefore;
            if (_transferred == 0) continue;

            uint _shares = Precision.toFactor(_transferred, _ctx.sharePrice);
            if (_shares > 0) {
                shareBalanceMap[_masterAccount][address(_puppet)] += _shares;
                _ctx.totalShares += _shares;
                _ctx.allocated += _transferred;
                _allocatedList[_i] = _transferred;
            }
        }
        totalSharesMap[_masterAccount] = _ctx.totalShares;

        _logEvent(
            "ExecuteAllocate",
            abi.encode(
                _masterAccount,
                _intent.user,
                _baseToken,
                _intent.amount,
                _puppetList,
                _allocatedList,
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
        MasterAccountInfo memory _info = _verifyIntent(_intent, _signature, _positionParams);

        if (_intent.user == _info.user) {
            if (_intent.signer != _info.user && _intent.signer != _info.signer) revert Error.Allocate__UnauthorizedSigner(_intent.signer);
        } else {
            if (_intent.signer != _intent.user) revert Error.Allocate__UnauthorizedSigner(_intent.signer);
        }

        IERC20 _baseToken = _info.baseToken;
        IERC7579Account _masterAccount = _intent.masterAccount;

        uint _allocation = _baseToken.balanceOf(address(_masterAccount));
        uint _positionValue = _position.getNetValue(
            address(_masterAccount), _baseToken, _positionParams.stages, _positionParams.positionKeys
        );
        uint _netValue = _allocation + _positionValue;

        if (_netValue < _intent.acceptableNetValue) revert Error.Allocate__NetValueBelowMin(_netValue, _intent.acceptableNetValue);

        uint _sharePrice = getSharePrice(_masterAccount, _netValue);
        uint _sharesBurnt = Precision.toFactor(_intent.amount, _sharePrice);
        if (_sharesBurnt == 0) revert Error.Allocate__ZeroShares();
        uint _amountOut = Precision.applyFactor(_sharePrice, _sharesBurnt);

        uint _prevUserShares = shareBalanceMap[_masterAccount][_intent.user];
        if (_sharesBurnt > _prevUserShares) revert Error.Allocate__InsufficientBalance();
        if (_amountOut > _allocation) revert Error.Allocate__InsufficientLiquidity();

        _masterAccount.executeFromExecutor{gas: config.withdrawGasLimit}(
            MODE_STRICT,
            ExecutionLib.encodeSingle(
                address(_baseToken), 0, abi.encodeCall(IERC20.transfer, (_intent.user, _amountOut))
            )
        );

        uint _actualOut = _allocation - _baseToken.balanceOf(address(_masterAccount));
        if (_actualOut != _amountOut) revert Error.Allocate__AmountMismatch(_amountOut, _actualOut);
        _allocation -= _actualOut;

        uint _userShares = _prevUserShares - _sharesBurnt;
        uint _totalShares = totalSharesMap[_masterAccount] - _sharesBurnt;
        shareBalanceMap[_masterAccount][_intent.user] = _userShares;
        totalSharesMap[_masterAccount] = _totalShares;

        _logEvent(
            "ExecuteWithdraw",
            abi.encode(
                _masterAccount,
                _intent.user,
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

    function disposeMasterAccount(IERC7579Account _masterAccount) external auth {
        if (address(registeredMap[_masterAccount].baseToken) == address(0)) return;
        if (registeredMap[_masterAccount].disposed) return;

        registeredMap[_masterAccount].disposed = true;

        _logEvent("DisposeMasterAccount", abi.encode(_masterAccount));
    }

    function _hashIntent(CallIntent calldata _intent) internal view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CALL_INTENT_TYPEHASH,
                    _intent.user,
                    _intent.signer,
                    _intent.masterAccount,
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
    }

    function _verifyIntent(
        CallIntent calldata _intent,
        bytes calldata _signature,
        PositionParams calldata _positionParams
    ) internal returns (MasterAccountInfo memory _masterAccountInfo) {
        if (block.timestamp > _intent.deadline) revert Error.Allocate__IntentExpired(_intent.deadline, block.timestamp);
        if (keccak256(abi.encode(_positionParams)) != _intent.positionParamsHash) revert Error.Allocate__NetValueParamsMismatch();

        IERC7579Account _masterAccount = _intent.masterAccount;
        _masterAccountInfo = registeredMap[_masterAccount];
        if (address(_masterAccountInfo.baseToken) == address(0)) revert Error.Allocate__UnregisteredMasterAccount();
        if (address(_intent.token) != address(_masterAccountInfo.baseToken)) revert Error.Allocate__TokenMismatch();
        if (tokenCapMap[_masterAccountInfo.baseToken] == 0) revert Error.Allocate__TokenNotAllowed();

        uint _expectedNonce = registeredMap[_masterAccount].nonce++;
        if (_expectedNonce != _intent.nonce) revert Error.Allocate__InvalidNonce(_expectedNonce, _intent.nonce);

        if (!SignatureChecker.isValidSignatureNow(_intent.signer, _hashIntent(_intent), _signature)) {
            revert Error.Allocate__InvalidSignature(_intent.signer);
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

    // TODO: implement proper uninstall flow (handle remaining shares, fund distribution)
    function onUninstall(bytes calldata) external pure {
        revert Error.Allocate__UninstallDisabled();
    }
}
