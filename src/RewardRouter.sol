// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IReferralStorage} from "./position/interface/IReferralStorage.sol";

import {Router} from "./utils/Router.sol";
import {Precision} from "./utils/Precision.sol";

import {RewardLogic} from "./tokenomics/logic/RewardLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";

contract RewardRouter is Auth, ReentrancyGuard {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        RewardLogic.CallLockConfig lock;
        RewardLogic.CallExitConfig exit;
    }

    CallConfig callConfig;

    VotingEscrow votingEscrow;

    function getClaimableAmount(
        RewardLogic.Choice choice, //
        IERC20 token,
        address user,
        uint cugarAmount,
        uint tokenPrice
    ) public view returns (uint claimableAmount) {
        uint rate = choice == RewardLogic.Choice.LOCK ? callConfig.lock.rate : callConfig.exit.rate;

        return RewardLogic.getCommitedAmount(callConfig.lock.cugar, rate, token, tokenPrice, user, cugarAmount);
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

    constructor(Authority _authority, Router _router, VotingEscrow _votingEscrow, CallConfig memory _callConfig) Auth(address(0), _authority) {
        votingEscrow = _votingEscrow;

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

    function veWithdraw(address receiver) external nonReentrant {
        votingEscrow.withdraw(msg.sender, receiver);
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
