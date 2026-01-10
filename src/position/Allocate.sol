// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {
    IExecutor,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {
    ModeCode,
    ModePayload,
    CALLTYPE_SINGLE,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT
} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";
import {Attest} from "../attest/Attest.sol";
import {Compact} from "../compact/Compact.sol";
import {Match} from "./Match.sol";
import {MasterInfo} from "./interface/ITypes.sol";

/// @title Allocate
/// @notice ERC-7579 Executor module for share-based fund allocation to master accounts
/// @dev Share state is globally attested (not stored on-chain) for cross-chain unified balances
contract Allocate is CoreContract, IExecutor, EIP712 {
    struct Config {
        Attest attest;
        address masterHook;
        Compact compact;
        uint allocateGasLimit;
        uint withdrawGasLimit;
    }

    struct AllocateAttestation {
        uint sharePrice;
        bytes32 puppetListHash;
        bytes32 amountListHash;
        uint nonce;
        uint deadline;
        bytes signature;
    }

    struct WithdrawAttestation {
        address user;
        IERC7579Account master;
        uint amount;
        uint sharePrice;
        uint nonce;
        uint deadline;
        bytes signature;
    }

    bytes32 public constant ALLOCATE_ATTESTATION_TYPEHASH = keccak256(
        "AllocateAttestation(address master,uint256 sharePrice,bytes32 puppetListHash,bytes32 amountListHash,uint256 nonce,uint256 deadline)"
    );

    bytes32 public constant WITHDRAW_ATTESTATION_TYPEHASH = keccak256(
        "WithdrawAttestation(address user,address master,uint256 amount,uint256 sharePrice,uint256 nonce,uint256 deadline)"
    );

    ModeCode internal constant MODE_STRICT = ModeCode.wrap(bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00))));

    Config public config;

    mapping(IERC20 token => uint) public tokenCapMap;

    /// @notice Whitelist of allowed ERC-7579 smart account implementation code hashes
    mapping(bytes32 codeHash => bool) public account7579CodeHashMap;

    mapping(IERC7579Account master => MasterInfo) public registeredMap;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Allocate", "1") {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getMasterInfo(IERC7579Account _master) external view returns (MasterInfo memory) {
        return registeredMap[_master];
    }

    function computeTokenId(address _master, address _baseToken) public pure returns (uint) {
        return uint(keccak256(abi.encode(_master, _baseToken)));
    }

    function setTokenCap(IERC20 _token, uint _cap) external auth {
        tokenCapMap[_token] = _cap;
        _logEvent("SetTokenCap", abi.encode(_token, _cap));
    }

    function setCodeHash(bytes32 _codeHash, bool _allowed) external auth {
        account7579CodeHashMap[_codeHash] = _allowed;
        _logEvent("SetCodeHash", abi.encode(_codeHash, _allowed));
    }

    function createMaster(
        address _user,
        address _signer,
        IERC7579Account _master,
        IERC20 _baseToken,
        bytes32 _name
    ) external auth {
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_master) }
        if (!account7579CodeHashMap[_codeHash]) revert Error.Allocate__InvalidAccountCodeHash();
        if (address(registeredMap[_master].baseToken) != address(0)) revert Error.Allocate__AlreadyRegistered();
        if (tokenCapMap[_baseToken] == 0) revert Error.Allocate__TokenNotAllowed();

        uint _initialBalance = _baseToken.balanceOf(address(_master));
        if (_initialBalance > tokenCapMap[_baseToken]) revert Error.Allocate__DepositExceedsCap(_initialBalance, tokenCapMap[_baseToken]);

        registeredMap[_master] = MasterInfo(_user, _signer, _baseToken, _name, false, address(0));

        _logEvent("CreateMaster", abi.encode(_master, _user, _signer, _baseToken, _name, _initialBalance));
    }

    /// @notice Allocate puppet funds to a master account
    /// @param _matcher Match contract for on-chain policy verification
    /// @param _master The master account to allocate to
    /// @param _puppetList List of puppet addresses to allocate from
    /// @param _requestedAmountList Requested amounts per puppet
    /// @param _attestation Attestor-signed share price with nonce and deadline
    function allocate(
        Match _matcher,
        IERC7579Account _master,
        address[] calldata _puppetList,
        uint[] calldata _requestedAmountList,
        AllocateAttestation calldata _attestation
    ) external auth {
        MasterInfo memory _info = registeredMap[_master];
        if (address(_info.baseToken) == address(0)) revert Error.Allocate__UnregisteredMaster();
        if (_info.disposed) revert Error.Allocate__MasterDisposed();
        if (tokenCapMap[_info.baseToken] == 0) revert Error.Allocate__TokenNotAllowed();
        if (_puppetList.length != _requestedAmountList.length) {
            revert Error.Allocate__ArrayLengthMismatch(_puppetList.length, _requestedAmountList.length);
        }

        _verifyAllocateAttestation(_master, _puppetList, _requestedAmountList, _attestation);

        IERC20 _baseToken = _info.baseToken;

        // Match puppets on-chain (checks filters, throttle, policy, balances)
        (uint[] memory _matchedAmountList, uint _totalMatched) = _matcher.recordMatchAmountList(
            _baseToken, _info.stage, address(_master), _puppetList, _requestedAmountList
        );

        if (_totalMatched == 0) revert Error.Allocate__ZeroAmount();

        uint _balanceBefore = _baseToken.balanceOf(address(_master));

        // Transfer from puppets via executeFromExecutor and build share mint lists
        uint[] memory _shareList = new uint[](_puppetList.length);
        uint _actualTotal;

        for (uint i; i < _puppetList.length; ++i) {
            if (_matchedAmountList[i] == 0) continue;

            // Calculate shares first to check for zero
            uint _shares = Precision.toFactor(_matchedAmountList[i], _attestation.sharePrice);
            if (_shares == 0) {
                _matchedAmountList[i] = 0;
                continue;
            }

            // Transfer from puppet 7579 account to master account
            try IERC7579Account(_puppetList[i]).executeFromExecutor{gas: config.allocateGasLimit}(
                MODE_STRICT,
                ExecutionLib.encodeSingle(
                    address(_baseToken), 0,
                    abi.encodeCall(IERC20.transfer, (address(_master), _matchedAmountList[i]))
                )
            ) {
                _shareList[i] = _shares;
                _actualTotal += _matchedAmountList[i];
            } catch {
                _matchedAmountList[i] = 0;
            }
        }

        if (_actualTotal == 0) revert Error.Allocate__ZeroAmount();

        // Verify transfers
        uint _actualReceived = _baseToken.balanceOf(address(_master)) - _balanceBefore;
        if (_actualReceived != _actualTotal) revert Error.Allocate__AmountMismatch(_actualTotal, _actualReceived);

        // Check token cap
        if (_balanceBefore + _actualTotal > tokenCapMap[_baseToken]) {
            revert Error.Allocate__DepositExceedsCap(_balanceBefore + _actualTotal, tokenCapMap[_baseToken]);
        }

        // Mint shares to puppets
        uint _tokenId = computeTokenId(address(_master), address(_baseToken));
        config.compact.mintMany(_puppetList, _tokenId, _shareList);

        // Calculate total shares minted and new balance
        uint _totalSharesMinted;
        for (uint i; i < _shareList.length; ++i) {
            _totalSharesMinted += _shareList[i];
        }
        uint _newMasterBalance = _balanceBefore + _actualTotal;

        _logEvent(
            "Allocate",
            abi.encode(
                _master,
                _actualTotal,
                _totalSharesMinted,
                _newMasterBalance,
                _attestation.sharePrice,
                _attestation.nonce
            )
        );
    }

    /// @notice Withdraw funds from a master account
    /// @dev Attestor validates user consent off-chain and co-signs with share price
    /// @param _attestation Attestor-signed withdrawal (includes user, amount, sharePrice)
    function withdraw(WithdrawAttestation calldata _attestation) external auth {
        IERC7579Account _master = _attestation.master;
        MasterInfo memory _info = registeredMap[_master];

        if (address(_info.baseToken) == address(0)) revert Error.Allocate__UnregisteredMaster();
        if (tokenCapMap[_info.baseToken] == 0) revert Error.Allocate__TokenNotAllowed();

        _verifyWithdrawAttestation(_attestation);

        IERC20 _baseToken = _info.baseToken;
        address _user = _attestation.user;
        uint _allocation = _baseToken.balanceOf(address(_master));

        // Calculate shares to burn for requested amount
        uint _sharesBurnt = Precision.toFactor(_attestation.amount, _attestation.sharePrice);
        if (_sharesBurnt == 0) revert Error.Allocate__ZeroShares();
        uint _amountOut = Precision.applyFactor(_attestation.sharePrice, _sharesBurnt);

        // Check user has enough shares (from Compact)
        uint _tokenId = computeTokenId(address(_master), address(_baseToken));
        uint _sharesBefore = config.compact.balanceOf(_user, _tokenId);
        if (_sharesBurnt > _sharesBefore) revert Error.Allocate__InsufficientBalance();
        if (_amountOut > _allocation) revert Error.Allocate__InsufficientLiquidity();

        // Transfer from master account to user
        _master.executeFromExecutor{gas: config.withdrawGasLimit}(
            MODE_STRICT,
            ExecutionLib.encodeSingle(
                address(_baseToken), 0, abi.encodeCall(IERC20.transfer, (_user, _amountOut))
            )
        );

        uint _actualOut = _allocation - _baseToken.balanceOf(address(_master));
        if (_actualOut != _amountOut) revert Error.Allocate__AmountMismatch(_amountOut, _actualOut);

        // Burn shares
        config.compact.burn(_user, _tokenId, _sharesBurnt);

        uint _newMasterBalance = _allocation - _amountOut;
        uint _sharesAfter = _sharesBefore - _sharesBurnt;

        _logEvent(
            "Withdraw",
            abi.encode(
                _master,
                _user,
                _amountOut,
                _sharesBurnt,
                _newMasterBalance,
                _sharesAfter,
                _attestation.sharePrice,
                _attestation.nonce
            )
        );
    }

    function disposeMaster(IERC7579Account _master) external auth {
        if (address(registeredMap[_master].baseToken) == address(0)) return;
        if (registeredMap[_master].disposed) return;

        registeredMap[_master].disposed = true;

        _logEvent("DisposeMaster", abi.encode(_master));
    }

    function _verifyAllocateAttestation(
        IERC7579Account _master,
        address[] calldata _puppetList,
        uint[] calldata _requestedAmountList,
        AllocateAttestation calldata _attestation
    ) internal {
        if (block.timestamp > _attestation.deadline) {
            revert Error.Allocate__AttestationExpired(_attestation.deadline, block.timestamp);
        }
        if (_attestation.puppetListHash != keccak256(abi.encodePacked(_puppetList))) {
            revert Error.Allocate__InvalidAttestation();
        }
        if (_attestation.amountListHash != keccak256(abi.encodePacked(_requestedAmountList))) {
            revert Error.Allocate__InvalidAttestation();
        }

        bytes32 _digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ALLOCATE_ATTESTATION_TYPEHASH,
                    _master,
                    _attestation.sharePrice,
                    _attestation.puppetListHash,
                    _attestation.amountListHash,
                    _attestation.nonce,
                    _attestation.deadline
                )
            )
        );

        config.attest.verify(_digest, _attestation.signature, _attestation.nonce);
    }

    function _verifyWithdrawAttestation(WithdrawAttestation calldata _attestation) internal {
        if (block.timestamp > _attestation.deadline) {
            revert Error.Allocate__AttestationExpired(_attestation.deadline, block.timestamp);
        }

        bytes32 _digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WITHDRAW_ATTESTATION_TYPEHASH,
                    _attestation.user,
                    _attestation.master,
                    _attestation.amount,
                    _attestation.sharePrice,
                    _attestation.nonce,
                    _attestation.deadline
                )
            )
        );

        config.attest.verify(_digest, _attestation.signature, _attestation.nonce);
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (address(_config.attest) == address(0)) revert Error.Allocate__InvalidAttestor();
        if (_config.masterHook == address(0)) revert Error.Allocate__InvalidMasterHook();
        if (address(_config.compact) == address(0)) revert Error.Allocate__InvalidCompact();
        if (_config.allocateGasLimit == 0) revert Error.Allocate__InvalidGasLimit();
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

    function onUninstall(bytes calldata) external pure {
        revert Error.Allocate__UninstallDisabled();
    }
}
