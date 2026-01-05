// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";

contract Match is CoreContract {
    uint constant DIM_STAGE = 0;
    uint constant DIM_COLLATERAL = 1;

    struct Policy {
        uint allowanceRate;
        uint throttlePeriod;
        uint expiry;
    }

    mapping(address puppet => mapping(uint dim => mapping(bytes32 value => bool))) public filterMap;
    mapping(address puppet => mapping(address trader => Policy)) public policyMap;
    mapping(address puppet => mapping(address trader => uint)) public throttleMap;

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    function _setConfig(bytes memory) internal override {}

    function getMatchAmountList(
        IERC20 _baseToken,
        address _stage,
        address _masterSubaccount,
        IERC7579Account[] calldata _puppetList,
        uint[] calldata _requestedAmountList
    ) external view returns (uint[] memory _matchedAmountList) {
        _matchedAmountList = new uint[](_puppetList.length);

        bytes32 _stageKey = bytes32(uint(uint160(_stage)));
        bytes32 _collateralKey = bytes32(uint(uint160(address(_baseToken))));

        for (uint _i; _i < _puppetList.length; ++_i) {
            address _puppetAddr = address(_puppetList[_i]);

            if (!_passesFilter(_puppetAddr, DIM_STAGE, _stageKey)) continue;
            if (!_passesFilter(_puppetAddr, DIM_COLLATERAL, _collateralKey)) continue;
            if (block.timestamp < throttleMap[_puppetAddr][_masterSubaccount]) continue;

            Policy memory _p = policyMap[_puppetAddr][_masterSubaccount];
            if (_p.expiry == 0) _p = policyMap[_puppetAddr][address(0)];
            if (_p.expiry == 0 || block.timestamp > _p.expiry) continue;

            uint _balance = _baseToken.balanceOf(_puppetAddr);
            uint _maxAllowed = Precision.applyBasisPoints(_p.allowanceRate, _balance);
            uint _cappedAmount = _requestedAmountList[_i] > _maxAllowed ? _maxAllowed : _requestedAmountList[_i];

            _matchedAmountList[_i] = _cappedAmount;
        }
    }

    function recordThrottle(address _puppet, address _masterSubaccount) external auth {
        Policy memory _p = policyMap[_puppet][_masterSubaccount];
        if (_p.expiry == 0) _p = policyMap[_puppet][address(0)];
        if (_p.throttlePeriod > 0) {
            throttleMap[_puppet][_masterSubaccount] = block.timestamp + _p.throttlePeriod;
        }
    }

    function setFilter(address _puppet, uint _dim, bytes32 _value, bool _allowed) external auth {
        filterMap[_puppet][_dim][_value] = _allowed;
        if (_allowed && _value != bytes32(0)) filterMap[_puppet][_dim][bytes32(0)] = true;
        _logEvent("SetFilter", abi.encode(_puppet, _dim, _value, _allowed));
    }

    function setPolicy(address _puppet, address _trader, uint _allowanceRate, uint _throttlePeriod, uint _expiry)
        external
        auth
    {
        policyMap[_puppet][_trader] = Policy(_allowanceRate, _throttlePeriod, _expiry);
        if (_expiry == 0) delete throttleMap[_puppet][_trader];
        _logEvent("SetPolicy", abi.encode(_puppet, _trader, _allowanceRate, _throttlePeriod, _expiry));
    }

    function _passesFilter(address _puppet, uint _dim, bytes32 _value) internal view returns (bool) {
        if (!filterMap[_puppet][_dim][bytes32(0)]) return true;
        return filterMap[_puppet][_dim][_value];
    }
}
