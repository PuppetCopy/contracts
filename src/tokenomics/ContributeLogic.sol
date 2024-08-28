// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC20Mintable} from "../utils/interfaces/IERC20Mintable.sol";
import {ContributeStore} from "./store/ContributeStore.sol";

/// @title ContributeLogic
/// @notice contract features a token-based incentive buy-back, it has self-contained mechanism operates without relying
/// on external price oracles or a single liquidity pool for each token contributed
/// distribution of rewards within the protocol, including locking mechanisms and bonus multipliers
/// for token holders.
//// @dev It calculates rewards for contributors based on a cumulative distribution rate, which increases with each
/// PUPPET token sold, enabling users to claim PUPPET rewards proportionate to their token contributions
contract ContributeLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baselineEmissionRate;
    }

    /// @notice The configuration parameters for the ContributeLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20Mintable public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    ContributeStore public immutable store;

    function getPendingUserTokenReward(IERC20 token, address user) public view returns (uint) {
        uint userRewardPerContrib = store.getUserRewardPerContributionCursor(token, user);
        uint cumulativeRewardPerContribution = store.getCumulativeRewardPerContribution(token);

        if (cumulativeRewardPerContribution > userRewardPerContrib) {
            uint userCumContribution = store.getUserCumulativeContribution(token, user);

            return userCumContribution * (cumulativeRewardPerContribution - userRewardPerContrib)
                / Precision.FLOAT_PRECISION;
        }

        return 0;
    }

    function getPendingUserTokenListRewardList(
        address user,
        IERC20[] calldata tokenList
    ) public view returns (uint totalPendingReward, uint[] memory pendingRewardList) {
        pendingRewardList = new uint[](tokenList.length);
        totalPendingReward;

        for (uint i; i < tokenList.length; i++) {
            pendingRewardList[i] = getPendingUserTokenReward(tokenList[i], user);
        }
    }

    function getClaimable(IERC20[] calldata tokenList, address user) external view returns (uint) {
        (uint totalPendingReward,) = getPendingUserTokenListRewardList(user, tokenList);
        return store.getUserAccruedReward(user) + totalPendingReward;
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20Mintable _rewardToken,
        ContributeStore _store,
        Config memory _config
    ) CoreContract("ContributeLogic", "1", _authority, _eventEmitter) {
        rewardToken = _rewardToken;
        store = _store;

        _setConfig(_config);
    }

    function contribute(
        IERC20 _token, //
        address _depositor,
        address _user,
        uint _value
    ) external auth {
        store.contribute(_token, _depositor, _user, _value);
    }

    function contributeMany(
        IERC20 _token, //
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        store.contributeMany(_token, _depositor, _userList, _valueList);
    }

    /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
    /// @param depositor The address that deposits the buyback token.
    /// @param user The address that will receive the revenue token.
    /// @param token The address of the revenue token to be bought back.
    /// @param amount The amount of revenue tokens to be bought back.
    function buyback(address depositor, address user, IERC20 token, uint amount) external auth {
        uint thresholdAmount = store.getBuybackQuote(token);

        if (thresholdAmount == 0) revert ContributeLogic__InvalidBuybackToken();

        store.transferIn(rewardToken, depositor, thresholdAmount);
        store.transferOut(token, user, amount);

        uint nextCumulativeTokenPerContrib = store.increaseCumulativeRewardPerContribution(
            token, //
            Precision.toFactor(thresholdAmount, amount)
        );

        logEvent(
            "buyback()", abi.encode(token, depositor, user, nextCumulativeTokenPerContrib, thresholdAmount, amount)
        );
    }

    /// @notice Updates the reward state for a user based on the token list and cumulative token per contribution list.
    /// @param token The token for which the reward state is to be updated.
    /// @param user The address of the user for whom the reward state is to be updated.
    function updateUserTokenRewardState(IERC20 token, address user) external auth {
        store.updateUserTokenRewardState(token, user);
    }

    /// @notice Updates the reward state for a user based on the token list and cumulative token per contribution list.
    /// @param tokenList The list of tokens for which the reward state is to be updated.
    /// @param user The address of the user for whom the reward state is to be updated.
    function updateUserTokenRewardStateList(IERC20[] calldata tokenList, address user) external auth {
        store.updateUserTokenRewardStateList(user, tokenList);
    }

    /// @notice Claims the rewards for a specific token contribution.
    /// @param user The address of the contributor for whom the rewards are to be claimed.
    /// @param receiver The address that will receive the claimed rewards.
    /// @param amount The amount of rewards to be claimed.
    /// @return The amount of rewards claimed.
    function claim(address user, address receiver, uint amount) external auth returns (uint) {
        uint accruedReward = store.getUserAccruedReward(user);

        if (amount > accruedReward) revert ContributeLogic__InsufficientClaimableReward();

        uint nextAccruedReward = accruedReward - amount;
        uint reward = Precision.applyFactor(config.baselineEmissionRate, amount);

        store.setUserAccruedReward(user, nextAccruedReward);
        rewardToken.mint(receiver, reward);

        logEvent("claim()", abi.encode(user, nextAccruedReward, reward));

        return reward;
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.

    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig()", abi.encode(_config));
    }

    /// @notice Error emitted when the claim token is invalid
    error ContributeLogic__InvalidBuybackToken();

    /// @notice Error emitted when the claimable reward is insufficient
    error ContributeLogic__InsufficientClaimableReward();
}
