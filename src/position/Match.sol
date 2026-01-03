// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";

contract Match is CoreContract {
    uint constant DIM_CHAIN = 0;
    uint constant DIM_STAGE = 1;
    uint constant DIM_COLLATERAL = 2;

    struct Config {
        uint gasLimit;
    }

    struct Policy {
        uint allowanceRate;
        uint throttlePeriod;
        uint expiry;
    }

    struct MatchParams {
        address subaccount;
        address master;
        uint chainId;
        address stage;
        IERC20 collateral;
    }

    Config public config;

    mapping(address puppet => mapping(uint dim => mapping(bytes32 value => bool))) public filterMap;
    mapping(address puppet => mapping(uint dim => bool)) public hasFilterMap;

    mapping(address puppet => mapping(address trader => Policy)) public policyMap;
    mapping(address puppet => mapping(address trader => uint)) public throttleMap;

    constructor(IAuthority _authority, bytes memory _config) CoreContract(_authority, _config) {}

    function _setConfig(bytes memory _data) internal override {
        config = abi.decode(_data, (Config));
    }

    function executeMatch(
        MatchParams calldata _params,
        address[] calldata _puppets,
        uint[] calldata _amounts
    ) external auth returns (uint[] memory _allocated) {
        _allocated = new uint[](_puppets.length);

        bytes32 _chainKey = bytes32(_params.chainId);
        bytes32 _stageKey = bytes32(uint(uint160(_params.stage)));
        bytes32 _collateralKey = bytes32(uint(uint160(address(_params.collateral))));
        uint _gasLimit = config.gasLimit;

        uint _balanceBefore = _params.collateral.balanceOf(_params.subaccount);
        uint _total;

        for (uint _i; _i < _puppets.length; ++_i) {
            address _puppet = _puppets[_i];

            if (!_passesFilter(_puppet, DIM_CHAIN, _chainKey)) continue;
            if (!_passesFilter(_puppet, DIM_STAGE, _stageKey)) continue;
            if (!_passesFilter(_puppet, DIM_COLLATERAL, _collateralKey)) continue;

            if (block.timestamp < throttleMap[_puppet][_params.master]) continue;

            Policy memory _p = policyMap[_puppet][_params.master];
            if (_p.expiry == 0) _p = policyMap[_puppet][address(0)];
            if (_p.expiry == 0 || block.timestamp > _p.expiry) continue;

            uint _balance = _params.collateral.balanceOf(_puppet);
            uint _maxAllowed = Precision.applyBasisPoints(_p.allowanceRate, _balance);
            uint _cappedAmount = _amounts[_i] > _maxAllowed ? _maxAllowed : _amounts[_i];
            if (_cappedAmount == 0) continue;

            (bool _success,) = address(_params.collateral).call{gas: _gasLimit}(
                abi.encodeCall(IERC20.transferFrom, (_puppet, _params.subaccount, _cappedAmount))
            );
            if (!_success) continue;

            throttleMap[_puppet][_params.master] = block.timestamp + _p.throttlePeriod;
            _allocated[_i] = _cappedAmount;
            _total += _cappedAmount;
        }

        if (_params.collateral.balanceOf(_params.subaccount) != _balanceBefore + _total) {
            revert Error.Match__TransferMismatch();
        }
    }

    function setFilter(address _puppet, uint _dim, bytes32 _value, bool _allowed) external auth {
        if (_value == bytes32(0)) {
            hasFilterMap[_puppet][_dim] = _allowed;
        } else {
            filterMap[_puppet][_dim][_value] = _allowed;
            if (_allowed) hasFilterMap[_puppet][_dim] = true;
        }
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
        if (!hasFilterMap[_puppet][_dim]) return true;
        return filterMap[_puppet][_dim][_value];
    }
}
