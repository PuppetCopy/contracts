// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// ========================= Route ==============================
// ==============================================================
// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOrderCallbackReceiver} from "./interfaces/IOrderCallbackReceiver.sol";
import {IGMXEventUtils} from "./interfaces/IGMXEventUtils.sol";
import {IGMXOrder} from "./interfaces/IGMXOrder.sol";
import {GMXV2RouteHelper} from "./libraries/GMXV2RouteHelper.sol";
import {OrderUtils} from "./libraries/OrderUtils.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IDataStore} from "../utilities/interfaces/IDataStore.sol";
import {IBaseRoute} from "../interfaces/IBaseRoute.sol";
import {RouteReader} from "../libraries/RouteReader.sol";
import {RouteSetter} from "../libraries/RouteSetter.sol";
import {IBaseOrchestrator} from "../interfaces/IBaseOrchestrator.sol";
import {CommonHelper} from "../libraries/CommonHelper.sol";
import {SharesHelper} from "../libraries/SharesHelper.sol";
import {GMXV2OrchestratorHelper} from "./libraries/GMXV2OrchestratorHelper.sol";

/// @title Route
/// @author johnnyonline
/// @notice This contract extends the ```BaseRoute``` and is modified to fit GMX V2
contract TradeRoute is IOrderCallbackReceiver, ReentrancyGuard, IBaseRoute {
    using SafeERC20 for IERC20;
    using Address for address payable;

    IDataStore public immutable dataStore;

    /// @notice The ```constructor``` function is called on deployment
    /// @param _dataStore The dataStore contract instance
    constructor(IDataStore _dataStore) {
        dataStore = _dataStore;
    }

    /// @notice Ensures the caller is the orchestrator
    modifier onlyOrchestrator() {
        if (msg.sender != RouteReader.orchestrator(dataStore)) revert NotOrchestrator();
        _;
    }

    /// @notice Ensures the caller is the callback caller
    modifier onlyCallbackCaller() {
        if (msg.sender != _callBackCaller()) revert NotCallbackCaller();
        _;
    }

    /// @inheritdoc IBaseRoute
    function requestPosition(AdjustPositionParams memory _adjustPositionParams, SwapParams memory _swapParams, ExecutionFees memory _executionFees, bool _isIncrease) external payable onlyOrchestrator nonReentrant returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        if (RouteReader.isWaitingForCallback(_dataStore, address(this))) revert WaitingForCallback();
        if (RouteReader.isWaitingForKeeperAdjustment(_dataStore, address(this))) revert WaitingForKeeperAdjustment();

        _repayBalance(true, true, bytes32(0));

        if (_isIncrease) {
            (uint256 _puppetsAmountIn, uint256 _traderAmountIn, uint256 _traderShares, uint256 _totalSupply) = _getAssets(_swapParams, _executionFees.dexKeeper + _executionFees.puppetKeeper, _adjustPositionParams.puppets);

            RouteSetter.setTargetLeverage(_dataStore, _executionFees.puppetKeeper, _adjustPositionParams.sizeDelta, _traderAmountIn, _traderShares, _totalSupply);

            _adjustPositionParams.collateralDelta = _puppetsAmountIn + _traderAmountIn;
        }

        _requestKey = _requestPosition(_adjustPositionParams, _executionFees.dexKeeper, _isIncrease);
    }

    /// @inheritdoc IBaseRoute
    function cancelRequest(bytes32 _requestKey) external payable onlyOrchestrator {
        _cancelRequest(_requestKey);

        emit CancelRequest(_requestKey);
    }

    // called by keeper

    /// @inheritdoc IBaseRoute
    function decreaseSize(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee) external payable onlyOrchestrator nonReentrant returns (bytes32 _requestKey) {
        _requestKey = _requestPosition(_adjustPositionParams, _executionFee, false);

        RouteSetter.storeKeeperRequest(dataStore, _requestKey);

        emit DecreaseSize(_requestKey, _adjustPositionParams.sizeDelta, _adjustPositionParams.acceptablePrice);
    }

    // called by owner

    /// @inheritdoc IBaseRoute
    function forceCallback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external onlyOrchestrator nonReentrant {
        _callback(_requestKey, _isExecuted, _isIncrease);

        emit ForceCallback(_requestKey, _isExecuted, _isIncrease);
    }

    /// @inheritdoc IBaseRoute
    function rescueToken(uint256 _amount, address _token, address _receiver) external onlyOrchestrator nonReentrant {
        _token == address(0) ? payable(_receiver).sendValue(_amount) : IERC20(_token).safeTransfer(_receiver, _amount);

        emit RescueToken(_amount, _token, _receiver);
    }

    /// @notice The ```_callback``` function is triggered upon request execution
    /// @param _requestKey The request key
    /// @param _isExecuted Whether the request was executed
    /// @param _isIncrease Whether the request was an increase request
    function _callback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) internal onlyCallbackCaller nonReentrant {
        IDataStore _dataStore = dataStore;
        RouteSetter.onCallback(_dataStore, _isExecuted, _isIncrease, _requestKey);

        uint256 _performanceFeePaid = _repayBalance(_isExecuted, _isIncrease, _requestKey);

        _resetRoute();

        IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).emitExecutionCallback(_performanceFeePaid, _requestKey, _isExecuted, _isIncrease);

        emit Callback(_requestKey, _isExecuted, _isIncrease);
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    /// @notice The ```_repayBalance``` function is used to repay the Route's balance and adjust the Route's flags
    /// @param _isExecuted A boolean indicating whether the request was executed
    /// @param _isIncrease A boolean indicating whether the request is an increase request
    /// @param _requestKey The request key of the request
    /// @return _performanceFeePaid The amount of performance fee paid to the Trader
    function _repayBalance(bool _isExecuted, bool _isIncrease, bytes32 _requestKey) internal returns (uint256 _performanceFeePaid) {
        IDataStore _dataStore = dataStore;
        address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
        uint256 _totalAssets = IERC20(_collateralToken).balanceOf(address(this));
        if (_totalAssets > 0 && RouteReader.isAvailableShares(_dataStore)) {
            uint256[] memory _puppetsAssets;
            uint256 _puppetsTotalAssets;
            uint256 _traderAssets;
            (_puppetsAssets, _puppetsTotalAssets, _traderAssets, _performanceFeePaid) = RouteSetter.repayBalanceData(_dataStore, _totalAssets, _isExecuted, _isIncrease);

            address _orchestrator = RouteReader.orchestrator(_dataStore);
            IBaseOrchestrator(_orchestrator).creditAccounts(_puppetsAssets, RouteReader.puppetsInPosition(_dataStore), _collateralToken);

            IERC20(_collateralToken).safeTransfer(_orchestrator, _puppetsTotalAssets);
            IERC20(_collateralToken).safeTransfer(CommonHelper.trader(_dataStore, address(this)), _traderAssets);
        }

        if (_requestKey != bytes32(0)) {
            RouteSetter.setAdjustmentFlags(_dataStore, _isExecuted, RouteReader.isKeeperRequestKey(_dataStore, _requestKey));
        }

        /// @dev send unused execution fees to the Trader
        if (address(this).balance > msg.value) {
            uint256 _amount = address(this).balance - msg.value;
            address _wnt = CommonHelper.wnt(_dataStore);
            payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _amount);
            IERC20(_wnt).safeTransfer(CommonHelper.trader(_dataStore, address(this)), _amount);
            emit RepayWNT(_amount);
        }

        emit Repay(_totalAssets, _requestKey);
    }

    /// @notice The ```_resetRoute``` function is used to reset the Route and update user scores when the position has been closed
    function _resetRoute() internal {
        IDataStore _dataStore = dataStore;
        if (!_isOpenInterest() && CommonHelper.isPositionOpen(_dataStore, address(this))) {
            RouteSetter.resetRoute(_dataStore);
            emit ResetRoute();
        }
    }

    /// @notice The ```_approve``` function is used to approve a spender to spend a token
    /// @param _spender The address of the spender
    /// @param _token The address of the token
    /// @param _amount The amount of the token to approve
    function _approve(address _spender, address _token, uint256 _amount) internal {
        SafeERC20.forceApprove(IERC20(_token), _spender, _amount);
    }

    // ============================================================================================
    // Private Mutated Functions
    // ============================================================================================

    // @todo - refactor this is mentioend in IBaseRoute
    /// @notice The ```_getAssets``` function is used to get the assets of the Trader and Puppets and update the request accounting
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFee The execution fee paid by the Trader, in ETH
    /// @param _puppets The array of Puppts
    /// @return _puppetsAmountIn The amount of collateral the Puppets will add to the position
    /// @return _traderAmountIn The amount of collateral the Trader will add to the position
    /// @return _traderShares The amount of shares the Trader will receive
    /// @return _totalSupply The total amount of shares for the request
    function _getAssets(SwapParams memory _swapParams, uint256 _executionFee, address[] memory _puppets) private returns (uint256 _puppetsAmountIn, uint256 _traderAmountIn, uint256 _traderShares, uint256 _totalSupply) {
        if (_swapParams.amount > 0) {
            // 1. get trader assets and allocate request shares. pull funds too, if needed
            _traderAmountIn = _getTraderAssets(_swapParams, _executionFee);

            _traderShares = SharesHelper.convertToShares(0, 0, _traderAmountIn);

            // 2. get puppets assets and allocate request shares
            IDataStore _dataStore = dataStore;
            IBaseRoute.PuppetsRequest memory _puppetsRequest = RouteSetter.getPuppetsAssets(_dataStore, _traderShares, _traderAmountIn, _puppets);

            _totalSupply = _puppetsRequest.totalSupply;
            _puppetsAmountIn = _puppetsRequest.puppetsAmountIn;

            // 3. store request data
            IBaseRoute.AddCollateralRequest memory _addCollateralRequest = IBaseRoute.AddCollateralRequest({puppetsAmountIn: _puppetsAmountIn, traderAmountIn: _traderAmountIn, traderShares: _traderShares, totalSupply: _totalSupply, puppetsShares: _puppetsRequest.puppetsShares, puppetsAmounts: _puppetsRequest.puppetsAmounts});

            RouteSetter.storeNewAddCollateralRequest(_dataStore, _addCollateralRequest);

            // 4. pull funds from Orchestrator
            address _collateralToken = _swapParams.path[_swapParams.path.length - 1];
            IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).transferTokens(_puppetsAmountIn, _collateralToken);

            return (_puppetsAmountIn, _traderAmountIn, _traderShares, _totalSupply);
        }
    }

    /// @notice The ```_requestPosition``` function is used to create a position request
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The total execution fee, paid by the Trader in ETH
    /// @param _isIncrease A boolean indicating whether the request is an increase or decrease request
    /// @return _requestKey The request key of the request
    function _requestPosition(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee, bool _isIncrease) private returns (bytes32 _requestKey) {
        _requestKey = _isIncrease ? _makeRequestIncreasePositionCall(_adjustPositionParams, _executionFee) : _makeRequestDecreasePositionCall(_adjustPositionParams, _executionFee);

        RouteSetter.storePositionRequest(dataStore, _adjustPositionParams.sizeDelta, _requestKey);

        emit RequestPosition(_requestKey, _adjustPositionParams.collateralDelta, _adjustPositionParams.sizeDelta, _adjustPositionParams.acceptablePrice, _isIncrease);
    }

    // ============================================================================================
    // Receive Function
    // ============================================================================================

    receive() external payable {}

    using Address for address payable;

    // ============================================================================================
    // External Mutated Functions
    // ============================================================================================

    function claimFundingFees(address[] memory _markets, address[] memory _tokens) external onlyOrchestrator {
        GMXV2RouteHelper.gmxExchangeRouter(dataStore).claimFundingFees(_markets, _tokens, CommonHelper.trader(dataStore, address(this)));
    }

    // ============================================================================================
    // Callback Functions
    // ============================================================================================

    /// @inheritdoc IOrderCallbackReceiver
    function afterOrderExecution(bytes32 _requestKey, IGMXOrder.Props memory _order, IGMXEventUtils.EventLogData memory) external {
        if (OrderUtils.isLiquidationOrder(_order.numbers.orderType)) {
            _repayBalance(true, true, bytes32(0));
            _resetRoute();
            IBaseOrchestrator(RouteReader.orchestrator(dataStore)).emitExecutionCallback(0, bytes32(0), true, false);
            return;
        }
        _callback(_requestKey, true, OrderUtils.isIncrease(_order.numbers.orderType));

        _updateGeneratedRevenue();
    }

    function _updateGeneratedRevenue() internal {
        address _collateralToken = CommonHelper.collateralToken(dataStore, address(this));
        bytes32 _affiliateRewardKey = keccak256( // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/data/Keys.sol#L1288
            abi.encode(
                keccak256(abi.encode("AFFILIATE_REWARD")), // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/data/Keys.sol#L324
                address(GMXV2OrchestratorHelper.gmxMarketToken(dataStore, address(this))),
                _collateralToken,
                0x189b21eda0cff16461913D616a0A4F711Cd986cB // refLinkOwner (https://discord.com/channels/@me/1088765425875161130/1206958799433244813)
            )
        );
        uint256 _newBalance = GMXV2RouteHelper.gmxDataStore(dataStore).getUint(_affiliateRewardKey);
        uint256 _revenueGeneratedInCollateralToken = _newBalance - dataStore.getUint(_affiliateRewardKey);
        uint256 _revenueGeneratedInUSD = GMXV2OrchestratorHelper.getPrice(dataStore, _collateralToken) * _revenueGeneratedInCollateralToken / 1e12; // with 1e18 decimals

        address[] memory _puppets = RouteReader.puppetsInPosition(dataStore);
        uint256[] memory _puppetsShares = RouteReader.puppetsShares(dataStore);
        for (uint256 i = 0; i < _puppets.length; i++) {
            uint256 _puppetRevenue = _revenueGeneratedInUSD * _puppetsShares[i] / 1e18; // with 1e18 decimals
            dataStore.incrementUint(keccak256(abi.encode("USER_REVENUE", _puppets[i])), _puppetRevenue);
        }

        uint256 _traderRevenue = _revenueGeneratedInUSD * RouteReader.traderShares(dataStore) / 1e18; // with 1e18 decimals
        dataStore.incrementUint(keccak256(abi.encode("USER_REVENUE", address(this))), _traderRevenue);

        dataStore.setUint(_affiliateRewardKey, _newBalance);
    }

    /// @inheritdoc IOrderCallbackReceiver
    function afterOrderCancellation(bytes32 _requestKey, IGMXOrder.Props memory _order, IGMXEventUtils.EventLogData memory) external {
        _callback(_requestKey, false, OrderUtils.isIncrease(_order.numbers.orderType));
    }

    /// @inheritdoc IOrderCallbackReceiver
    /// @dev If an order is frozen, a Trader must call the ```cancelRequest``` function to cancel the order
    function afterOrderFrozen(bytes32 _requestKey, IGMXOrder.Props memory _order, IGMXEventUtils.EventLogData memory) external {}

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    function _getTraderAssets(SwapParams memory _swapParams, uint256 _executionFee) internal returns (uint256 _traderAmountIn) {
        IDataStore _dataStore = dataStore;
        if (_swapParams.path.length != 1 || _swapParams.path[0] != CommonHelper.collateralToken(_dataStore, address(this))) revert InvalidPath();

        if (msg.value - _executionFee > 0) {
            if (msg.value - _executionFee != _swapParams.amount) revert InvalidExecutionFee();
            address _wnt = CommonHelper.wnt(_dataStore);
            if (_swapParams.path[0] != _wnt) revert InvalidPath();

            payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _swapParams.amount);
        } else {
            if (msg.value != _executionFee) revert InvalidExecutionFee();

            IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).transferTokens(_swapParams.amount, _swapParams.path[0]);
        }

        return _swapParams.amount;
    }

    function _makeRequestIncreasePositionCall(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee) internal returns (bytes32 _requestKey) {
        return _makeRequestPositionCall(_adjustPositionParams, _executionFee, true);
    }

    function _makeRequestDecreasePositionCall(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee) internal returns (bytes32 _requestKey) {
        return _makeRequestPositionCall(_adjustPositionParams, _executionFee, false);
    }

    function _cancelRequest(bytes32 _requestKey) internal {
        _sendTokensToRouter(0, msg.value);
        GMXV2RouteHelper.gmxExchangeRouter(dataStore).cancelOrder(_requestKey);
    }

    // ============================================================================================
    // Private Mutated Functions
    // ============================================================================================

    function _makeRequestPositionCall(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee, bool _isIncrease) private returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        OrderUtils.CreateOrderParams memory _params = GMXV2RouteHelper.getCreateOrderParams(_dataStore, _adjustPositionParams, _executionFee, _isIncrease);

        uint256 _amountIn = 0;
        if (_isIncrease) _amountIn = _adjustPositionParams.collateralDelta;
        _sendTokensToRouter(_amountIn, _executionFee);

        return GMXV2RouteHelper.gmxExchangeRouter(_dataStore).createOrder(_params);
    }

    function _sendTokensToRouter(uint256 _amountIn, uint256 _executionFee) private {
        IDataStore _dataStore = dataStore;
        address _wnt = CommonHelper.wnt(_dataStore);
        payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _executionFee);

        address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
        if (_collateralToken == _wnt) {
            _approve(GMXV2RouteHelper.gmxRouter(_dataStore), _collateralToken, _amountIn + _executionFee);
            GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(_collateralToken, GMXV2RouteHelper.gmxOrderVault(_dataStore), _amountIn + _executionFee);
        } else {
            // send WETH for execution fee
            _approve(GMXV2RouteHelper.gmxRouter(_dataStore), _wnt, _executionFee);
            GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(_wnt, GMXV2RouteHelper.gmxOrderVault(_dataStore), _executionFee);

            if (_amountIn > 0) {
                // send collateral tokens
                _approve(GMXV2RouteHelper.gmxRouter(_dataStore), _collateralToken, _amountIn);
                GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(_collateralToken, GMXV2RouteHelper.gmxOrderVault(_dataStore), _amountIn);
            }
        }
    }

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================
    function _isOpenInterest() internal view returns (bool) {
        return GMXV2RouteHelper.isOpenInterest(dataStore);
    }

    function _callBackCaller() internal view returns (address) {
        return GMXV2RouteHelper.gmxCallBackCaller(dataStore);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error InvalidPath();
}
