// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {WNT} from "./utils/WNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";
import {Calc} from "./utils/Calc.sol";

import {RewardStore} from "./tokenomics/store/RewardStore.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";

import {PuppetToken} from "./tokenomics/PuppetToken.sol";
import {OracleStore} from "./tokenomics/store/OracleStore.sol";
import {OracleLogic} from "./tokenomics/OracleLogic.sol";

import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";
import {IVeRevenueDistributor} from "./utils/interfaces/IVeRevenueDistributor.sol";

contract RewardRouter is MulticallRouter {
    event RewardRouter__SetConfig(uint timestmap, RewardRouterConfig config);

    struct RewardRouterConfig {
        IVeRevenueDistributor revenueDistributor;
        RewardStore rewardStore;
        RewardLogic rewardLogic;
        OracleLogic oracleLogic;
        IUniswapV3Pool[] wntUsdPoolList;
        uint32 wntUsdTwapInterval;
        address dao;
        IERC20 revenueToken;
        bytes32 poolId;
        uint lockRate;
        uint exitRate;
        uint treasuryLockRate;
        uint treasuryExitRate;
    }

    struct RewardRouterParams {
        Dictator dictator;
        PuppetToken puppetToken;
        IVault lp;
        Router router;
        OracleStore oracleStore;
        VotingEscrow votingEscrow;
        WNT wnt;
    }

    RewardRouterConfig config;
    RewardRouterParams params;

    constructor(RewardRouterParams memory _params, RewardRouterConfig memory _config)
        MulticallRouter(_params.dictator, _params.wnt, _params.router, _config.dao)
    {
        _setConfig(_config);
        params = _params;
    }

    function lock(uint unlockTime, uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        RewardLogic.CallOptionConfig memory option = RewardLogic.CallOptionConfig({
            wntUsdPoolList: config.wntUsdPoolList,
            oracleStore: params.oracleStore,
            oracleLogic: config.oracleLogic,
            poolId: config.poolId,
            wntUsdTwapInterval: config.wntUsdTwapInterval,
            maxAcceptableTokenPriceInUsdc: maxAcceptableTokenPriceInUsdc,
            lp: params.lp,
            rewardStore: config.rewardStore,
            puppetToken: params.puppetToken,
            dao: config.dao,
            account: msg.sender,
            revenueToken: config.revenueToken,
            rate: config.lockRate,
            daoRate: config.treasuryLockRate
        });

        config.rewardLogic.lock(params.router, params.votingEscrow, option, unlockTime);
    }

    function exit(uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        RewardLogic.CallOptionConfig memory option = RewardLogic.CallOptionConfig({
            wntUsdPoolList: config.wntUsdPoolList,
            oracleStore: params.oracleStore,
            oracleLogic: config.oracleLogic,
            poolId: config.poolId,
            wntUsdTwapInterval: config.wntUsdTwapInterval,
            maxAcceptableTokenPriceInUsdc: maxAcceptableTokenPriceInUsdc,
            lp: params.lp,
            rewardStore: config.rewardStore,
            puppetToken: params.puppetToken,
            dao: config.dao,
            account: msg.sender,
            revenueToken: config.revenueToken,
            rate: config.exitRate,
            daoRate: config.treasuryExitRate
        });

        config.rewardLogic.exit(option);
    }

    function claim(address to) external nonReentrant returns (uint) {
        return config.rewardLogic.claim(config.revenueDistributor, config.revenueToken, msg.sender, to);
    }

    function veLock(address to, uint _tokenAmount, uint unlockTime) external nonReentrant {
        if (unlockTime > 0 && msg.sender != to) revert RewardRouter__AdjustOtherLock();

        params.votingEscrow.lock(msg.sender, to, _tokenAmount, unlockTime);
    }

    function veDeposit(uint value, address to) external nonReentrant {
        params.votingEscrow.depositFor(msg.sender, to, value);
    }

    function veWithdraw(address to) external nonReentrant {
        params.votingEscrow.withdraw(msg.sender, to);
    }

    // governance

    function setConfig(RewardRouterConfig memory _config) external requiresAuth {
        _setConfig(_config);
    }

    // internal

    function _setConfig(RewardRouterConfig memory _config) internal {
        if ((_config.lockRate + _config.exitRate + _config.treasuryLockRate + _config.treasuryExitRate) > Calc.BASIS_POINT_DIVISOR) {
            revert RewardRouter__InvalidWeightFactors();
        }

        if (_config.wntUsdPoolList.length % 2 == 0) revert RewardRouter__SourceCountNotOdd();
        if (_config.wntUsdPoolList.length < 3) revert RewardRouter__NotEnoughSources();

        if (_config.poolId == bytes32(0)) revert RewardRouter__InvalidPoolId();
        if (_config.dao == address(0)) revert RewardRouter__InvalidAddress();
        if (_config.revenueDistributor == IVeRevenueDistributor(address(0))) revert RewardRouter__InvalidAddress();
        if (_config.rewardStore == RewardStore(address(0))) revert RewardRouter__InvalidAddress();
        if (_config.rewardLogic == RewardLogic(address(0))) revert RewardRouter__InvalidAddress();
        if (_config.oracleLogic == OracleLogic(address(0))) revert RewardRouter__InvalidAddress();
        if (_config.revenueToken == IERC20(address(0))) revert RewardRouter__InvalidAddress();

        config = _config;

        emit RewardRouter__SetConfig(block.timestamp, _config);
    }

    error RewardRouter__AdjustOtherLock();
    error RewardRouter__InvalidWeightFactors();
    error RewardRouter__SourceCountNotOdd();
    error RewardRouter__NotEnoughSources();
    error RewardRouter__InvalidPoolId();
    error RewardRouter__InvalidAddress();
}
