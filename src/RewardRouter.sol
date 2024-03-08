// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {MulticallRouter} from "./utilities/MulticallRouter.sol";
import {WNT} from "./utilities/common/WNT.sol";
import {Router} from "./utilities/Router.sol";
import {Dictator} from "./utilities/Dictator.sol";
import {IDataStore} from "./integrations/utilities/interfaces/IDataStore.sol";
import {IVeRevenueDistributor} from "./utilities/interfaces/IVeRevenueDistributor.sol";

import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";
import {PuppetToken} from "./tokenomics/PuppetToken.sol";
import {OracleStore} from "./tokenomics/store/OracleStore.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {OracleLogic} from "./tokenomics/OracleLogic.sol";


contract RewardRouter is MulticallRouter {
    event RewardRouter__WeightRateSet(uint lockRate, uint exitRate, uint treasuryLockRate, uint treasuryExitRate);

    uint internal constant BASIS_POINT_DIVISOR = 10000;

    struct RewardRouterParams {
        Dictator dictator;
        PuppetToken puppetToken;
        IVault lp;
        Router router;
        OracleStore oracleStore;
        VotingEscrow votingEscrow;
        WNT wnt;
    }

    struct RewardRouterConfigParams {
        IVeRevenueDistributor revenueDistributor;
        IDataStore dataStore;
        RewardLogic rewardLogic;
        OracleLogic oracleLogic;
        IUniswapV3Pool[] wntUsdPoolList;
        uint32 wntUsdTwapInterval;
        address dao;
        IERC20 revenueInToken;
        bytes32 poolId;
        uint lockRate;
        uint exitRate;
        uint treasuryLockRate;
        uint treasuryExitRate;
    }

    RewardRouterParams params;
    RewardRouterConfigParams config;

    constructor(RewardRouterParams memory _params, RewardRouterConfigParams memory _config)
        MulticallRouter(_params.dictator, _params.wnt, _params.router, _config.dao)
    {
        params = _params;
        config = _config;
    }

    function lock(uint unlockTime, uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        uint tokenPrice = config.oracleLogic.syncTokenPrice(config.wntUsdPoolList, params.lp, params.oracleStore, config.poolId, config.wntUsdTwapInterval);

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice();

        RewardLogic.OptionParams memory option = RewardLogic.OptionParams({
            dataStore: config.dataStore,
            puppetToken: params.puppetToken,
            dao: config.dao,
            account: msg.sender,
            revenueInToken: config.revenueInToken,
            rate: config.lockRate,
            daoRate: config.treasuryLockRate,
            tokenPrice: tokenPrice
        });

        config.rewardLogic.lock(params.router, params.votingEscrow, option, unlockTime);
    }

    function exit(uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        uint tokenPrice = config.oracleLogic.syncTokenPrice(config.wntUsdPoolList, params.lp, params.oracleStore, config.poolId, config.wntUsdTwapInterval);

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice();

        RewardLogic.OptionParams memory option = RewardLogic.OptionParams({
            dataStore: config.dataStore,
            puppetToken: params.puppetToken,
            dao: config.dao,
            account: msg.sender,
            revenueInToken: config.revenueInToken,
            rate: config.exitRate,
            daoRate: config.treasuryExitRate,
            tokenPrice: tokenPrice
        });

        config.rewardLogic.exit(option);
    }

    function claim(address to) external nonReentrant returns (uint) {
        return config.rewardLogic.claim(config.revenueDistributor, config.revenueInToken, msg.sender, to);
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

    function setRewardLogic(RewardLogic rewardLogic) external requiresAuth {
        config.rewardLogic = rewardLogic;
    }

    function setPriceLogic(OracleLogic priceLogic) external requiresAuth {
        config.oracleLogic = priceLogic;
    }

    function setDataStore(IDataStore dataStore) external requiresAuth {
        config.dataStore = dataStore;
    }

    function configDaoAddress(address daoAddress) external requiresAuth {
        config.dao = daoAddress;
    }

    function configOptionDistributionRate(uint _lockRate, uint _exitRate, uint _treasuryLockRate, uint _treasuryExitRate) external requiresAuth {
        if (_lockRate + _exitRate + _treasuryLockRate + _treasuryExitRate != BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        config.lockRate = _lockRate;
        config.exitRate = _exitRate;
        config.treasuryLockRate = _treasuryLockRate;
        config.treasuryExitRate = _treasuryExitRate;

        emit RewardRouter__WeightRateSet(_lockRate, _exitRate, _treasuryLockRate, _treasuryExitRate);
    }

    function configRevenueInToken(IERC20 revenueInToken) external requiresAuth {
        config.revenueInToken = revenueInToken;
    }

    function configPoolId(IVault vault, bytes32 poolId) external requiresAuth {
        (address poolAddress,) = vault.getPool(poolId);
        if (poolAddress == address(0)) revert RewardRouter__PoolDoesNotExit();

        config.poolId = poolId;
    }

    function configWntUsdPoolList(IUniswapV3Pool[] memory wntUsdPoolList) external requiresAuth {
        if (wntUsdPoolList.length % 2 == 0) revert RewardRouter__SourceCountNotOdd();
        if (wntUsdPoolList.length < 3) revert RewardRouter__NotEnoughSources();

        config.wntUsdPoolList = wntUsdPoolList;
    }

    function configWntUsdTwapInterval(uint32 twapInterval) external requiresAuth {
        config.wntUsdTwapInterval = twapInterval;
    }

    error RewardRouter__AdjustOtherLock();
    error RewardRouter__UnacceptableTokenPrice();
    error RewardRouter__InvalidWeightFactors();
    error RewardRouter__SourceCountNotOdd();
    error RewardRouter__NotEnoughSources();
    error RewardRouter__PoolDoesNotExit();
}
