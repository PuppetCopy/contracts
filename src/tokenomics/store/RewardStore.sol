// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract RewardStore is BankStore {
    struct UserRewardCursor {
        uint rewardPerToken;
        uint accruedReward;
    }

    uint public cumulativePerContributionMap;
    mapping(address user => UserRewardCursor) userRewardCursorMap;

    uint public tokenEmissionRewardPerTokenCursor;
    uint public tokenEmissionRate;
    uint public tokenEmissionTimestamp;

    mapping(IERC20 => uint) tokenBuybackQuote;
    mapping(IERC20 => uint) cumulativeRewardPerContributionMap;

    mapping(IERC20 => mapping(address => uint)) userCumulativeContributionMap;
    mapping(IERC20 => mapping(address => uint)) userRewardPerContributionCursorMap;
    mapping(IERC20 => mapping(address => uint)) userAccruedRewardMap;

    constructor(
        IAuthority _authority,
        Router _router,
        IERC20[] memory _tokenBuybackThresholdList,
        uint[] memory _tokenBuybackThresholdAmountList
    ) BankStore(_authority, _router) {
        uint thresholdListLength = _tokenBuybackThresholdList.length;
        if (thresholdListLength != _tokenBuybackThresholdAmountList.length) revert RewardStore__InvalidLength();

        for (uint i; i < thresholdListLength; i++) {
            IERC20 _token = _tokenBuybackThresholdList[i];
            tokenBuybackQuote[_token] = _tokenBuybackThresholdAmountList[i];
        }
    }

    function incrementCumulativePerContribution(uint _value) external auth returns (uint) {
        return cumulativePerContributionMap += _value;
    }

    function getUserRewardCursor(address _user) external view returns (UserRewardCursor memory) {
        return userRewardCursorMap[_user];
    }

    function setUserRewardCursor(address _user, UserRewardCursor calldata cursor) external auth {
        userRewardCursorMap[_user] = cursor;
    }

    function setTokenEmissionRewardPerTokenCursor(uint _value) external auth {
        tokenEmissionRewardPerTokenCursor = _value;
    }

    function setTokenEmissionRate(uint _value) external auth {
        tokenEmissionRate = _value;
    }

    function setTokenEmissionTimestamp(uint _value) external auth {
        tokenEmissionTimestamp = _value;
    }

    function getBuybackQuote(IERC20 _token) external view returns (uint) {
        return tokenBuybackQuote[_token];
    }

    function setTokenBuybackOffer(IERC20 _token, uint _value) external auth {
        tokenBuybackQuote[_token] = _value;
    }

    function getCumulativeRewardPerContribution(IERC20 _token) external view returns (uint) {
        return cumulativeRewardPerContributionMap[_token];
    }

    function increaseCumulativeRewardPerContribution(IERC20 _token, uint _value) external auth returns (uint) {
        return cumulativeRewardPerContributionMap[_token] += _value;
    }

    function getUserCumulativeContribution(IERC20 _token, address _user) external view returns (uint) {
        return userCumulativeContributionMap[_token][_user];
    }

    function contribute(
        IERC20 _token, //
        address _depositor,
        address _user,
        uint _value
    ) external auth {
        uint cumulativeTokenPerContribution = cumulativeRewardPerContributionMap[_token];

        _userDistribute(_token, cumulativeTokenPerContribution, _user);

        userCumulativeContributionMap[_token][_user] += _value;
        transferIn(_token, _depositor, _value);
    }

    function contributeMany(
        IERC20 _token, //
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        uint _valueListLength = _valueList.length;
        uint _totalAmount = 0;

        if (_valueListLength != _userList.length) revert RewardStore__InvalidLength();

        uint cumulativeTokenPerContribution = cumulativeRewardPerContributionMap[_token];

        for (uint i = 0; i < _valueListLength; i++) {
            address _user = _userList[i];
            uint value = _valueList[i];
            _totalAmount += value;

            _userDistribute(_token, cumulativeTokenPerContribution, _user);

            userCumulativeContributionMap[_token][_user] += value;
        }

        transferIn(_token, _depositor, _totalAmount);
    }

    function getUserRewardPerContributionCursor(IERC20 _token, address _user) external view returns (uint) {
        return userRewardPerContributionCursorMap[_token][_user];
    }

    function setUserRewardPerContributionCursor(IERC20 _token, address _user, uint _value) external auth {
        userRewardPerContributionCursorMap[_token][_user] = _value;
    }

    function getUserAccruedReward(IERC20 _token, address _user) external view returns (uint) {
        return userAccruedRewardMap[_token][_user];
    }

    function setUserAccruedReward(IERC20 _token, address _user, uint _value) external auth {
        userAccruedRewardMap[_token][_user] = _value;
    }

    function _userDistribute(IERC20 _token, uint cumulativeTokenPerContribution, address _user) internal {
        uint userRewardPerContribution = userRewardPerContributionCursorMap[_token][_user];

        if (cumulativeTokenPerContribution > userRewardPerContribution) {
            userRewardPerContributionCursorMap[_token][_user] = cumulativeTokenPerContribution;

            userAccruedRewardMap[_token][_user] += userCumulativeContributionMap[_token][_user]
                * (cumulativeTokenPerContribution - userRewardPerContribution) / Precision.FLOAT_PRECISION;
            userCumulativeContributionMap[_token][_user] = 0;
        }
    }

    error RewardStore__InvalidLength();
}
