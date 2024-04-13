// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IReferralStorage} from "./position/interface/IReferralStorage.sol";

import {MulticallRouter} from "./utils/MulticallRouter.sol";
import {IWNT} from "./utils/interfaces/IWNT.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";
import {Precision} from "./utils/Precision.sol";

import {RewardLogic} from "./tokenomics/logic/RewardLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";
import {VeRevenueDistributor} from "./tokenomics/VeRevenueDistributor.sol";

contract RewardRouter is MulticallRouter {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        RewardLogic.CallLockConfig lock;
        RewardLogic.CallExitConfig exit;
    }

    CallConfig callConfig;

    VotingEscrow votingEscrow;
    VeRevenueDistributor revenueDistributor;

    function getClaimableAmount(
        RewardLogic.Choice choice, //
        IERC20 token,
        address user,
        uint cugarAmount,
        uint tokenPrice
    ) public view returns (uint claimableAmount) {
        uint rate = choice == RewardLogic.Choice.LOCK ? callConfig.lock.rate : callConfig.exit.rate;

        return RewardLogic.getClaimableAmount(callConfig.lock.cugar, rate, token, tokenPrice, user, cugarAmount);
    }

    function getClaimableAmount(
        RewardLogic.Choice choice, //
        IERC20 token,
        address user,
        uint cugarAmount
    ) public view returns (uint claimableAmount) {
        uint tokenPrice = callConfig.lock.oracle.getMaxPrice(token);
        return getClaimableAmount(choice, token, user, cugarAmount, tokenPrice);
    }

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
        callConfig.lock.puppetToken.approve(address(_router), type(uint).max);
    }

    function lock(IERC20 revenueToken, uint unlockTime, uint acceptableTokenPrice, uint cugarAmount) public nonReentrant {
        RewardLogic.lock(callConfig.lock, revenueToken, msg.sender, acceptableTokenPrice, unlockTime, cugarAmount);
    }

    function exit(IERC20 revenueToken, uint acceptableTokenPrice, uint cugarAmount) public nonReentrant {
        RewardLogic.exit(callConfig.exit, revenueToken, msg.sender, acceptableTokenPrice, cugarAmount);
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

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    function transferReferralOwnership(IReferralStorage _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
        RewardLogic.transferReferralOwnership(_referralStorage, _code, _newOwner);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        if (_callConfig.lock.rate + callConfig.exit.rate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
}
