// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {WNT} from "./utils/WNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";
import {Calc} from "./utils/Calc.sol";

import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {OracleLogic} from "./tokenomics/OracleLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";

contract RewardRouter is MulticallRouter {
    event RewardRouter__SetConfig(
        uint timestmap,
        RewardLogic.CallStorePriceConfig callStorePriceConfig,
        RewardLogic.CallLockConfig callLockConfig,
        RewardLogic.CallExitConfig callExitConfig,
        RewardLogic.CallClaimConfig callClaimConfig
    );

    RewardLogic rewardLogic;

    RewardLogic.CallStorePriceConfig public callStorePriceConfig;
    RewardLogic.CallLockConfig public callLockConfig;
    RewardLogic.CallExitConfig public callExitConfig;
    RewardLogic.CallClaimConfig public callClaimConfig;
    RewardLogic.CallVeConfig public callVeLockConfig;

    struct Params {
        VotingEscrow votingEscrow;
    }

    constructor(
        Dictator _dictator,
        WNT _wnt,
        Router _router,
        RewardLogic _rewardLogic,
        RewardLogic.CallStorePriceConfig memory _callStorePriceConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig,
        RewardLogic.CallClaimConfig memory _callClaimConfig,
        RewardLogic.CallVeConfig memory _callVeLockConfig
    ) MulticallRouter(_dictator, _wnt, _router, _dictator.owner()) {
        rewardLogic = _rewardLogic;
        _setConfig(_callStorePriceConfig, _callLockConfig, _callExitConfig, _callClaimConfig, _callVeLockConfig);
    }

    function lock(uint maxAcceptableTokenPriceInUsdc, uint unlockTime) public nonReentrant {
        rewardLogic.lock(callStorePriceConfig, callLockConfig, msg.sender, maxAcceptableTokenPriceInUsdc, unlockTime);
    }

    function exit(uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        rewardLogic.exit(callStorePriceConfig, callExitConfig, msg.sender, maxAcceptableTokenPriceInUsdc);
    }

    function claim(address to) external nonReentrant returns (uint) {
        return rewardLogic.claim(callClaimConfig, msg.sender, to);
    }

    function veLock(address to, uint _tokenAmount, uint unlockTime) external nonReentrant {
        rewardLogic.veLock(callVeLockConfig, msg.sender, to, _tokenAmount, unlockTime);
    }

    function veDeposit(uint value, address to) external nonReentrant {
        rewardLogic.veDeposit(callVeLockConfig, msg.sender, value, to);
    }

    function veWithdraw(address to) external nonReentrant {
        rewardLogic.veWithdraw(callVeLockConfig, msg.sender, to);
    }

    // governance

    function setConfig(
        RewardLogic.CallStorePriceConfig memory _callStorePriceConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig,
        RewardLogic.CallClaimConfig memory _callClaimConfig,
        RewardLogic.CallVeConfig memory _callVeLockConfig
    ) external requiresAuth {
        _setConfig(_callStorePriceConfig, _callLockConfig, _callExitConfig, _callClaimConfig, _callVeLockConfig);
    }

    // internal

    function _setConfig(
        RewardLogic.CallStorePriceConfig memory _callStorePriceConfig,
        RewardLogic.CallLockConfig memory _callLockConfig,
        RewardLogic.CallExitConfig memory _callExitConfig,
        RewardLogic.CallClaimConfig memory _callClaimConfig,
        RewardLogic.CallVeConfig memory _callVeLockConfig
    ) internal {
        if ((_callLockConfig.rate + _callExitConfig.rate + _callLockConfig.daoRate + _callExitConfig.daoRate) > Calc.BASIS_POINT_DIVISOR) {
            revert RewardRouter__InvalidWeightFactors();
        }

        if (_callStorePriceConfig.wntUsdPoolList.length % 2 == 0) revert RewardRouter__SourceCountNotOdd();
        if (_callStorePriceConfig.wntUsdPoolList.length < 3) revert RewardRouter__NotEnoughSources();

        if (_callStorePriceConfig.poolId == bytes32(0)) revert RewardRouter__InvalidPoolId();
        if (_callStorePriceConfig.oracleLogic == OracleLogic(address(0))) revert RewardRouter__InvalidAddress();

        callStorePriceConfig = _callStorePriceConfig;
        callLockConfig = _callLockConfig;
        callExitConfig = _callExitConfig;
        callClaimConfig = _callClaimConfig;
        callVeLockConfig = _callVeLockConfig;

        emit RewardRouter__SetConfig(block.timestamp, _callStorePriceConfig, _callLockConfig, _callExitConfig, callClaimConfig);
    }

    error RewardRouter__AdjustOtherLock();
    error RewardRouter__InvalidWeightFactors();
    error RewardRouter__SourceCountNotOdd();
    error RewardRouter__NotEnoughSources();
    error RewardRouter__InvalidPoolId();
    error RewardRouter__InvalidAddress();
}
