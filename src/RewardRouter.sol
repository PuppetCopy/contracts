// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {IWNT} from "./utils/interfaces/IWNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";
import {Calc} from "./utils/Calc.sol";

import {OracleLogic} from "./tokenomics/OracleLogic.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";
import {IVeRevenueDistributor} from "./utils/interfaces/IVeRevenueDistributor.sol";

contract RewardRouter is MulticallRouter {
    event RewardRouter__SetConfig(
        uint timestmap, OracleLogic.CallConfig callOracleConfig, RewardLogic.CallLockConfig callLockConfig, RewardLogic.CallExitConfig callExitConfig
    );

    OracleLogic.CallConfig public callOracleConfig;
    RewardLogic.CallLockConfig public callLockConfig;
    RewardLogic.CallExitConfig public callExitConfig;

    VotingEscrow votingEscrow;
    IVeRevenueDistributor revenueDistributor;

    constructor(
        Dictator _dictator,
        IWNT _wnt,
        Router _router,
        VotingEscrow _votingEscrow,
        IVeRevenueDistributor _revenueDistributor,
        OracleLogic.CallConfig memory _callOracleConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig
    ) MulticallRouter(_dictator, _wnt, _router, _dictator.owner()) {
        votingEscrow = _votingEscrow;
        revenueDistributor = _revenueDistributor;

        _setConfig(_callOracleConfig, _callLockConfig, _callExitConfig);
    }

    function lock(IERC20[] calldata revenueTokenList, uint maxAcceptableTokenPriceInUsdc, uint unlockTime) public nonReentrant {
        (,, uint tokenPrice) = OracleLogic.syncPrices(callOracleConfig);

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice(tokenPrice, maxAcceptableTokenPriceInUsdc);

        RewardLogic.lock(callLockConfig, revenueTokenList, tokenPrice, msg.sender, unlockTime);
    }

    function exit(IERC20[] calldata revenueTokenList, uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        (,, uint tokenPrice) = OracleLogic.syncPrices(callOracleConfig);

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice(tokenPrice, maxAcceptableTokenPriceInUsdc);

        RewardLogic.exit(callExitConfig, revenueTokenList, tokenPrice, msg.sender);
    }

    function claim(IERC20 token, address to) external nonReentrant {
        RewardLogic.claim(revenueDistributor, token, msg.sender, to);
    }

    function veLock(uint _tokenAmount, uint unlockTime) external nonReentrant {
        votingEscrow.lock(msg.sender, msg.sender, _tokenAmount, unlockTime);
    }

    function veDeposit(address to, uint value) external nonReentrant {
        votingEscrow.depositFor(msg.sender, to, value);
    }

    function veWithdraw(address to) external nonReentrant {
        votingEscrow.withdraw(msg.sender, to);
    }

    // integration

    function syncPrices() public nonReentrant {
        OracleLogic.syncPrices(callOracleConfig);
    }

    // governance

    function setConfig(
        OracleLogic.CallConfig memory _callOracleConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig
    ) external requiresAuth {
        _setConfig(_callOracleConfig, _callLockConfig, _callExitConfig);
    }

    // internal

    function _setConfig(
        OracleLogic.CallConfig memory _callOracleConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig
    ) internal {
        if (_callOracleConfig.wntUsdSourceList.length % 2 == 0) revert RewardRouter__SourceCountNotOdd();
        if (_callOracleConfig.wntUsdSourceList.length < 3) revert RewardRouter__NotEnoughSources();
        if (_callOracleConfig.poolId == bytes32(0)) revert RewardRouter__InvalidPoolId();
        if (_callLockConfig.rate + _callExitConfig.rate > Calc.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callOracleConfig = _callOracleConfig;
        callLockConfig = _callLockConfig;
        callExitConfig = _callExitConfig;

        emit RewardRouter__SetConfig(block.timestamp, _callOracleConfig, _callLockConfig, _callExitConfig);
    }

    error RewardRouter__InvalidWeightFactors();
    error RewardRouter__SourceCountNotOdd();
    error RewardRouter__NotEnoughSources();
    error RewardRouter__InvalidPoolId();
    error RewardRouter__InvalidAddress();
    error RewardRouter__UnacceptableTokenPrice(uint curentPrice, uint acceptablePrice);
}
