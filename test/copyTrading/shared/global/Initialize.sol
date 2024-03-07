// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";
import {BaseSetup} from "test/base/BaseSetup.t.sol";
import {Context} from "test/utilities/Types.sol";
import {IDataStore} from "src/integrations/utilities/interfaces/IDataStore.sol";

contract Initialize is BaseSetup {

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function pausedStateTest(Context memory _context) external {
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_context.orchestrator);
        vm.expectRevert(bytes4(keccak256("Paused()")));
        _orchestratorInstance.registerRoute(_context.longETHRouteTypeKey);

        vm.expectRevert(bytes4(keccak256("Paused()")));
        _orchestratorInstance.subscribe(0, 0, address(0), address(0), bytes32(0));

        vm.expectRevert(bytes4(keccak256("Paused()")));
        _orchestratorInstance.deposit(0, address(0), address(0));

        vm.expectRevert(bytes4(keccak256("Paused()")));
        _orchestratorInstance.setThrottleLimit(0, bytes32(0));
    }

    function dataStoreOwnershipBeforeInitializationTest(Context memory _context) external {

        IDataStore _dataStoreInstance = IDataStore(_context.dataStore);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.updateOwnership(address(0), true);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.setUint(bytes32(0), 0);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.incrementUint(bytes32(0), 0);
    }

    function dataStoreOwnershipAfterInitializationTest(Context memory _context) external {

        IDataStore _dataStoreInstance = IDataStore(_context.dataStore);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.updateOwnership(address(0), true);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.setUint(bytes32(0), 0);

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        _dataStoreInstance.updateOwnership(address(0), true);
        vm.stopPrank();
    }
}