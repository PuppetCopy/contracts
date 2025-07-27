// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {AccountStore} from "../shared/AccountStore.sol";
import {AllocationAccount} from "../shared/AllocationAccount.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Handles user account management including deposits, withdrawals, and balance tracking
 * @dev Central contract for all account-related functionality and AllocationAccount management
 */
contract Account is CoreContract {
    struct Config {
        uint transferOutGasLimit;
    }

    AccountStore public immutable accountStore;
    address public immutable allocationAccountImplementation;

    Config config;

    // User balance tracking
    mapping(IERC20 token => mapping(address user => uint)) public userBalanceMap;

    // Deposit configuration
    IERC20[] public depositTokenList;
    mapping(IERC20 token => uint) depositCapMap;
    uint public unaccountedBalance;

    constructor(
        IAuthority _authority,
        AccountStore _accountStore,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        accountStore = _accountStore;
        allocationAccountImplementation = address(new AllocationAccount(_accountStore));
    }

    /**
     * @notice Get current configuration parameters
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Get balances for multiple users for a specific token
     */
    function getBalanceList(IERC20 _token, address[] calldata _puppetList) external view returns (uint[] memory) {
        uint _accountListLength = _puppetList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_puppetList[i]];
        }
        return _balanceList;
    }

    /**
     * @notice Get deterministic allocation account address
     */
    function getAllocationAddress(
        bytes32 _allocationKey
    ) external view returns (address) {
        return Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));
    }

    /**
     * @notice Set user balance for a specific token
     */
    function setUserBalance(IERC20 _token, address _account, uint _value) external auth {
        userBalanceMap[_token][_account] = _value;
    }

    /**
     * @notice Set balance list for multiple users and a token
     */
    function setBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _balanceList
    ) external auth {
        uint _accountListLength = _accountList.length;
        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }

    /**
     * @notice Deposit tokens for a user
     * @dev Validates against deposit cap and updates user balance
     */
    function deposit(IERC20 _collateralToken, address _depositor, address _user, uint _amount) external auth {
        require(_amount > 0, Error.Account__InvalidAmount());

        uint depositCap = depositCapMap[_collateralToken];
        require(depositCap > 0, Error.Account__TokenNotAllowed());

        uint nextBalance = userBalanceMap[_collateralToken][_user] + _amount;
        require(nextBalance <= depositCap, Error.Account__DepositExceedsLimit(depositCap));

        accountStore.transferIn(_collateralToken, _depositor, _amount);
        userBalanceMap[_collateralToken][_user] = nextBalance;

        _logEvent("Deposit", abi.encode(_collateralToken, _depositor, _user, nextBalance, _amount));
    }

    /**
     * @notice Withdraw tokens for a user
     * @dev Validates sufficient balance and transfers to receiver
     */
    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        require(_amount > 0, Error.Account__InvalidAmount());

        uint balance = userBalanceMap[_collateralToken][_user];

        require(_amount <= balance, Error.Account__InsufficientBalance());

        uint nextBalance = balance - _amount;

        userBalanceMap[_collateralToken][_user] = nextBalance;
        accountStore.transferOut(config.transferOutGasLimit, _collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    /**
     * @notice Configure deposit caps for allowed tokens
     */
    function setDepositCapList(IERC20[] calldata _depositTokenList, uint[] calldata _depositCapList) external auth {
        require(_depositTokenList.length == _depositCapList.length, "Invalid deposit token list");

        for (uint i = 0; i < depositTokenList.length; i++) {
            delete depositCapMap[depositTokenList[i]];
        }

        for (uint i = 0; i < _depositTokenList.length; i++) {
            IERC20 _token = _depositTokenList[i];
            uint _cap = _depositCapList[i];

            require(_cap > 0, "Invalid deposit cap");
            require(address(_token) != address(0), "Invalid token address");

            depositCapMap[_token] = _cap;
        }

        depositTokenList = _depositTokenList;

        _logEvent("SetDepositCapList", abi.encode(_depositTokenList, _depositCapList));
    }

    /**
     * @notice Execute a call through an AllocationAccount
     * @dev Forwards call to allocation account with specified gas limit
     */
    function execute(
        address _allocationAddress,
        address _target,
        bytes calldata _callData,
        uint _gasLimit
    ) external auth returns (bool success, bytes memory returnData) {
        return AllocationAccount(_allocationAddress).execute(_target, _callData, _gasLimit);
    }

    /**
     * @notice Transfers allocation balance to AccountStore, tracking any unaccounted funds
     * @dev Records unaccounted balances before transferring allocation funds
     */
    function transferInAllocation(
        address _allocationAddress,
        IERC20 _token,
        uint _gasLimit
    ) external auth returns (uint _recordedAmountIn) {
        uint _unaccountedBalance = accountStore.recordTransferIn(_token);

        if (_unaccountedBalance > 0) {
            unaccountedBalance += _unaccountedBalance;
            _logEvent("UnaccountedBalance", abi.encode(_token, _unaccountedBalance));
        }

        uint _settledAmount = _token.balanceOf(_allocationAddress);

        require(_settledAmount > 0, Error.Account__NoFundsToTransfer(_allocationAddress, address(_token)));

        AllocationAccount(_allocationAddress).execute(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, address(accountStore), _settledAmount),
            _gasLimit
        );

        _recordedAmountIn = accountStore.recordTransferIn(_token);

        require(
            _recordedAmountIn == _settledAmount,
            Error.Account__InvalidSettledAmount(_token, _recordedAmountIn, _settledAmount)
        );
    }
    /**
     * @notice Create a new allocation account with deterministic address
     */

    function createAllocationAccount(
        bytes32 _allocationKey
    ) external auth returns (address) {
        return Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);
    }

    /**
     * @notice Transfer tokens out through AccountStore
     */
    function transferOut(IERC20 _token, address _receiver, uint _amount) external auth {
        accountStore.transferOut(config.transferOutGasLimit, _token, _receiver, _amount);
    }

    /**
     * @notice Internal function to set configuration
     * @dev Required by CoreContract
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));
        require(_config.transferOutGasLimit > 0, "Invalid transfer out gas limit");

        config = _config;
    }
}
