// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {BankStore} from "./../../shared/store/BankStore.sol";
import {Router} from "./../../shared/Router.sol";

contract RevenueStore is BankStore {
    mapping(IERC20 => uint) tokenPerContributionCursorMap;
    mapping(IERC20 => uint) tokenBuybackOfferMap;

    mapping(IERC20 token => mapping(address user => uint)) userTokenPerContributionMap;
    mapping(IERC20 => mapping(address => uint)) userContributionBalanceMap;

    constructor(
        IAuthority _authority, //
        Router _router,
        IERC20[] memory _tokenBuybackThresholdList,
        uint[] memory _tokenBuybackThresholdAmountList
    ) BankStore(_authority, _router) {
        if (_tokenBuybackThresholdList.length != _tokenBuybackThresholdAmountList.length) revert RewardStore__InvalidLength();

        for (uint i; i < _tokenBuybackThresholdList.length; i++) {
            IERC20 _token = _tokenBuybackThresholdList[i];
            tokenBuybackOfferMap[_token] = _tokenBuybackThresholdAmountList[i];
        }
    }

    function increaseTokenPerContributionCursor(IERC20 _token, uint _value) external auth returns (uint) {
        return tokenPerContributionCursorMap[_token] += _value;
    }

    function getTokenPerContributionCursor(IERC20 _token) external view returns (uint) {
        return tokenPerContributionCursorMap[_token];
    }

    function getTokenBuybackOffer(IERC20 _token) external view returns (uint) {
        return tokenBuybackOfferMap[_token];
    }

    function setTokenBuybackOffer(IERC20 _token, uint _value) external auth {
        tokenBuybackOfferMap[_token] = _value;
    }

    function getUserContributionBalance(IERC20 _token, address _user) external view returns (uint) {
        return userContributionBalanceMap[_token][_user];
    }

    function setUserContributionBalance(IERC20 _token, address _user, uint _value) external auth {
        userContributionBalanceMap[_token][_user] += _value;
    }

    function commitReward(
        IERC20 _token, //
        address _source,
        address _user,
        uint _value
    ) external auth {
        userContributionBalanceMap[_token][_user] += _value;
        _transferIn(_token, _source, _value);
    }

    function commitRewardList(
        IERC20 _token, //
        address _source,
        address[] calldata _userList,
        uint[] calldata _valueList,
        address _trader,
        uint _performanceFee
    ) external auth {
        uint _valueListLength = _valueList.length;
        uint _totalAmount = 0;

        if (_valueListLength != _valueList.length) revert RewardStore__InvalidLength();

        if (_performanceFee > 0) userContributionBalanceMap[_token][_trader] += _performanceFee;

        for (uint i = 0; i < _valueListLength; i++) {
            userContributionBalanceMap[_token][_userList[i]] += _valueList[i];
            _totalAmount += _valueList[i];
        }

        _transferIn(_token, _source, _totalAmount + _performanceFee);
    }

    function getUserTokenPerContributionCursor(IERC20 _token, address _user) external view returns (uint) {
        return userTokenPerContributionMap[_token][_user];
    }

    function setUserTokenPerContributionCursor(IERC20 _token, address _user, uint _amount) external auth {
        userTokenPerContributionMap[_token][_user] = _amount;
    }

    function transferOut(IERC20 _token, address _receiver, uint _value) external auth {
        _transferOut(_token, _receiver, _value);
    }

    function transferIn(IERC20 _token, address _depositor, uint _value) external auth {
        _transferIn(_token, _depositor, _value);
    }

    error RewardStore__InvalidLength();
}
