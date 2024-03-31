// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {IWNT} from "./utils/interfaces/IWNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";
import {Precision} from "./utils/Precision.sol";

import {OracleLogic} from "./tokenomics/logic/OracleLogic.sol";
import {RewardLogic} from "./tokenomics/logic/RewardLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";
import {VeRevenueDistributor} from "./tokenomics/VeRevenueDistributor.sol";

contract RewardRouter is MulticallRouter {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        OracleLogic.CallConfig oracle;
        RewardLogic.CallLockConfig lock;
        RewardLogic.CallExitConfig exit;
    }

    CallConfig callConfig;

    VotingEscrow votingEscrow;
    VeRevenueDistributor revenueDistributor;

    constructor(
        Dictator _dictator,
        IWNT _wnt,
        Router _router,
        VotingEscrow _votingEscrow,
        VeRevenueDistributor _revenueDistributor,
        CallConfig memory _callConfig
    ) MulticallRouter(_dictator, _wnt, _router, _dictator.owner()) {
        votingEscrow = _votingEscrow;
        revenueDistributor = _revenueDistributor;

        _setConfig(_callConfig);
    }

    function lock(IERC20[] calldata revenueTokenList, uint maxAcceptableTokenPriceInUsdc, uint unlockTime) public nonReentrant {
        (,, uint tokenPrice) = OracleLogic.syncPrices(callConfig.oracle);

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice(tokenPrice);

        RewardLogic.lock(callConfig.lock, revenueTokenList, tokenPrice, msg.sender, unlockTime);
    }

    function exit(IERC20[] calldata revenueTokenList, uint maxAcceptableTokenPriceInUsdc) public nonReentrant {
        (,, uint usdPerToken) = OracleLogic.syncPrices(callConfig.oracle);

        if (usdPerToken > maxAcceptableTokenPriceInUsdc) revert RewardRouter__UnacceptableTokenPrice(usdPerToken);

        RewardLogic.exit(callConfig.exit, revenueTokenList, usdPerToken, msg.sender);
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

    function claim(IERC20 token, address to) internal {
        revenueDistributor.claim(token, msg.sender, to);
    }

    function claimList(IERC20[] calldata tokenList, address to) internal {
        revenueDistributor.claimList(tokenList, msg.sender, to);
    }

    // integration

    function syncPrices() public nonReentrant {
        OracleLogic.syncPrices(callConfig.oracle);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    function transferReferralOwnership(address _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
        RewardLogic.transferReferralOwnership(_referralStorage, _code, _newOwner);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        if (_callConfig.oracle.wntUsdSourceList.length % 2 == 0) revert RewardRouter__SourceCountNotOdd();
        if (_callConfig.oracle.wntUsdSourceList.length < 3) revert RewardRouter__NotEnoughSources();
        if (_callConfig.oracle.poolId == bytes32(0)) revert RewardRouter__InvalidPoolId();
        if (_callConfig.lock.rate + callConfig.exit.rate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
    error RewardRouter__SourceCountNotOdd();
    error RewardRouter__NotEnoughSources();
    error RewardRouter__InvalidPoolId();
    error RewardRouter__InvalidAddress();
    error RewardRouter__UnacceptableTokenPrice(uint curentPrice);
}
