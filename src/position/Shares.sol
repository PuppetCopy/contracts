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
    enum IntentType { Deposit, Withdraw }

    struct Config {
        INpvReader npvReader;
        uint maxPuppetList;
        uint transferGasLimit;
        uint callGasLimit;
        uint virtualShareOffset;
    }

    struct Intent {
        IntentType intentType;
        address user;
        address master;
        address token;
        uint256 amount;
        uint256 acceptablePrice;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 public constant INTENT_TYPEHASH = keccak256(
        "Intent(uint8 intentType,address user,address master,address token,uint256 amount,uint256 acceptablePrice,uint256 deadline,uint256 nonce)"
    );

    Config public config;
    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => mapping(address => uint)) public userShares;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    constructor(IAuthority _authority, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
        EIP712("Puppet Shares", "1")
    {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getKey(IERC20 _token, address _master) external pure returns (bytes32) {
        return PositionUtils.getMatchingKey(_token, _master);
    }

    function getSubaccount(bytes32 _key) external view returns (address) {
        return address(subaccountMap[_key]);
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

    function getUserNpv(IERC20 _token, address _master, address _user, bytes32[] calldata _positionKeys) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _master);
        uint _shares = userShares[_key][_user];
        if (_shares == 0) return 0;

        uint _totalAssets = _calculateTotalAssets(_key, address(_token), _positionKeys);
        uint _sharePrice = getSharePrice(_key, _totalAssets);
        return Precision.applyFactor(_sharePrice, _shares);
    }

    function execute(
        Intent[] calldata _intents,
        bytes[] calldata _signatures,
        bytes32[][] calldata _positionKeys
    ) external auth {
        uint _intentCount = _intents.length;
        if (_intentCount == 0) revert Error.Allocation__ZeroAllocation();
        if (_intentCount != _signatures.length || _intentCount != _positionKeys.length) {
            revert Error.Allocation__ArrayLengthMismatch(_intentCount, _signatures.length);
        }

        for (uint _i = 0; _i < _intentCount; ++_i) {
            Intent calldata _intent = _intents[_i];

            if (block.timestamp > _intent.deadline) revert Error.Allocation__IntentExpired(_intent.deadline, block.timestamp);

            _verifyIntent(_intent, _signatures[_i]);

            bytes32 _key = PositionUtils.getMatchingKey(IERC20(_intent.token), _intent.master);
            uint _totalAssets = _calculateTotalAssets(_key, _intent.token, _positionKeys[_i]);

            if (_intent.intentType == IntentType.Deposit) {
                _executeDeposit(_intent, _key, _totalAssets);
            } else {
                _executeWithdraw(_intent, _key, _totalAssets);
            }
        }
    }

    function _calculateTotalAssets(bytes32 _key, address _token, bytes32[] calldata _positionKeys) internal view returns (uint) {
        IERC7579Account _subaccount = subaccountMap[_key];
        if (address(_subaccount) == address(0)) return 0;

        uint _total = IERC20(_token).balanceOf(address(_subaccount));

        for (uint _i = 0; _i < _positionKeys.length; ++_i) {
            int256 _npv = config.npvReader.getPositionNetValue(_positionKeys[_i]);
            if (_npv > 0) _total += uint256(_npv);
        }
        return _total;
    }

    function _executeDeposit(Intent calldata _intent, bytes32 _key, uint _totalAssets) internal {
        if (address(subaccountMap[_key]) == address(0)) {
            IERC7579Account _master = IERC7579Account(_intent.master);
            if (!_master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")) {
                revert Error.Allocation__UnregisteredSubaccount();
            }
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(IERC20(_intent.token));
        }

        uint _sharePrice = getSharePrice(_key, _totalAssets);

        if (_intent.acceptablePrice > 0 && _sharePrice > _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooHigh(_sharePrice, _intent.acceptablePrice);
        }

        bytes memory _result = _executeFromExecutor(
            IERC7579Account(_intent.user),
            _intent.token,
            config.callGasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.master, _intent.amount))
        );

        if (_result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        uint _sharesOut = Precision.toFactor(_intent.amount, _sharePrice);
        userShares[_key][_intent.user] += _sharesOut;
        totalShares[_key] += _sharesOut;

        _logEvent("Deposit", abi.encode(_key, _intent.token, _intent.master, _intent.user, _intent.amount, _sharesOut, _sharePrice));
    }

    function _executeWithdraw(Intent calldata _intent, bytes32 _key, uint _totalAssets) internal {
        uint _userBalance = userShares[_key][_intent.user];
        if (_intent.amount > _userBalance) revert Error.Allocation__InsufficientBalance(_userBalance, _intent.amount);

        uint _sharePrice = getSharePrice(_key, _totalAssets);

        if (_intent.acceptablePrice > 0 && _sharePrice < _intent.acceptablePrice) {
            revert Error.Allocation__PriceTooLow(_sharePrice, _intent.acceptablePrice);
        }

        uint _amountOut = Precision.applyFactor(_sharePrice, _intent.amount);

        uint _available = IERC20(_intent.token).balanceOf(address(subaccountMap[_key]));
        if (_amountOut > _available) revert Error.Allocation__InsufficientBalance(_available, _amountOut);

        userShares[_key][_intent.user] -= _intent.amount;
        totalShares[_key] -= _intent.amount;

        bytes memory _result = _executeFromExecutor(
            subaccountMap[_key],
            _intent.token,
            config.transferGasLimit,
            abi.encodeCall(IERC20.transfer, (_intent.user, _amountOut))
        );

        if (_result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

        _logEvent("Withdraw", abi.encode(_key, _intent.token, _intent.master, _intent.user, _intent.amount, _amountOut, _sharePrice));
    }

    function _verifyIntent(Intent calldata _intent, bytes calldata _signature) internal {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
            INTENT_TYPEHASH,
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

    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gas, bytes memory _data) internal returns (bytes memory) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gas}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            return _results[0];
        } catch {
            return "";
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
