// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {Router} from "./utils/Router.sol";
import {Precision} from "./utils/Precision.sol";

import {Cugar} from "./shared/Cugar.sol";
import {RewardLogic} from "./tokenomics/logic/RewardLogic.sol";
import {VotingEscrow} from "./tokenomics/VotingEscrow.sol";

contract RewardRouter is Auth, EIP712, ReentrancyGuard {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        RewardLogic.CallLockConfig lock;
        RewardLogic.CallExitConfig exit;
    }

    CallConfig callConfig;
    VotingEscrow votingEscrow;
    Cugar cugar;

    constructor(Authority _authority, Router _router, VotingEscrow _votingEscrow, Cugar _Cugar, CallConfig memory _callConfig)
        Auth(address(0), _authority)
        EIP712("Reward Router", "1")
    {
        votingEscrow = _votingEscrow;
        cugar = _Cugar;

        _setConfig(_callConfig);
        callConfig.lock.puppetToken.approve(address(_router), type(uint).max);
    }

    function lock(IERC20 revenueToken, uint unlockTime, uint acceptableTokenPrice) public nonReentrant {
        RewardLogic.lock(callConfig.lock, revenueToken, msg.sender, acceptableTokenPrice, unlockTime);
    }

    function claim(IERC20 revenueToken) external nonReentrant returns (uint) {
        return claim(revenueToken, msg.sender);
    }

    function claim(IERC20 revenueToken, address receiver) public nonReentrant returns (uint) {
        return cugar.claim(revenueToken, msg.sender, receiver);
    }

    function exit(IERC20 revenueToken, uint acceptableTokenPrice) public nonReentrant {
        RewardLogic.exit(callConfig.exit, revenueToken, msg.sender, acceptableTokenPrice);
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

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        if (_callConfig.lock.rate + callConfig.exit.rate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
}
