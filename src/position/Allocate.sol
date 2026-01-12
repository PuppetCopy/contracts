// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IExecutor, MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {NonceLib} from "../utils/NonceLib.sol";
import {Precision} from "../utils/Precision.sol";
import {TokenRouter} from "../shared/TokenRouter.sol";
import {Match} from "./Match.sol";
import {MasterInfo} from "./interface/ITypes.sol";

/// @title Allocate
/// @notice ERC-7579 Executor module for share-based fund allocation to master accounts
/// @dev Share state is globally attested (not stored on-chain) for cross-chain unified balances
contract Allocate is CoreContract, IExecutor, EIP712 {
    uint256 private constant _NONCE_SCOPE = 0x414C4C43;

    struct Config {
        address attestor;
        uint maxBlockStaleness;
        uint maxTimestampAge;
    }

    struct AllocateAttestation {
        IERC7579Account master;
        uint sharePrice;
        uint masterAmount;
        bytes32 puppetListHash;
        bytes32 amountListHash;
        uint blockNumber;
        uint blockTimestamp;
        uint nonce;
        uint deadline;
        bytes signature;
    }

    bytes32 public constant ALLOCATE_ATTESTATION_TYPEHASH = keccak256(
        "AllocateAttestation(address master,uint256 sharePrice,uint256 masterAmount,bytes32 puppetListHash,bytes32 amountListHash,uint256 blockNumber,uint256 blockTimestamp,uint256 nonce,uint256 deadline)"
    );

    Config public config;

    mapping(IERC20 token => uint) public tokenCapMap;
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

    function allocate(
        TokenRouter _tokenRouter,
        Match _matcher,
        IERC7579Account _master,
        address[] calldata _puppetList,
        uint[] calldata _requestedAmountList,
        AllocateAttestation calldata _attestation
    ) external auth {
        if (address(_attestation.master) != address(_master)) revert Error.Allocate__InvalidMaster();

        MasterInfo memory _info = registeredMap[_master];
        if (address(_info.baseToken) == address(0)) revert Error.Allocate__UnregisteredMaster();
        if (_info.disposed) revert Error.Allocate__MasterDisposed();
        if (tokenCapMap[_info.baseToken] == 0) revert Error.Allocate__TokenNotAllowed();
        if (_puppetList.length != _requestedAmountList.length) {
            revert Error.Allocate__ArrayLengthMismatch(_puppetList.length, _requestedAmountList.length);
        }
        if (block.timestamp > _attestation.deadline) {
            revert Error.Allocate__AttestationExpired(_attestation.deadline, block.timestamp);
        }
        if (block.number - _attestation.blockNumber > config.maxBlockStaleness) {
            revert Error.Allocate__AttestationBlockStale(_attestation.blockNumber, block.number, config.maxBlockStaleness);
        }
        if (block.timestamp - _attestation.blockTimestamp > config.maxTimestampAge) {
            revert Error.Allocate__AttestationTimestampStale(_attestation.blockTimestamp, block.timestamp, config.maxTimestampAge);
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
                    _attestation.master,
                    _attestation.sharePrice,
                    _attestation.masterAmount,
                    _attestation.puppetListHash,
                    _attestation.amountListHash,
                    _attestation.blockNumber,
                    _attestation.blockTimestamp,
                    _attestation.nonce,
                    _attestation.deadline
                )
            )
        );
        if (!SignatureCheckerLib.isValidSignatureNow(config.attestor, _digest, _attestation.signature)) {
            revert Error.Allocate__InvalidAttestation();
        }
        NonceLib.consume(_NONCE_SCOPE, _attestation.nonce);

        IERC20 _baseToken = _info.baseToken;

        (uint[] memory _matchedAmountList, uint _totalMatched) = _matcher.recordMatchAmountList(
            _baseToken, _info.stage, _master, _puppetList, _requestedAmountList
        );

        if (_totalMatched == 0 && _attestation.masterAmount == 0) revert Error.Allocate__ZeroAmount();

        uint _balanceBefore = _baseToken.balanceOf(address(_master));
        uint _allocated;
        uint _masterShares;

        if (_attestation.masterAmount > 0) {
            uint _shares = Precision.toFactor(_attestation.masterAmount, _attestation.sharePrice);
            if (_shares > 0) {
                _tokenRouter.transfer(_baseToken, _info.user, address(_master), _attestation.masterAmount);
                _allocated += _attestation.masterAmount;
                _masterShares = _shares;
            }
        }

        uint[] memory _shareList = new uint[](_puppetList.length);

        for (uint i; i < _puppetList.length; ++i) {
            if (_matchedAmountList[i] == 0) continue;

            uint _shares = Precision.toFactor(_matchedAmountList[i], _attestation.sharePrice);
            if (_shares == 0) {
                _matchedAmountList[i] = 0;
                continue;
            }

            try _tokenRouter.transfer(_baseToken, _puppetList[i], address(_master), _matchedAmountList[i]) {
                _shareList[i] = _shares;
                _allocated += _matchedAmountList[i];
            } catch {
                _matchedAmountList[i] = 0;
            }
        }

        if (_allocated == 0) revert Error.Allocate__ZeroAmount();

        uint _actualReceived = _baseToken.balanceOf(address(_master)) - _balanceBefore;
        if (_actualReceived != _allocated) revert Error.Allocate__AmountMismatch(_allocated, _actualReceived);

        uint _balance = _balanceBefore + _allocated;
        if (_balance > tokenCapMap[_baseToken]) revert Error.Allocate__DepositExceedsCap(_balance, tokenCapMap[_baseToken]);

        _logEvent(
            "Allocate",
            abi.encode(
                _master,
                _allocated,
                _masterShares,
                _puppetList,
                _matchedAmountList,
                _shareList,
                _balance,
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

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.attestor == address(0)) revert Error.Allocate__InvalidAttestor();
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
