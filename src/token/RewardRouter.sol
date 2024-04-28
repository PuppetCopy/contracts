// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/auth/Permission.sol";
import {Precision} from "../utils/Precision.sol";

import {Router} from "../shared/Router.sol";

import {RewardStore} from "./store/RewardStore.sol";
import {RewardLogic} from "./logic/RewardLogic.sol";
import {VotingEscrow} from "./VotingEscrow.sol";

contract RewardRouter is Permission, EIP712, ReentrancyGuard {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        RewardLogic.CallLockConfig lock;
        RewardLogic.CallExitConfig exit;
    }

    CallConfig callConfig;
    VotingEscrow votingEscrow;
    RewardStore store;

    function getClaimableCursor(IERC20 token, address user, uint cursor) public view returns (uint) {
        return RewardLogic.getClaimableCursor(votingEscrow, store, token, user, cursor);
    }

    function getClaimable(IERC20 token, address user) public view returns (uint) {
        return RewardLogic.getClaimable(votingEscrow, store, token, user);
    }

    function getClaimable(IERC20 token, address user, uint fromCursor, uint toCursor) public view returns (uint) {
        return RewardLogic.getClaimable(votingEscrow, store, token, user, fromCursor, toCursor);
    }

    constructor(IAuthority _authority, Router _router, VotingEscrow _votingEscrow, RewardStore _store, CallConfig memory _callConfig)
        Permission(_authority)
        EIP712("Reward Router", "1")
    {
        votingEscrow = _votingEscrow;
        store = _store;

        _setConfig(_callConfig);
        callConfig.lock.puppetToken.approve(address(_router), type(uint).max);
    }

    function lock(IERC20 revenueToken, uint unlockTime, uint acceptableTokenPrice, uint cugarAmount) public nonReentrant returns (uint) {
        return RewardLogic.lock(votingEscrow, store, callConfig.lock, revenueToken, msg.sender, acceptableTokenPrice, unlockTime, cugarAmount);
    }

    function exit(IERC20 revenueToken, uint acceptableTokenPrice, uint cugarAmount) public nonReentrant returns (uint) {
        return RewardLogic.exit(votingEscrow, store, callConfig.exit, revenueToken, msg.sender, acceptableTokenPrice, cugarAmount);
    }

    function claim(IERC20 revenueToken, address receiver) public nonReentrant returns (uint) {
        return RewardLogic.claim(votingEscrow, store, revenueToken, msg.sender, receiver);
    }

    function veLock(uint _tokenAmount, uint unlockTime) external nonReentrant {
        votingEscrow.lockFor(msg.sender, msg.sender, _tokenAmount, unlockTime);
    }

    function veWithdraw(address receiver) external nonReentrant {
        votingEscrow.withdrawFor(msg.sender, receiver);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(IGmxReferralStorage _referralStorage, bytes32 _code, address _newOwner) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        if (_callConfig.lock.rate + callConfig.exit.rate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
}
