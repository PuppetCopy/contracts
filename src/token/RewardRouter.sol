// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";

import {ReentrancyGuardTransient} from "../utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";
import {Precision} from "../utils/Precision.sol";

import {Router} from "../shared/Router.sol";

import {RewardStore} from "./store/RewardStore.sol";
import {RewardLogic} from "./logic/RewardLogic.sol";
import {VotingEscrow} from "./VotingEscrow.sol";
import {PuppetToken} from "./PuppetToken.sol";

contract RewardRouter is Permission, EIP712, ReentrancyGuardTransient {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        uint rate;
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

    function lock(IERC20 revenueToken, uint lockDuration, uint cugarAmount) public nonReentrant returns (uint) {
        RewardLogic.CallOptionParmas memory lockParams = RewardLogic.CallOptionParmas({
            revenueToken: revenueToken,
            user: msg.sender,
            revenueSource: callConfig.revenueSource,
            distributionTimeframe: callConfig.distributionTimeframe,
            rate: callConfig.rate,
            cugarAmount: cugarAmount
        });

        return RewardLogic.lock(votingEscrow, store, puppetToken, lockParams, lockDuration);
    }

    function exit(IERC20 revenueToken, uint cugarAmount, address receiver) public nonReentrant returns (uint) {
        RewardLogic.CallOptionParmas memory exitParams = RewardLogic.CallOptionParmas({
            revenueToken: revenueToken,
            user: msg.sender,
            revenueSource: callConfig.revenueSource,
            distributionTimeframe: callConfig.distributionTimeframe,
            rate: callConfig.exitRate,
            cugarAmount: cugarAmount
        });

        return RewardLogic.exit(votingEscrow, store, puppetToken, exitParams, receiver);
    }

    function claim(IERC20 revenueToken, address receiver) public nonReentrant returns (uint) {
        return RewardLogic.claim(votingEscrow, store, revenueToken, callConfig.distributionTimeframe, callConfig.revenueSource, msg.sender, receiver);
    }

    function veLock(uint _tokenAmount, uint lockDuration) external nonReentrant {
        // RewardLogic.veLock(votingEscrow, store, msg.sender, msg.sender, _tokenAmount, lockDuration);
    }

    function veWithdraw(address receiver, uint amount) external nonReentrant {
        RewardLogic.veWithdraw(votingEscrow, msg.sender, receiver, amount);
    }

    function distribute(IERC20 token) external nonReentrant returns (uint) {
        uint supply = votingEscrow.totalSupply();
        return RewardLogic.distribute(votingEscrow, store, token, callConfig.revenueSource, callConfig.distributionTimeframe);
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
        if (_callConfig.rate + callConfig.exitRate > Precision.BASIS_POINT_DIVISOR) revert RewardRouter__InvalidWeightFactors();

        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error RewardRouter__InvalidWeightFactors();
}
