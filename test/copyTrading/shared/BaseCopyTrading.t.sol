// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";

import {Deposit} from "./puppet/Deposit.sol";
import {Subscribe} from "./puppet/Subscribe.sol";
import {ThrottleLimit} from "./puppet/ThrottleLimit.sol";
import {Withdraw} from "./puppet/Withdraw.sol";

import {RegisterRoute} from "./trader/RegisterRoute.sol";
import {RequestPosition} from "./trader/RequestPosition.sol";

import {Initialize} from "./global/Initialize.sol";
import {Fees} from "./global/Fees.sol";
import {CallbackAsserts} from "./global/CallbackAsserts.sol";

import {FuzzPuppetDeposit} from "./fuzz/puppet/Deposit.sol";
import {FuzzPuppetWithdraw} from "./fuzz/puppet/Withdraw.sol";
import {FuzzPuppetSubscribe} from "./fuzz/puppet/Subscribe.sol";

import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";
import {DecreaseSizeResolver} from "src/integrations/utilities/DecreaseSizeResolver.sol";

import {BaseSetup} from "test/base/BaseSetup.t.sol";

abstract contract BaseCopyTrading is BaseSetup {

    // ============================================================================================
    // Contracts
    // ============================================================================================

    address internal _routeFactory;
    address internal _orchestrator;
    address payable internal _decreaseSizeResolver;

    // ============================================================================================
    // Test Helpers
    // ============================================================================================

    Deposit internal _deposit;
    RegisterRoute internal _registerRoute;
    Initialize internal _initialize;
    Subscribe internal _subscribe;
    ThrottleLimit internal _throttleLimit;
    Withdraw internal _withdraw;
    Fees internal _fees;
    RequestPosition internal _requestPosition;
    CallbackAsserts internal _callbackAsserts;

    FuzzPuppetDeposit internal _fuzz_PuppetDeposit;
    FuzzPuppetWithdraw internal _fuzz_PuppetWithdraw;
    FuzzPuppetSubscribe internal _fuzz_PuppetSubscribe;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual override {
        BaseSetup.setUp();

        _deposit = new Deposit();
        _registerRoute = new RegisterRoute();
        _initialize = new Initialize();
        _subscribe = new Subscribe();
        _throttleLimit = new ThrottleLimit();
        _withdraw = new Withdraw();
        _fees = new Fees();
        _requestPosition = new RequestPosition();
        _callbackAsserts = new CallbackAsserts();

        _fuzz_PuppetDeposit = new FuzzPuppetDeposit();
        _fuzz_PuppetWithdraw = new FuzzPuppetWithdraw();
        _fuzz_PuppetSubscribe = new FuzzPuppetSubscribe();
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _setDictatorRoles() internal {
        if (_orchestrator == address(0)) revert("_setDictatorRoles: ZERO_ADDRESS");

        vm.startPrank(users.owner);
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_orchestrator);
        _setRoleCapability(1, address(_orchestrator), _orchestratorInstance.decreaseSize.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.updatePuppetKeeperMinExecutionFee.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.setRouteType.selector, true);
        _setRoleCapability( 0, address(_orchestrator), _orchestratorInstance.initialize.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.updateFees.selector, true);

        vm.stopPrank();
    }

    function _initializeDataStore() internal {
        vm.startPrank(users.owner);
        _dataStore.updateOwnership(_orchestrator, true);
        _dataStore.updateOwnership(_routeFactory, true);
        _dataStore.updateOwnership(users.owner, false);
        vm.stopPrank();
    }

    function _initializeResolver() internal {

        _depositFundsToGelato1Balance();

        vm.startPrank(users.owner);

        _setRoleCapability(0, _decreaseSizeResolver, DecreaseSizeResolver(_decreaseSizeResolver).createTask.selector, true);

        _setUserRole(_gelatoFunctionCallerArbi, 1, true);
        _setUserRole(_gelatoFunctionCallerArbi1, 1, true);
        _setUserRole(_gelatoFunctionCallerArbi2, 1, true);

        DecreaseSizeResolver(_decreaseSizeResolver).createTask(_orchestrator);

        vm.stopPrank();
    }
}