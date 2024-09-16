// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../../shared/Router.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract MirrorPositionStore is BankStore {
    struct RequestAdjustment {
        Subaccount subaccount;
        bytes32 allocationKey;
        bytes32 positionKey;
        uint traderSizeDelta;
        uint traderCollateralDelta;
        uint puppetSizeDelta;
        uint puppetCollateralDelta;
        uint transactionCost;
    }

    struct AllocationMatch {
        IERC20 collateralToken;
        address trader;
        address[] puppetList;
        uint[] collateralList;
    }

    struct Position {
        bytes32 allocationKey;
        uint traderSize;
        uint traderCollateral;
        uint puppetSize;
        uint puppetCollateral;
        uint cumulativeTransactionCost;
    }

    struct UnhandledCallback {
        GmxPositionUtils.OrderExecutionStatus status;
        GmxPositionUtils.Props order;
        bytes eventData;
    }

    mapping(bytes32 allocationKey => AllocationMatch) public allocationMatchMap;
    mapping(bytes32 requestKey => RequestAdjustment) public requestAdjustmentMap;
    mapping(bytes32 positionKey => Position) public positionMap;
    mapping(bytes32 positionKey => UnhandledCallback) public unhandledCallbackMap;

    mapping(address => Subaccount) public subaccountMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getAllocationMatchMap(bytes32 _key) external view returns (AllocationMatch memory) {
        return allocationMatchMap[_key];
    }

    function setAllocationMatchMap(bytes32 _key, AllocationMatch calldata _val) external auth {
        allocationMatchMap[_key] = _val;
    }

    function getRequestAdjustment(bytes32 _key) external view returns (RequestAdjustment memory) {
        return requestAdjustmentMap[_key];
    }

    function setRequestAdjustment(bytes32 _key, RequestAdjustment calldata _ra) external auth {
        requestAdjustmentMap[_key] = _ra;
    }

    function removeRequestAdjustment(bytes32 _key) external auth {
        delete requestAdjustmentMap[_key];
    }

    function removeRequestDecrease(bytes32 _key) external auth {
        delete requestAdjustmentMap[_key];
    }

    function getPosition(bytes32 _key) external view returns (Position memory) {
        return positionMap[_key];
    }

    function setPosition(bytes32 _key, Position calldata _mp) external auth {
        positionMap[_key] = _mp;
    }

    function removePosition(bytes32 _key) external auth {
        delete positionMap[_key];
    }

    function setUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus _status,
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) external auth {
        MirrorPositionStore.UnhandledCallback memory callbackResponse =
            MirrorPositionStore.UnhandledCallback({status: _status, order: _order, eventData: _eventData});

        unhandledCallbackMap[_key] = callbackResponse;
    }

    function getUnhandledCallback(bytes32 _key) external view returns (UnhandledCallback memory) {
        return unhandledCallbackMap[_key];
    }

    function removeUnhandledCallback(bytes32 _key) external auth {
        delete unhandledCallbackMap[_key];
    }

    function getSubaccount(address _user) external view returns (Subaccount) {
        return subaccountMap[_user];
    }

    function createSubaccount(address _user) external auth returns (Subaccount) {
        return subaccountMap[_user] = new Subaccount(this, _user);
    }
}
