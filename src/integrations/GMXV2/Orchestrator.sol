// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ======================== Orchestrator ========================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGMXV2Route} from "./interfaces/IGMXV2Route.sol";
import {IWETH} from "../../utilities/interfaces/IWETH.sol";
import {GlobalReentrancyGuard} from "../utilities/GlobalReentrancyGuard.sol";
import {IDataStore} from "../utilities/interfaces/IDataStore.sol";
import {TradeRoute} from "./TradeRoute.sol";
import {CommonHelper} from "../libraries/CommonHelper.sol";
import {OrchestratorHelper} from "../libraries/OrchestratorHelper.sol";
import {GMXV2OrchestratorHelper} from "./libraries/GMXV2OrchestratorHelper.sol";
import {Keys} from "../libraries/Keys.sol";

/// @title Orchestrator
/// @author johnnyonline
/// @notice This contract extends the ```BaseOrchestrator``` and is modified to fit GMX V2
contract Orchestrator is Auth, GlobalReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint public constant MAX_FEE = 1000; // 10% max fee

    bool private _initialized;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _authority The Authority contract instance
    /// @param _dataStore The dataStore contract address
    constructor(Authority _authority, IDataStore _dataStore) Auth(address(0), _authority) GlobalReentrancyGuard(_dataStore) {}

    // ============================================================================================
    // Modifiers
    // ============================================================================================

    /// @notice Ensures the caller is a Route
    modifier onlyRoute() {
        if (!CommonHelper.isRouteRegistered(dataStore, msg.sender)) revert NotRoute();
        _;
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function positionKey(address _route) public view returns (bytes32) {
        return GMXV2OrchestratorHelper.positionKey(dataStore, _route);
    }

    function positionAmounts(address _route) external view returns (uint, uint) {
        return GMXV2OrchestratorHelper.positionAmounts(dataStore, _route);
    }

    function getPrice(address _token) external view returns (uint) {
        return GMXV2OrchestratorHelper.getPrice(dataStore, _token);
    }

    function isWaitingForCallback(bytes32 _routeKey) external view returns (bool) {
        return GMXV2OrchestratorHelper.isWaitingForCallback(dataStore, _routeKey);
    }

    // ============================================================================================
    // Trader Function
    // ============================================================================================

    function registerRoute(bytes32 _routeTypeKey) public globalNonReentrant requiresAuth returns (bytes32) {
        (address _route, bytes32 _routeKey) = OrchestratorHelper.registerRoute(dataStore, msg.sender, _routeTypeKey);

        emit RegisterRoute(msg.sender, _route);

        return _routeKey;
    }

    function requestPosition(
        TradeRoute.AdjustPositionParams memory _adjustPositionParams,
        TradeRoute.SwapParams memory _swapParams,
        TradeRoute.ExecutionFees memory _executionFees,
        bytes32 _routeTypeKey,
        bool _isIncrease
    ) public payable globalNonReentrant requiresAuth returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validateExecutionFees(_dataStore, _swapParams, _executionFees);

        address _route = OrchestratorHelper.validateRouteKey(_dataStore, CommonHelper.routeKey(_dataStore, msg.sender, _routeTypeKey));

        OrchestratorHelper.validatePuppets(_dataStore, _route, _adjustPositionParams.puppets);

        if (_isIncrease && msg.value == _executionFees.dexKeeper + _executionFees.puppetKeeper) {
            IERC20(_swapParams.path[0]).safeTransferFrom(msg.sender, address(this), _swapParams.amount);
        }

        _requestKey = TradeRoute(_route).requestPosition{value: msg.value}(_adjustPositionParams, _swapParams, _executionFees, _isIncrease);

        emit RequestPosition(_adjustPositionParams.puppets, msg.sender, _route, _isIncrease, _requestKey, _routeTypeKey, positionKey(_route));
    }

    function cancelRequest(bytes32 _routeTypeKey, bytes32 _requestKey) external payable globalNonReentrant requiresAuth {
        IDataStore _dataStore = dataStore;
        if (msg.value == 0 || msg.value < CommonHelper.minExecutionFee(_dataStore)) revert InvalidExecutionFee();

        address _route = OrchestratorHelper.validateRouteKey(_dataStore, CommonHelper.routeKey(_dataStore, msg.sender, _routeTypeKey));

        TradeRoute(_route).cancelRequest{value: msg.value}(_requestKey);

        emit CancelRequest(_route, _requestKey);
    }

    function registerRouteAndRequestPosition(
        TradeRoute.AdjustPositionParams memory _adjustPositionParams,
        TradeRoute.SwapParams memory _swapParams,
        TradeRoute.ExecutionFees memory _executionFees,
        bytes32 _routeTypeKey
    ) external payable returns (bytes32 _routeKey, bytes32 _requestKey) {
        _routeKey = registerRoute(_routeTypeKey);

        _requestKey = requestPosition(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, true);
    }

    // ============================================================================================
    // Puppet Functions
    // ============================================================================================

    function subscribe(uint _allowance, uint _expiry, address _puppet, address _trader, bytes32 _routeTypeKey)
        public
        globalNonReentrant
        requiresAuth
    {
        address _route = OrchestratorHelper.updateSubscription(dataStore, _expiry, _allowance, msg.sender, _trader, _puppet, _routeTypeKey);

        emit Subscribe(_allowance, _expiry, _trader, _puppet, _route, _routeTypeKey);
    }

    function batchSubscribe(
        address _puppet,
        uint[] memory _allowances,
        uint[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys
    ) public requiresAuth {
        if (_traders.length != _allowances.length) revert MismatchedInputArrays();
        if (_traders.length != _expiries.length) revert MismatchedInputArrays();
        if (_traders.length != _routeTypeKeys.length) revert MismatchedInputArrays();

        for (uint i = 0; i < _traders.length; i++) {
            subscribe(_allowances[i], _expiries[i], _puppet, _traders[i], _routeTypeKeys[i]);
        }
    }

    function deposit(uint _amount, address _token, address _receiver) public payable globalNonReentrant requiresAuth {
        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validatePuppetInput(_dataStore, _amount, _receiver, _token);

        if (msg.value > 0) {
            if (_amount != msg.value) revert InvalidAmount();
            if (_token != CommonHelper.wnt(_dataStore)) revert InvalidAsset();
        }

        _creditAccount(_amount, _token, _receiver);

        if (msg.value > 0) {
            payable(_token).functionCallWithValue(abi.encodeWithSignature("deposit()"), _amount);
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        emit Deposit(_amount, _token, msg.sender, _receiver);
    }

    function depositAndBatchSubscribe(
        uint _amount,
        address _token,
        address _puppet,
        uint[] memory _allowances,
        uint[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys
    ) external payable {
        deposit(_amount, _token, _puppet);

        batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
    }

    function withdraw(uint _amount, address _token, address _receiver, bool _isETH) external globalNonReentrant returns (uint _amountOut) {
        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validatePuppetInput(_dataStore, _amount, _receiver, _token);

        if (_isETH && _token != CommonHelper.wnt(_dataStore)) revert InvalidAsset();

        _amountOut = _debitAccount(_amount, _token, msg.sender, true);

        if (_isETH) {
            IWETH(_token).withdraw(_amountOut);
            payable(_receiver).sendValue(_amountOut);
        } else {
            IERC20(_token).safeTransfer(_receiver, _amountOut);
        }

        emit Withdraw(_amountOut, _token, _receiver, msg.sender);
    }

    function setThrottleLimit(uint _throttleLimit, bytes32 _routeType) external globalNonReentrant requiresAuth {
        dataStore.setUint(Keys.puppetThrottleLimitKey(msg.sender, _routeType), _throttleLimit);

        emit SetThrottleLimit(msg.sender, _routeType, _throttleLimit);
    }

    // ============================================================================================
    // Route Functions
    // ============================================================================================

    function debitAccounts(uint[] memory _amounts, address[] memory _puppets, address _token) external onlyRoute {
        if (_amounts.length != _puppets.length) revert MismatchedInputArrays();

        for (uint i = 0; i < _puppets.length; i++) {
            _debitAccount(_amounts[i], _token, _puppets[i], false);
        }
    }

    function creditAccounts(uint[] memory _amounts, address[] memory _puppets, address _token) external onlyRoute {
        if (_amounts.length != _puppets.length) revert MismatchedInputArrays();

        for (uint i = 0; i < _puppets.length; i++) {
            _creditAccount(_amounts[i], _token, _puppets[i]);
        }
    }

    function updateLastPositionOpenedTimestamp(address[] memory _puppets) external onlyRoute {
        bytes32 _routeType = OrchestratorHelper.updateLastPositionOpenedTimestamp(dataStore, msg.sender, _puppets);

        emit UpdateOpenTimestamp(_puppets, _routeType);
    }

    function transferTokens(uint _amount, address _token) external onlyRoute {
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit TransferTokens(_amount, _token, msg.sender);
    }

    function emitExecutionCallback(uint _performanceFeePaid, bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external onlyRoute {
        emit ExecutePosition(_performanceFeePaid, msg.sender, _requestKey, _isExecuted, _isIncrease);
    }

    function emitSharesIncrease(uint[] memory _puppetsShares, uint _traderShares, uint _totalSupply, bytes32 _requestKey) external onlyRoute {
        emit SharesIncrease(_puppetsShares, _traderShares, _totalSupply, msg.sender, _requestKey);
    }

    // ============================================================================================
    // Authority Functions
    // ============================================================================================

    // called by keeper

    function decreaseSize(TradeRoute.AdjustPositionParams memory _adjustPositionParams, uint _executionFee, bytes32 _routeKey)
        external
        requiresAuth
        globalNonReentrant
        returns (bytes32 _requestKey)
    {
        address _route = OrchestratorHelper.validateRouteKey(dataStore, _routeKey);

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, _executionFee, false);

        _requestKey = TradeRoute(_route).decreaseSize{value: _executionFee}(_adjustPositionParams, _executionFee);

        emit DecreaseSize(_route, _requestKey, _routeKey, positionKey(_route));
    }

    // called by owner
    function updateDexAddresses(bytes memory _data) external requiresAuth {
        GMXV2OrchestratorHelper.updateGMXAddresses(dataStore, _data);
    }

    function initialize(uint _minExecutionFee, address _wnt, address _platformFeeRecipient, address _routeFactory, bytes memory _data)
        external
        requiresAuth
    {
        if (_initialized) revert AlreadyInitialized();
        if (_platformFeeRecipient == address(0)) revert ZeroAddress();
        if (_routeFactory == address(0)) revert ZeroAddress();

        _initialized = true;

        OrchestratorHelper.setInitializeData(dataStore, _minExecutionFee, _wnt, _platformFeeRecipient, _routeFactory);

        _initialize(_data);

        emit Initialize(_platformFeeRecipient, _routeFactory);
    }

    function claimFundingFees(address _route, address[] memory _markets, address[] memory _tokens) external {
        if (msg.sender != CommonHelper.trader(dataStore, _route)) revert OnlyTrader();
        IGMXV2Route(_route).claimFundingFees(_markets, _tokens);
    }

    function depositExecutionFees() external payable {
        if (msg.value == 0) revert InvalidAmount();

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, msg.value, true);

        emit DepositExecutionFees(msg.value);
    }

    function withdrawExecutionFees(uint _amount, address _receiver) external requiresAuth {
        if (_amount == 0) revert ZeroAmount();
        if (_receiver == address(0)) revert ZeroAddress();

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, _amount, false);

        payable(_receiver).sendValue(_amount);

        emit WithdrawExecutionFees(_amount, _receiver);
    }

    function withdrawPlatformFees(address _token) external globalNonReentrant {
        (uint _balance, address _platformFeeRecipient) = OrchestratorHelper.withdrawPlatformFees(dataStore, _token);
        IERC20(_token).safeTransfer(_platformFeeRecipient, _balance);

        emit WithdrawPlatformFees(_balance, _token);
    }

    function setRouteType(address _collateralToken, address _indexToken, bool _isLong, bytes memory _data) external requiresAuth {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_indexToken == address(0)) revert ZeroAddress();

        bytes32 _routeTypeKey = Keys.routeTypeKey(_collateralToken, _indexToken, _isLong, _data);
        OrchestratorHelper.setRouteType(dataStore, _routeTypeKey, _collateralToken, _indexToken, _isLong, _data);

        emit SetRouteType(_routeTypeKey, _collateralToken, _indexToken, _isLong, _data);
    }

    function updateRouteFactory(address _routeFactory) external requiresAuth {
        if (_routeFactory == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.ROUTE_FACTORY, _routeFactory);

        emit UpdateRouteFactory(_routeFactory);
    }

    function updateMultiSubscriber(address _multiSubscriber) external requiresAuth {
        if (_multiSubscriber == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.MULTI_SUBSCRIBER, _multiSubscriber);

        emit UpdateMultiSubscriber(_multiSubscriber);
    }

    function updateScoreGauge(address _gauge) external requiresAuth {
        if (_gauge == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.SCORE_GAUGE, _gauge);

        emit UpdateScoreGauge(_gauge);
    }

    function updateReferralCode(bytes32 _referralCode) external requiresAuth {
        if (_referralCode == bytes32(0)) revert ZeroBytes32();

        dataStore.setBytes32(Keys.REFERRAL_CODE, _referralCode);

        emit UpdateReferralCode(_referralCode);
    }

    function updatePlatformFeesRecipient(address _recipient) external requiresAuth {
        if (_recipient == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.PLATFORM_FEES_RECIPIENT, _recipient);

        emit UpdateFeesRecipient(_recipient);
    }

    function updatePauseStatus(bool _paused) external requiresAuth {
        dataStore.setBool(Keys.PAUSED, _paused);

        emit UpdatePauseStatus(_paused);
    }

    function updateMinExecutionFee(uint _minExecutionFee) external requiresAuth {
        if (_minExecutionFee == 0) revert ZeroAmount();

        dataStore.setUint(Keys.MIN_EXECUTION_FEE, _minExecutionFee);

        emit UpdateMinExecutionFee(_minExecutionFee);
    }

    function updatePuppetKeeperMinExecutionFee(uint _puppetKeeperMinExecutionFee) external requiresAuth {
        if (_puppetKeeperMinExecutionFee == 0) revert ZeroAmount();

        dataStore.setUint(Keys.PUPPET_KEEPER_MIN_EXECUTION_FEE, _puppetKeeperMinExecutionFee);

        emit UpdatePuppetKeeperMinExecutionFee(_puppetKeeperMinExecutionFee);
    }

    function updateMaxPuppets(uint _maxPuppets) external requiresAuth {
        if (_maxPuppets == 0) revert ZeroAmount();

        dataStore.setUint(Keys.MAX_PUPPETS, _maxPuppets);

        emit UpdateMaxPuppets(_maxPuppets);
    }

    function updateFees(uint _managementFee, uint _withdrawalFee, uint _performanceFee) external requiresAuth {
        if (_managementFee > MAX_FEE || _withdrawalFee > MAX_FEE || _performanceFee > MAX_FEE) revert FeeExceedsMax();

        IDataStore _dataStore = dataStore;
        _dataStore.setUint(Keys.MANAGEMENT_FEE, _managementFee);
        _dataStore.setUint(Keys.WITHDRAWAL_FEE, _withdrawalFee);
        _dataStore.setUint(Keys.PERFORMANCE_FEE, _performanceFee);

        emit UpdateFees(_managementFee, _withdrawalFee, _performanceFee);
    }

    function forceCallback(address _route, bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external requiresAuth {
        if (_route == address(0)) revert ZeroAddress();

        TradeRoute(_route).forceCallback(_requestKey, _isExecuted, _isIncrease);

        emit ForceCallback(_route, _requestKey, _isExecuted, _isIncrease);
    }

    function rescueToken(uint _amount, address _token, address _receiver, address _route) external requiresAuth {
        if (_amount == 0 || _token == address(0) || _receiver == address(0) || _route == address(0)) revert ZeroAddress();

        TradeRoute(_route).rescueToken(_amount, _token, _receiver);

        emit RescueToken(_amount, _token, _receiver, _route);
    }

    function _initialize(bytes memory _data) internal {
        GMXV2OrchestratorHelper.updateGMXAddresses(dataStore, _data);
    }

    /// @notice The ```_debitAccount``` function debits a Puppet's account
    /// @param _amount The amount to debit
    /// @param _token The token address
    /// @param _puppet The Puppet address
    /// @param _isWithdraw The boolean indicating if the debit is a withdraw or for investing in a position
    /// @return _amountOut The amount out, after fees
    function _debitAccount(uint _amount, address _token, address _puppet, bool _isWithdraw) private returns (uint _amountOut) {
        uint _feeAmount = OrchestratorHelper.debitPuppetAccount(dataStore, _amount, _token, _puppet, _isWithdraw);

        _amountOut = _amount - _feeAmount;

        emit DebitPuppet(_amount + _feeAmount, _token, _puppet, msg.sender);
        emit CreditPlatform(_feeAmount, _token, _puppet, msg.sender, _isWithdraw);
    }

    /// @notice The ```_creditAccount``` function credits a Puppet's account
    /// @param _amount The amount to credit
    /// @param _token The token address
    /// @param _puppet The Puppet address
    function _creditAccount(uint _amount, address _token, address _puppet) private {
        dataStore.incrementUint(Keys.puppetDepositAccountKey(_puppet, _token), _amount);

        emit CreditPuppet(_amount, _token, _puppet, msg.sender);
    }

    error OnlyTrader();

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterRoute(address indexed trader, address indexed route);
    event RequestPosition(
        address[] puppets,
        address indexed trader,
        address indexed route,
        bool isIncrease,
        bytes32 requestKey,
        bytes32 routeTypeKey,
        bytes32 positionKey
    );
    event CancelRequest(address indexed route, bytes32 requestKey);

    event Subscribe(uint allowance, uint expiry, address indexed trader, address indexed puppet, address indexed route, bytes32 routeTypeKey);
    event Deposit(uint amount, address asset, address caller, address indexed receiver);
    event Withdraw(uint amountOut, address asset, address indexed receiver, address indexed puppet);
    event SetThrottleLimit(address indexed puppet, bytes32 routeType, uint throttleLimit);

    event UpdateOpenTimestamp(address[] puppets, bytes32 routeType);
    event TransferTokens(uint amount, address asset, address indexed caller);
    event ExecutePosition(uint performanceFeePaid, address indexed route, bytes32 requestKey, bool isExecuted, bool isIncrease);
    event SharesIncrease(uint[] puppetsShares, uint traderShares, uint totalSupply, address route, bytes32 requestKey);
    event DecreaseSize(address indexed route, bytes32 requestKey, bytes32 routeKey, bytes32 positionKey);

    event Initialize(address platformFeeRecipient, address routeFactory);
    event DepositExecutionFees(uint amount);
    event WithdrawExecutionFees(uint amount, address receiver);
    event WithdrawPlatformFees(uint amount, address asset);

    event SetRouteType(bytes32 routeTypeKey, address collateral, address index, bool isLong, bytes data);
    event UpdateRouteFactory(address routeFactory);
    event UpdateMultiSubscriber(address multiSubscriber);
    event UpdateScoreGauge(address scoreGauge);
    event UpdateReferralCode(bytes32 referralCode);
    event UpdateFeesRecipient(address recipient);
    event UpdatePauseStatus(bool paused);
    event UpdateMinExecutionFee(uint minExecutionFee);
    event UpdatePuppetKeeperMinExecutionFee(uint puppetKeeperMinExecutionFee);
    event UpdateMaxPuppets(uint maxPuppets);
    event UpdateFees(uint managmentFee, uint withdrawalFee, uint performanceFee);
    event ForceCallback(address route, bytes32 requestKey, bool isExecuted, bool isIncrease);
    event RescueToken(uint amount, address token, address indexed receiver, address indexed route);

    event DebitPuppet(uint amount, address asset, address indexed puppet, address indexed caller);
    event CreditPlatform(uint amount, address asset, address puppet, address caller, bool isWithdraw);
    event CreditPuppet(uint amount, address asset, address indexed puppet, address indexed caller);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error MismatchedInputArrays();
    error RouteNotRegistered();
    error InvalidAmount();
    error InvalidAsset();
    error ZeroAddress();
    error ZeroBytes32();
    error ZeroAmount();
    error FunctionCallPastDeadline();
    error NotWhitelisted();
    error FeeExceedsMax();
    error AlreadyInitialized();
    error InvalidExecutionFee();
    error InvalidPath();
    error Paused();
    error NotRoute();
}
