// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Router} from "../utilities/Router.sol";
import {PuppetToken} from "./PuppetToken.sol";
import {IDataStore} from "./../integrations/utilities/interfaces/IDataStore.sol";
import {CommonHelper} from "./../integrations/libraries/CommonHelper.sol";
import {VotingEscrow, MAXTIME} from "./VotingEscrow.sol";
import {IVeRevenueDistributor} from "./../utilities/interfaces/IVeRevenueDistributor.sol";

contract RewardLogic is Auth {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(
        Choice choice,
        address indexed account,
        address dao,
        IERC20 revenueInToken,
        uint revenueInTokenAmount,
        uint maxTokenAmount,
        uint rate,
        uint amount,
        uint daoRate,
        uint daoAmount
    );
    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct OptionParams {
        IDataStore dataStore;
        PuppetToken puppetToken;
        address dao;
        address account;
        IERC20 revenueInToken;
        uint rate;
        uint daoRate;
        uint tokenPrice;
    }

    uint internal constant BASIS_POINT_DIVISOR = 10000;

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        uint claimableAmount = tokenAmount * distributionRatio / BASIS_POINT_DIVISOR;
        return claimableAmount;
    }

    function getAccountGeneratedRevenue(IDataStore dataStore, address account) public view returns (uint) {
        return dataStore.getUint(keccak256(abi.encode("USER_REVENUE", account)));
    }

    function getAccountRouteList(IDataStore dataStore, bytes32[] calldata routeTypeKeys, address account)
        public
        view
        returns (address[] memory routeList)
    {
        routeList = new address[](routeTypeKeys.length);

        for (uint i = 0; i < routeTypeKeys.length; i++) {
            routeList[i] = CommonHelper.routeAddress(dataStore, CommonHelper.routeKey(dataStore, account, routeTypeKeys[i]));
        }
    }

    function getRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) public view returns (uint) {
        if (unlockTime == 0) {
            unlockTime = votingEscrow.lockedEnd(account);
        }

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return BASIS_POINT_DIVISOR;

        return unlockTime * BASIS_POINT_DIVISOR / maxTime;
    }

    // state

    function lock(Router router, VotingEscrow votingEscrow, OptionParams calldata params, uint unlockTime) public requiresAuth {
        uint revenueInTokenAmount = getAndResetUserRevenue(params.dataStore, params.account);
        uint maxRewardTokenAmount = revenueInTokenAmount * 1e18 / params.tokenPrice;

        if (revenueInTokenAmount == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = getClaimableAmount(params.rate, maxRewardTokenAmount) * getRewardTimeMultiplier(votingEscrow, params.account, unlockTime)
            / BASIS_POINT_DIVISOR;
        params.puppetToken.mint(address(this), amount);
        SafeERC20.forceApprove(params.puppetToken, address(router), amount);
        votingEscrow.lock(address(this), params.account, amount, unlockTime);

        uint daoAmount = getClaimableAmount(params.daoRate, maxRewardTokenAmount);
        params.puppetToken.mint(params.dao, daoAmount);

        emit RewardLogic__ClaimOption(
            Choice.LOCK,
            params.account,
            params.dao,
            params.revenueInToken,
            revenueInTokenAmount,
            maxRewardTokenAmount,
            params.rate,
            amount,
            params.daoRate,
            daoAmount
        );
    }

    function exit(OptionParams calldata params) public requiresAuth {
        uint revenueInTokenAmount = getAndResetUserRevenue(params.dataStore, params.account);
        uint maxRewardTokenAmount = revenueInTokenAmount * 1e18 / params.tokenPrice;

        if (revenueInTokenAmount == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint daoAmount = getClaimableAmount(params.daoRate, maxRewardTokenAmount);
        uint amount = getClaimableAmount(params.rate, maxRewardTokenAmount);

        params.puppetToken.mint(params.dao, daoAmount);
        params.puppetToken.mint(params.account, amount);

        emit RewardLogic__ClaimOption(
            Choice.EXIT,
            params.account,
            params.dao,
            params.revenueInToken,
            revenueInTokenAmount,
            maxRewardTokenAmount,
            params.rate,
            amount,
            params.daoRate,
            daoAmount
        );
    }

    function claim(IVeRevenueDistributor revenueDistributor, IERC20 revenueInToken, address from, address to) public requiresAuth returns (uint) {
        return revenueDistributor.claim(revenueInToken, from, to);
    }

    // internal

    function getAndResetUserRevenue(IDataStore dataStore, address account) internal returns (uint revenue) {
        revenue = dataStore.getUint(keccak256(abi.encode("USER_REVENUE", account)));
        dataStore.setUint(keccak256(abi.encode("USER_REVENUE", account)), 0);
    }

    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(address _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
        bytes memory data = abi.encodeWithSignature("setCodeOwner(bytes32,address)", _code, _newOwner);
        (bool success,) = _referralStorage.call(data);

        if (!success) revert RewardLogic__TransferReferralFailed();

        emit RewardLogic__ReferralOwnershipTransferred(_referralStorage, _code, _newOwner, block.timestamp);
    }

    error RewardLogic__TransferReferralFailed();
    error RewardLogic__NoClaimableAmount();
}
