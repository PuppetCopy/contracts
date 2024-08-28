// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract ContributeStore is BankStore {
    mapping(IERC20 => uint) tokenBuybackQuote;
    mapping(IERC20 => uint) cumulativeRewardPerContributionMap;

    mapping(IERC20 => mapping(address => uint)) userCumulativeContributionMap;
    mapping(IERC20 => mapping(address => uint)) userRewardPerContributionCursorMap;
    mapping(address => uint) userAccruedRewardMap;

    constructor(
        IAuthority _authority,
        Router _router,
        IERC20[] memory _tokenBuybackThresholdList,
        uint[] memory _tokenBuybackThresholdAmountList
    ) BankStore(_authority, _router) {
        uint _thresholdListLength = _tokenBuybackThresholdList.length;
        if (_thresholdListLength != _tokenBuybackThresholdAmountList.length) revert RewardStore__InvalidLength();

        for (uint i; i < _thresholdListLength; i++) {
            IERC20 _token = _tokenBuybackThresholdList[i];
            tokenBuybackQuote[_token] = _tokenBuybackThresholdAmountList[i];
        }
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
        updateUserTokenRewardState(_token, cumulativeRewardPerContributionMap[_token], _user);

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

        uint _cumulativeTokenPerContribution = cumulativeRewardPerContributionMap[_token];

        for (uint i = 0; i < _valueListLength; i++) {
            address _user = _userList[i];
            uint _value = _valueList[i];
            _totalAmount += _value;

            updateUserTokenRewardState(_token, _cumulativeTokenPerContribution, _user);
            userCumulativeContributionMap[_token][_user] += _value;
        }

        transferIn(_token, _depositor, _totalAmount);
    }

    function getUserRewardPerContributionCursor(IERC20 _token, address _user) external view returns (uint) {
        return userRewardPerContributionCursorMap[_token][_user];
    }

    function setUserRewardPerContributionCursor(IERC20 _token, address _user, uint _value) external auth {
        userRewardPerContributionCursorMap[_token][_user] = _value;
    }

    function getUserAccruedReward(address _user) external view returns (uint) {
        return userAccruedRewardMap[_user];
    }

    function setUserAccruedReward(address _user, uint _value) external auth {
        userAccruedRewardMap[_user] = _value;
    }

    function updateUserTokenRewardState(
        IERC20 _token,
        uint _cumulativeTokenPerContribution,
        address _user
    ) public auth {
        uint _userRewardPerContribution = userRewardPerContributionCursorMap[_token][_user];

        if (_cumulativeTokenPerContribution > _userRewardPerContribution) {
            userAccruedRewardMap[_user] += userCumulativeContributionMap[_token][_user]
                * (_cumulativeTokenPerContribution - _userRewardPerContribution) / Precision.FLOAT_PRECISION;

            userRewardPerContributionCursorMap[_token][_user] = _cumulativeTokenPerContribution;
            userCumulativeContributionMap[_token][_user] = 0;
        }
    }

    function updateUserTokenRewardState(IERC20 _token, address _user) public auth {
        updateUserTokenRewardState(_token, cumulativeRewardPerContributionMap[_token], _user);
    }

    function updateUserTokenRewardStateList(address _user, IERC20[] calldata _tokenList) external auth {
        uint _tokenListLength = _tokenList.length;

        for (uint i = 0; i < _tokenListLength; i++) {
            updateUserTokenRewardState(_tokenList[i], _user);
        }
    }

    error RewardStore__InvalidLength();
}
