// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";

contract RevenueStore is BankStore {
    mapping(IERC20 => uint) tokenBuybackOffer;
    mapping(IERC20 => uint) cumulativeRewardPerContributionMap;

    mapping(IERC20 => mapping(address => uint)) userCumulativeContributionMap;
    mapping(IERC20 => mapping(address => uint)) userRewardPerContributionMap;
    mapping(IERC20 => mapping(address => uint)) userAccruedRewardMap;

    constructor(
        IAuthority _authority, //
        Router _router,
        IERC20[] memory _tokenBuybackThresholdList,
        uint[] memory _tokenBuybackThresholdAmountList
    ) BankStore(_authority, _router) {
        uint thresholdListLength = _tokenBuybackThresholdList.length;
        if (thresholdListLength != _tokenBuybackThresholdAmountList.length) revert RewardStore__InvalidLength();

        for (uint i; i < thresholdListLength; i++) {
            IERC20 _token = _tokenBuybackThresholdList[i];
            tokenBuybackOffer[_token] = _tokenBuybackThresholdAmountList[i];
        }
    }

    function getTokenBuybackOffer(IERC20 _token) external view returns (uint) {
        return tokenBuybackOffer[_token];
    }

    function setTokenBuybackOffer(IERC20 _token, uint _value) external auth {
        tokenBuybackOffer[_token] = _value;
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
        uint cumTokenPerContrib = cumulativeRewardPerContributionMap[_token];
        uint userRewardPerContribution = userRewardPerContributionMap[_token][_user];

        if (cumTokenPerContrib > userRewardPerContribution) {
            userRewardPerContributionMap[_token][_user] = cumTokenPerContrib;
            uint cumContribution = userCumulativeContributionMap[_token][_user];

            userAccruedRewardMap[_token][_user] +=
                cumContribution * (cumTokenPerContrib - userRewardPerContribution) / Precision.FLOAT_PRECISION;
        }

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

        if (_valueListLength != _valueList.length) revert RewardStore__InvalidLength();

        for (uint i = 0; i < _valueListLength; i++) {
            address _user = _userList[i];
            userCumulativeContributionMap[_token][_user] += _valueList[i];
            _totalAmount += _valueList[i];

            uint cumTokenPerContrib = cumulativeRewardPerContributionMap[_token];
            uint userRewardPerContribution = userRewardPerContributionMap[_token][_user];

            if (cumTokenPerContrib > userRewardPerContribution) {
                userRewardPerContributionMap[_token][_user] = cumTokenPerContrib;
                uint cumContribution = userCumulativeContributionMap[_token][_user];

                userAccruedRewardMap[_token][_user] +=
                    cumContribution * (cumTokenPerContrib - userRewardPerContribution) / Precision.FLOAT_PRECISION;
            }
        }

        transferIn(_token, _depositor, _totalAmount);
    }

    function getUserRewardPerContribution(IERC20 _token, address _user) external view returns (uint) {
        return userRewardPerContributionMap[_token][_user];
    }

    function setUserRewardPerContribution(IERC20 _token, address _user, uint _value) external auth {
        userRewardPerContributionMap[_token][_user] = _value;
    }

    function getUserAccruedReward(IERC20 _token, address _user) external view returns (uint) {
        return userAccruedRewardMap[_token][_user];
    }

    function setUserAccruedReward(IERC20 _token, address _user, uint _value) external auth {
        userAccruedRewardMap[_token][_user] = _value;
    }

    error RewardStore__InvalidLength();
}
