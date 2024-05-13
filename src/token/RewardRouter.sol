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
import {PuppetToken} from "./PuppetToken.sol";
import {Oracle} from "./Oracle.sol";

contract RewardRouter is Permission, EIP712, ReentrancyGuard {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        Oracle oracle;
        uint lockRate;
        uint exitRate;
        uint distributionTimeframe;
        address revenueSource;
    }

    CallConfig callConfig;

    VotingEscrow immutable votingEscrow;
    RewardStore immutable store;
    PuppetToken immutable puppetToken;

    function getClaimable(IERC20 token, address user) public view returns (uint) {
        return RewardLogic.getClaimable(votingEscrow, store, token, callConfig.revenueSource, callConfig.distributionTimeframe, user);
    }

    constructor(
        IAuthority _authority,
        Router _router,
        VotingEscrow _votingEscrow,
        PuppetToken _puppetToken,
        RewardStore _store,
        CallConfig memory _callConfig
    ) Permission(_authority) EIP712("Reward Router", "1") {
        votingEscrow = _votingEscrow;
        store = _store;
        puppetToken = _puppetToken;

        _setConfig(_callConfig);
        _puppetToken.approve(address(_router), type(uint).max);
    }

    function lock(IERC20 revenueToken, uint unlockTime, uint acceptableTokenPrice, uint cugarAmount) public nonReentrant returns (uint) {
        RewardLogic.CallOptionParmas memory lockParams = RewardLogic.CallOptionParmas({
            revenueToken: revenueToken,
            user: msg.sender,
            revenueSource: callConfig.revenueSource,
            distributionTimeframe: callConfig.distributionTimeframe,
            rate: callConfig.lockRate,
            acceptableTokenPrice: acceptableTokenPrice,
            cugarAmount: cugarAmount
        });

        return RewardLogic.lock(votingEscrow, store, callConfig.oracle, puppetToken, lockParams, unlockTime);
    }

    function exit(IERC20 revenueToken, uint acceptableTokenPrice, uint cugarAmount, address receiver) public nonReentrant returns (uint) {
        RewardLogic.CallOptionParmas memory exitParams = RewardLogic.CallOptionParmas({
            revenueToken: revenueToken,
            user: msg.sender,
            revenueSource: callConfig.revenueSource,
            distributionTimeframe: callConfig.distributionTimeframe,
            rate: callConfig.exitRate,
            acceptableTokenPrice: acceptableTokenPrice,
            cugarAmount: cugarAmount
        });

        return RewardLogic.exit(votingEscrow, store, callConfig.oracle, puppetToken, exitParams, receiver);
    }

    function claim(IERC20 revenueToken, address receiver) public nonReentrant returns (uint) {
        return RewardLogic.claim(votingEscrow, store, revenueToken, callConfig.distributionTimeframe, callConfig.revenueSource, msg.sender, receiver);
    }

    function veLock(uint _tokenAmount, uint unlockTime) external nonReentrant {
        // RewardLogic.veLock(votingEscrow, store, msg.sender, msg.sender, _tokenAmount, unlockTime);
    }

    function veWithdraw(address receiver) external nonReentrant {
        RewardLogic.veWithdraw(votingEscrow, store, msg.sender, receiver);
    }

    function distribute(IERC20 token) external nonReentrant returns (uint) {
        VotingEscrow.Point memory point = votingEscrow.getPoint();
        return RewardLogic.distribute(store, token, callConfig.distributionTimeframe, callConfig.revenueSource, point);
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
        if (_callConfig.lockRate + callConfig.exitRate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
}
