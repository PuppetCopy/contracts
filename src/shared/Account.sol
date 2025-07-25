// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {PositionUtils} from "../position/utils/PositionUtils.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {AccountStore} from "./AccountStore.sol";
import {AllocationAccount} from "./AllocationAccount.sol";

/**
 * @title Account
 * @notice Handles user account management including deposits, withdrawals, and balance tracking
 * @dev Central contract for all account-related functionality and AllocationAccount management
 */
contract Account is CoreContract, ReentrancyGuardTransient {
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

    constructor(
        IAuthority _authority,
        AccountStore _accountStore,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        accountStore = _accountStore;
        allocationAccountImplementation = address(new AllocationAccount(_accountStore));
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Get balance list for multiple users and a token
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
     * @notice Set user balance for a specific token
     */
    function setUserBalance(IERC20 _token, address _account, uint _value) external auth nonReentrant {
        userBalanceMap[_token][_account] = _value;
    }

    /**
     * @notice Set balance list for multiple users and a token
     */
    function setBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _balanceList
    ) external auth nonReentrant {
        uint _accountListLength = _accountList.length;
        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }

    /**
     * @notice Deposit tokens for a user
     */
    function deposit(
        IERC20 _collateralToken,
        address _depositor,
        address _user,
        uint _amount
    ) external auth nonReentrant {
        require(_amount > 0, Error.Deposit__InvalidAmount());

        uint depositCap = depositCapMap[_collateralToken];
        require(depositCap > 0, Error.Deposit__TokenNotAllowed());

        uint nextBalance = userBalanceMap[_collateralToken][_user] + _amount;
        require(nextBalance <= depositCap, Error.Deposit__AllowanceAboveLimit(depositCap));

        accountStore.transferIn(_collateralToken, _depositor, _amount);
        userBalanceMap[_collateralToken][_user] = nextBalance;

        _logEvent("Deposit", abi.encode(_collateralToken, _depositor, _user, nextBalance, _amount));
    }

    /**
     * @notice Withdraw tokens for a user
     */
    function withdraw(
        IERC20 _collateralToken,
        address _user,
        address _receiver,
        uint _amount
    ) external auth nonReentrant {
        require(_amount > 0, Error.Deposit__InvalidAmount());

        uint balance = userBalanceMap[_collateralToken][_user];

        require(_amount <= balance, Error.Deposit__InsufficientBalance());

        uint nextBalance = balance - _amount;

        userBalanceMap[_collateralToken][_user] = nextBalance;
        accountStore.transferOut(config.transferOutGasLimit, _collateralToken, _receiver, _amount);

        _logEvent("Withdraw", abi.encode(_collateralToken, _user, _receiver, nextBalance, _amount));
    }

    /**
     * @notice Set deposit cap list for tokens
     */
    function setDepositCapList(
        IERC20[] calldata _depositTokenList,
        uint[] calldata _depositCapList
    ) external auth nonReentrant {
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
     * @param _allocationAddress The allocation account address
     * @param _target The target contract to call
     * @param _callData The call data to execute
     * @param _gasLimit The gas limit for the call
     * @return success Whether the call was successful
     * @return returnData The data returned from the call
     */
    function execute(
        address _allocationAddress,
        address _target,
        bytes calldata _callData,
        uint _gasLimit
    ) external auth nonReentrant returns (bool success, bytes memory returnData) {
        return AllocationAccount(_allocationAddress).execute(_target, _callData, _gasLimit);
    }

    /**
     * @notice Transfer tokens from allocation account to AccountStore and record the transfer
     * @param _allocationAddress The allocation account to transfer from
     * @param _token The token to transfer
     * @param _gasLimit The gas limit for the allocation account transfer
     * @return _recordedAmountIn The actual amount recorded in AccountStore
     */
    function transferInAllocation(
        address _allocationAddress,
        IERC20 _token,
        uint _gasLimit
    ) external auth nonReentrant returns (uint _recordedAmountIn) {
        uint _settledAmount = _token.balanceOf(_allocationAddress);

        (bool _success, bytes memory returnData) = AllocationAccount(_allocationAddress).execute(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, address(accountStore), _settledAmount),
            _gasLimit
        );
        require(_success, Error.Allocation__SettlementTransferFailed(address(_token), _allocationAddress));

        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "ERC20 transfer returned false");
        }

        _recordedAmountIn = accountStore.recordTransferIn(_token);

        require(
            _recordedAmountIn >= _settledAmount,
            Error.Allocation__InvalidSettledAmount(_token, _recordedAmountIn, _settledAmount)
        );
    }

    /**
     * @notice Get allocation address for given parameters
     */
    function getAllocationAddress(
        bytes32 _allocationKey
    ) external view returns (address) {
        return Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));
    }

    /**
     * @notice Create a new allocation account with a deterministic address
     * @param _allocationKey The key to derive the allocation account address
     * @return The address of the newly created allocation account
     */
    function createAllocationAccount(
        bytes32 _allocationKey
    ) external auth nonReentrant returns (address) {
        return Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);
    }

    /**
     * @notice Transfer tokens out through AccountStore
     */
    function transferOut(IERC20 _token, address _receiver, uint _amount) external auth nonReentrant {
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
