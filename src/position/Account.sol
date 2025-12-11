// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

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
    mapping(IERC20 token => uint) public depositCapMap;
    mapping(IERC20 token => uint) public unaccountedTokenBalance;

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
        if (_accountListLength != _balanceList.length) revert Error.Account__ArrayLengthMismatch();

        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }

    /**
     * @notice Deposit tokens for a user
     * @dev Validates against deposit cap and updates user balance
     */
    function deposit(IERC20 _collateralToken, address _depositor, address _user, uint _amount) external auth {
        if (_amount == 0) revert Error.Account__InvalidAmount();

        uint depositCap = depositCapMap[_collateralToken];
        if (depositCap == 0) revert Error.Account__TokenNotAllowed();

        uint nextBalance = userBalanceMap[_collateralToken][_user] + _amount;
        if (nextBalance > depositCap) revert Error.Account__DepositExceedsLimit(depositCap);

        accountStore.transferIn(_collateralToken, _depositor, _amount);
        userBalanceMap[_collateralToken][_user] = nextBalance;

        _logEvent("Deposit", abi.encode(_collateralToken, _depositor, _user, nextBalance, _amount));
    }

    /**
     * @notice Withdraw tokens for a user
     * @dev Validates sufficient balance and transfers to receiver
     */
    function withdraw(IERC20 _collateralToken, address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert Error.Account__InvalidAmount();

        uint balance = userBalanceMap[_collateralToken][_user];

        if (_amount > balance) revert Error.Account__InsufficientBalance(balance, _amount);

        uint nextBalance = balance - _amount;

        userBalanceMap[_collateralToken][_user] = nextBalance;
        accountStore.transferOut(config.transferOutGasLimit, _collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    /**
     * @notice Configure deposit caps for allowed tokens
     */
    function setDepositCapList(IERC20[] calldata _depositTokenList, uint[] calldata _depositCapList) external auth {
        if (_depositTokenList.length != _depositCapList.length) revert Error.Account__ArrayLengthMismatch();

        for (uint i = 0; i < depositTokenList.length; i++) {
            delete depositCapMap[depositTokenList[i]];
        }

        for (uint i = 0; i < _depositTokenList.length; i++) {
            IERC20 _token = _depositTokenList[i];
            uint _cap = _depositCapList[i];

            if (_cap == 0) revert Error.Account__InvalidDepositCap();
            if (address(_token) == address(0)) revert Error.Account__InvalidTokenAddress();

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
     * @param _amount The expected amount to transfer (passed by sequencer for validation)
     */
    function transferInAllocation(
        address _allocationAddress,
        IERC20 _token,
        uint _amount,
        uint _gasLimit
    ) external auth returns (uint _recordedAmountIn) {
        uint _unaccountedBalance = accountStore.recordTransferIn(_token);

        if (_unaccountedBalance > 0) {
            uint _totalUnaccounted = unaccountedTokenBalance[_token] += _unaccountedBalance;
            _logEvent("UnaccountedBalance", abi.encode(_token, _totalUnaccounted, _unaccountedBalance));
        }

        // Validate there's sufficient balance in the allocation account
        uint _actualBalance = _token.balanceOf(_allocationAddress);
        if (_actualBalance < _amount) revert Error.Account__InsufficientBalance(_actualBalance, _amount);
        if (_amount == 0) revert Error.Account__NoFundsToTransfer(_allocationAddress, address(_token));

        AllocationAccount(_allocationAddress).execute(
            address(_token), abi.encodeWithSelector(IERC20.transfer.selector, address(accountStore), _amount), _gasLimit
        );

        _recordedAmountIn = accountStore.recordTransferIn(_token);

        if (_recordedAmountIn != _amount) revert Error.Account__InvalidSettledAmount(_token, _recordedAmountIn, _amount);
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
     * @notice Recover unaccounted tokens that were sent to AccountStore outside normal flows
     * @dev Can only recover up to the tracked unaccounted balance for each token
     * @param _token The token to recover
     * @param _receiver The address to send recovered tokens to
     * @param _amount The amount to recover
     */
    function recoverUnaccountedTokens(IERC20 _token, address _receiver, uint _amount) external auth {
        if (_amount > unaccountedTokenBalance[_token]) revert Error.Account__AmountExceedsUnaccounted();
        unaccountedTokenBalance[_token] -= _amount;
        accountStore.transferOut(config.transferOutGasLimit, _token, _receiver, _amount);
        _logEvent("RecoverUnaccountedTokens", abi.encode(_token, _receiver, _amount, unaccountedTokenBalance[_token]));
    }

    /**
     * @notice Internal function to set configuration
     * @dev Required by CoreContract
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.transferOutGasLimit == 0) revert("Invalid transfer out gas limit");

        config = _config;
    }
}
