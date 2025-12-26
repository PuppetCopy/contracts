// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.33;

// import {Test} from "forge-std/src/Test.sol";
// import {console} from "forge-std/src/console.sol";

// import {Dictatorship} from "src/shared/Dictatorship.sol";
// import {Allocation} from "src/position/Allocation.sol";
// import {PositionUtils} from "src/position/utils/PositionUtils.sol";
// import {MockERC20} from "test/mock/MockERC20.t.sol";
// import {TestSmartAccount} from "test/mock/TestSmartAccount.t.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
// import {Access} from "src/utils/auth/Access.sol";
// import {Permission} from "src/utils/auth/Permission.sol";
// import {Error} from "src/utils/Error.sol";
// import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";
// import {ModeLib} from "erc7579/lib/ModeLib.sol";
// import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// /**
//  * @title AllocationTest
//  * @notice Tests for Allocation contract as bundler
//  * @dev Simulates flow: Master calls allocate(), Allocation executes transfers from puppets
//  */
// contract AllocationTest is Test {
//     Dictatorship dictator;
//     Allocation allocation;
//     TestSmartAccount masterAccount; // Master's 7579 account
//     MockERC20 usdc;

//     address owner;
//     address puppet1;
//     address puppet2;
//     address puppet3;

//     uint constant PRECISION = 1e30;

//     function setUp() public {
//         owner = makeAddr("owner");
//         puppet1 = makeAddr("puppet1");
//         puppet2 = makeAddr("puppet2");
//         puppet3 = makeAddr("puppet3");

//         vm.startPrank(owner);

//         usdc = new MockERC20("USDC", "USDC", 6);
//         dictator = new Dictatorship(owner);

//         // Deploy Allocation (executor + hook module)
//         allocation = new Allocation(dictator, Allocation.Config({maxPuppetList: 100, transferOutGasLimit: 200_000, callGasLimit: 200_000}));
//         dictator.registerContract(address(allocation));

//         // Deploy TestSmartAccount for master
//         masterAccount = new TestSmartAccount();
//         // Install test contract as validator (to allow execute calls in tests)
//         masterAccount.installModule(MODULE_TYPE_VALIDATOR, address(this), "");
//         // Install Allocation as hook for settlement/utilization sync
//         masterAccount.installModule(MODULE_TYPE_HOOK, address(allocation), "");
//         // Install Allocation as executor - triggers onInstall() which registers the subaccount
//         masterAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

//         // Owner permissions for testing (owner simulates router)
//         dictator.setPermission(allocation, allocation.allocate.selector, owner);
//         dictator.setPermission(allocation, allocation.withdraw.selector, owner);
//         dictator.setPermission(allocation, allocation.setWhitelistedTarget.selector, owner);

//         // Whitelist targets for hook validation
//         allocation.setWhitelistedTarget(address(usdc), true);
//         allocation.setWhitelistedTarget(address(0xdead), true);

//         vm.stopPrank();
//     }

//     /**
//      * @notice Create puppet account with master as allowed validator
//      * @dev Simulates: puppet subscribes to master via Smart Sessions (validator module)
//      */
//     function _createPuppetAccount(address) internal returns (TestSmartAccount) {
//         TestSmartAccount puppetAccount = new TestSmartAccount();
//         // Install master as validator - simulates Smart Sessions subscription
//         puppetAccount.installModule(MODULE_TYPE_VALIDATOR, address(masterAccount), "");
//         // Install Allocation as executor - allows Allocation to transfer funds on puppet's behalf
//         puppetAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
//         return puppetAccount;
//     }

//     function _getMatchingKey() internal view returns (bytes32) {
//         return PositionUtils.getMatchingKey(usdc, address(masterAccount));
//     }

//     function _isModuleInstalled(TestSmartAccount _account) internal view returns (bool) {
//         return _account.isModuleInstalled(2, address(allocation), "")
//             && _account.isModuleInstalled(4, address(allocation), "");
//     }

//     /**
//      * @notice Master gathers allocations from puppets
//      * @dev Router calls allocate() with master as parameter
//      */
//     function _allocate(
//         address[] memory _puppetList,
//         uint[] memory _puppetAllocations
//     ) internal {
//         // Owner (simulating router) calls allocate with master as parameter
//         vm.prank(owner);
//         allocation.allocate(
//             usdc,
//             address(masterAccount),
//             _puppetList,
//             _puppetAllocations
//         );
//     }

//     function _utilize(bytes32, uint _amount) internal {
//         // Execute transfer through subaccount - triggers postCheck hook which calls _utilize
//         masterAccount.execute(
//             ModeLib.encodeSimpleSingle(),
//             ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.transfer, (address(0xdead), _amount)))
//         );
//     }

//     function _depositSettlement(uint _amount) internal {
//         // Mint to master account (simulating funds returning from GMX)
//         usdc.mint(address(masterAccount), _amount);
//     }

//     function test_singlePuppet_profit() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: master gathers 500 USDC from puppet
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "Puppet allocation should be 500");
//         assertEq(allocation.totalAllocation(matchingKey), 500e6, "Total allocation should be 500");
//         assertEq(usdc.balanceOf(address(masterAccount)), 500e6, "Master account should have 500 USDC");

//         // Utilize: master uses 500 USDC
//         _utilize(matchingKey, 500e6);

//         assertEq(allocation.totalUtilization(matchingKey), 500e6, "Total utilization should be 500");
//         assertEq(allocation.totalAllocation(matchingKey), 0, "Total allocation should be 0 after utilize");

//         // Settlement: position returns 600 USDC (20% profit)
//         _depositSettlement(600e6);

//         // Realize (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         uint puppetAllocation = allocation.allocationBalance(matchingKey, address(puppetAccount));
//         assertEq(puppetAllocation, 600e6, "Puppet allocation should be 600 after profit");
//     }

//     function test_singlePuppet_loss() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: master gathers 500 USDC from puppet
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Utilize: master uses 500 USDC
//         _utilize(matchingKey, 500e6);

//         // Settlement: position returns 400 USDC (20% loss)
//         _depositSettlement(400e6);

//         // Realize (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         uint puppetAllocation = allocation.allocationBalance(matchingKey, address(puppetAccount));
//         assertEq(puppetAllocation, 400e6, "Puppet allocation should be 400 after loss");
//     }

//     function test_multiplePuppets_profitDistribution() public {
//         // Setup: two puppet accounts with different allocations
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 2000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: puppet1 = 300, puppet2 = 600
//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         uint[] memory allocations = new uint[](2);
//         allocations[0] = 300e6;
//         allocations[1] = 600e6;

//         _allocate(puppetList, allocations);

//         assertEq(allocation.totalAllocation(matchingKey), 900e6, "Total allocation should be 900");

//         // Utilize all
//         _utilize(matchingKey, 900e6);

//         // Settlement: 50% profit -> 1350 USDC returned
//         _depositSettlement(1350e6);

//         // Realize both (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);

//         // puppet1: 300 * 1.5 = 450
//         // puppet2: 600 * 1.5 = 900
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 450e6, "Puppet1 should have 450");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 900e6, "Puppet2 should have 900");
//     }

//     function test_withdraw() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Withdraw (no utilization yet, so can withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 200e6);

//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 300e6, "Allocation should be 300 after withdraw");
//         assertEq(usdc.balanceOf(address(puppetAccount)), 700e6, "Puppet should have 700 USDC (500 remaining + 200 withdrawn)");
//     }

//     function test_zeroAllocation_reverts() public {
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 0;

//         vm.expectRevert();
//         vm.prank(owner);
//         allocation.allocate(
//             usdc,
//             address(masterAccount),
//             puppetList,
//             allocations
//         );
//     }

//     function test_puppetRejectsMaster_skipped() public {
//         // Create two puppets - one allows master, one doesn't
//         TestSmartAccount puppetAllowed = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetRejected = new TestSmartAccount(); // No permission set

//         usdc.mint(address(puppetAllowed), 1000e6);
//         usdc.mint(address(puppetRejected), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAllowed);
//         puppetList[1] = address(puppetRejected);
//         uint[] memory amounts = new uint[](2);
//         amounts[0] = 500e6;
//         amounts[1] = 500e6;

//         // Allocate - puppetRejected should be skipped, puppetAllowed should succeed
//         _allocate(puppetList, amounts);

//         // Only puppetAllowed's allocation should be recorded
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAllowed)), 500e6);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetRejected)), 0);
//         assertEq(allocation.totalAllocation(matchingKey), 500e6);
//         assertEq(usdc.balanceOf(address(masterAccount)), 500e6);
//     }

//     function test_allPuppetsReject_reverts() public {
//         // Create puppet that doesn't allow master
//         TestSmartAccount puppetRejected = new TestSmartAccount();
//         usdc.mint(address(puppetRejected), 1000e6);

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetRejected);
//         uint[] memory amounts = new uint[](1);
//         amounts[0] = 500e6;

//         // Should revert because 0 allocation after all puppets rejected
//         vm.expectRevert();
//         vm.prank(owner);
//         allocation.allocate(
//             usdc,
//             address(masterAccount),
//             puppetList,
//             amounts
//         );
//     }

//     function test_install_idempotent() public {
//         // Master is already registered from setUp (installed as both hook and executor)
//         assertTrue(_isModuleInstalled(masterAccount), "Should be registered");

//         // Installing executor again - both still installed, no state change
//         masterAccount.installModule(2, address(allocation), "");
//         assertTrue(_isModuleInstalled(masterAccount), "Should still be registered");
//     }

//     // ============ Distribution Tests ============

//     function test_partialUtilization_distribution() public {
//         // Setup: two puppets
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: puppet1 = 400, puppet2 = 600
//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         uint[] memory allocations = new uint[](2);
//         allocations[0] = 400e6;
//         allocations[1] = 600e6;

//         _allocate(puppetList, allocations);

//         // Utilize only 50% (500 of 1000)
//         _utilize(matchingKey, 500e6);

//         assertEq(allocation.totalUtilization(matchingKey), 500e6, "Utilization should be 500");
//         assertEq(allocation.totalAllocation(matchingKey), 500e6, "Remaining allocation should be 500");

//         // Check proportional utilization
//         // puppet1: 400/1000 * 500 = 200 utilized
//         // puppet2: 600/1000 * 500 = 300 utilized
//         uint puppet1Util = allocation.getUtilization(matchingKey, address(puppetAccount1));
//         uint puppet2Util = allocation.getUtilization(matchingKey, address(puppetAccount2));
//         assertEq(puppet1Util, 200e6, "Puppet1 utilization should be 200");
//         assertEq(puppet2Util, 300e6, "Puppet2 utilization should be 300");

//         // Settlement: 20% profit on utilized amount -> 600 returned
//         _depositSettlement(600e6);

//         // Realize both (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);

//         // puppet1: 200 remaining + (200 util * 1.2) = 200 + 240 = 440
//         // puppet2: 300 remaining + (300 util * 1.2) = 300 + 360 = 660
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 440e6, "Puppet1 should have 440");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 660e6, "Puppet2 should have 660");
//     }

//     function test_multiplePuppets_lossDistribution() public {
//         // Setup: three puppets with different allocations
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         TestSmartAccount puppetAccount3 = _createPuppetAccount(puppet3);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 1000e6);
//         usdc.mint(address(puppetAccount3), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: puppet1 = 100, puppet2 = 200, puppet3 = 300
//         address[] memory puppetList = new address[](3);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         puppetList[2] = address(puppetAccount3);
//         uint[] memory allocations = new uint[](3);
//         allocations[0] = 100e6;
//         allocations[1] = 200e6;
//         allocations[2] = 300e6;

//         _allocate(puppetList, allocations);

//         // Utilize all
//         _utilize(matchingKey, 600e6);

//         // 50% loss -> 300 returned
//         _depositSettlement(300e6);

//         // Realize all (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount3), 0);

//         // Each gets 50% of their allocation
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 50e6, "Puppet1 should have 50");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 100e6, "Puppet2 should have 100");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount3)), 150e6, "Puppet3 should have 150");
//     }

//     function test_multipleAllocations_overTime() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 2000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);

//         // First allocation: 500
//         allocations[0] = 500e6;
//         _allocate(puppetList, allocations);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "First allocation");

//         // Second allocation: 300 more
//         allocations[0] = 300e6;
//         _allocate(puppetList, allocations);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 800e6, "After second allocation");
//         assertEq(allocation.totalAllocation(matchingKey), 800e6, "Total after two allocations");

//         // Utilize and settle
//         _utilize(matchingKey, 800e6);
//         _depositSettlement(1000e6); // 25% profit

//         // Realize (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 1000e6, "Should have 1000 after profit");
//     }

//     function test_withdraw_withPendingUtilization_reverts() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Utilize funds
//         _utilize(matchingKey, 500e6);

//         // Attempt withdraw before settlement - should revert
//         vm.prank(address(masterAccount));
//         usdc.approve(address(allocation), type(uint).max);

//         vm.expectRevert(abi.encodeWithSelector(Error.Allocation__UtilizationNotSettled.selector, 500e6));
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 100e6);
//     }

//     function test_maxPuppetList_reverts() public {
//         // Create more puppets than allowed
//         uint maxPuppets = allocation.getConfig().maxPuppetList;
//         address[] memory puppetList = new address[](maxPuppets + 1);
//         uint[] memory allocations = new uint[](maxPuppets + 1);

//         for (uint i = 0; i <= maxPuppets; i++) {
//             puppetList[i] = address(uint160(i + 1000));
//             allocations[i] = 1e6;
//         }

//         vm.expectRevert(abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, maxPuppets + 1, maxPuppets));
//         vm.prank(owner);
//         allocation.allocate(
//             usdc,
//             address(masterAccount),
//             puppetList,
//             allocations
//         );
//     }

//     // ============ Uninstall Tests ============

//     function test_uninstall_noActiveUtilization_succeeds() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // No utilization - master can uninstall
//         assertTrue(_isModuleInstalled(masterAccount), "Should be registered before uninstall");

//         // Uninstall executor module - triggers Allocation.onUninstall()
//         masterAccount.uninstallModule(2, address(allocation), "");

//         assertFalse(_isModuleInstalled(masterAccount), "Should be unregistered after uninstall");

//         // Allocations still exist - puppets can withdraw
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "Allocation should remain");
//     }

//     function test_uninstall_activeUtilization_reverts() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Utilize funds (position opened)
//         _utilize(matchingKey, 500e6);
//         assertEq(allocation.totalUtilization(matchingKey), 500e6, "Utilization should be active");

//         // Attempt to uninstall - should fail due to active utilization
//         vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveUtilization.selector, 500e6));
//         masterAccount.uninstallModule(2, address(allocation), "");

//         // Still registered
//         assertTrue(_isModuleInstalled(masterAccount), "Should still be registered");
//     }

//     function test_uninstall_afterSettlement_succeeds() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Utilize all
//         _utilize(matchingKey, 500e6);

//         // Settlement returns funds
//         _depositSettlement(600e6);

//         // Realize to clear utilization (settle is called internally by withdraw)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         assertEq(allocation.totalUtilization(matchingKey), 0, "Utilization should be zero after realize");

//         // Now uninstall should succeed
//         masterAccount.uninstallModule(2, address(allocation), "");

//         assertFalse(_isModuleInstalled(masterAccount), "Should be unregistered");
//     }

//     function test_allocate_afterUninstall_reverts() public {
//         // Setup puppet
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         // Uninstall master executor module
//         masterAccount.uninstallModule(2, address(allocation), "");

//         // Attempt to allocate after uninstall
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         vm.expectRevert(Error.Allocation__UnregisteredSubaccount.selector);
//         vm.prank(owner);
//         allocation.allocate(
//             usdc,
//             address(masterAccount),
//             puppetList,
//             allocations
//         );
//     }

//     function test_uninstall_idempotent() public {
//         // Uninstall executor first - both still show installed → unregisters
//         masterAccount.uninstallModule(2, address(allocation), "");
//         assertFalse(_isModuleInstalled(masterAccount), "Should be unregistered");

//         // Uninstall hook - only hook shows installed → no-op (already unregistered)
//         masterAccount.uninstallModule(4, address(allocation), "");
//         assertFalse(_isModuleInstalled(masterAccount), "Should still be unregistered");
//     }

//     // ============ Hook Flow Tests ============

//     function test_hookFlow_utilization() public {
//         // Setup: create puppet account with 1000 USDC
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         assertEq(usdc.balanceOf(address(masterAccount)), 500e6, "Master should have 500");
//         assertEq(allocation.totalUtilization(matchingKey), 0, "No utilization yet");

//         // Execute transfer via hooks - this should trigger utilization detection
//         _utilize(bytes32(0), 300e6);

//         // Utilization should be detected automatically via postCheck
//         assertEq(allocation.totalUtilization(matchingKey), 300e6, "Utilization should be 300 via hook");
//         assertEq(allocation.totalAllocation(matchingKey), 200e6, "Allocation should be 200 remaining");
//     }

//     function test_hookFlow_settlement() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         // Utilize via hooks
//         _utilize(bytes32(0), 500e6);

//         assertEq(allocation.totalUtilization(matchingKey), 500e6, "Full utilization");

//         // Simulate profit returning (GMX sends funds back)
//         usdc.mint(address(masterAccount), 600e6);

//         // Any execution should trigger settlement detection via preCheck
//         masterAccount.execute(
//             ModeLib.encodeSimpleSingle(),
//             ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.transfer, (address(0xdead), 0)))
//         );

//         // Settlement should be detected - recorded balance updated
//         assertEq(allocation.subaccountRecordedBalance(matchingKey), 600e6, "Recorded balance should include settlement");
//     }

//     function test_hookFlow_noChange() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         uint utilizationBefore = allocation.totalUtilization(matchingKey);
//         uint allocationBefore = allocation.totalAllocation(matchingKey);

//         // Execute something that doesn't change USDC balance
//         masterAccount.execute(
//             ModeLib.encodeSimpleSingle(),
//             ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.balanceOf, (address(masterAccount))))
//         );

//         // State should be unchanged
//         assertEq(allocation.totalUtilization(matchingKey), utilizationBefore, "Utilization unchanged");
//         assertEq(allocation.totalAllocation(matchingKey), allocationBefore, "Allocation unchanged");
//     }

//     function test_hookFlow_unregisteredAccount_noOp() public {
//         // Create a new account that's NOT registered with Allocation
//         TestSmartAccount unregisteredAccount = new TestSmartAccount();
//         unregisteredAccount.installModule(MODULE_TYPE_VALIDATOR, address(this), "");
//         unregisteredAccount.installModule(MODULE_TYPE_HOOK, address(allocation), "");
//         usdc.mint(address(unregisteredAccount), 1000e6);

//         // Execute with hooks - should not revert, just no-op
//         unregisteredAccount.execute(
//             ModeLib.encodeSimpleSingle(),
//             ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.transfer, (address(0xdead), 100e6)))
//         );

//         // Transfer happened but no allocation tracking (unregistered)
//         assertEq(usdc.balanceOf(address(unregisteredAccount)), 900e6, "Transfer should succeed");
//     }

//     // ============ Lazy Distribution Tests ============

//     function test_lazyDistribution_delayedClaim() public {
//         // Setup: two puppets
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // Allocate: puppet1 = 400, puppet2 = 600
//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         uint[] memory allocations = new uint[](2);
//         allocations[0] = 400e6;
//         allocations[1] = 600e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 1000e6);
//         _depositSettlement(1200e6); // 20% profit

//         // Puppet1 claims immediately
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 480e6, "Puppet1: 400 * 1.2");

//         // Puppet2 waits... claims later
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 720e6, "Puppet2: 600 * 1.2");

//         // Both should get correct amounts regardless of claim timing
//         assertEq(allocation.totalUtilization(matchingKey), 0, "All utilization cleared");
//     }

//     function test_lazyDistribution_unclaimed_getsSubsequentSettlements() public {
//         // Test: User who doesn't claim continues to receive settlement from subsequent cycles
//         // because their utilization remains active (funds still "at risk")
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         uint[] memory allocations = new uint[](2);
//         allocations[0] = 400e6;
//         allocations[1] = 600e6;

//         // Allocate and utilize
//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 1000e6);
//         _depositSettlement(1200e6); // 20% profit

//         // Puppet1 claims immediately
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 480e6, "Puppet1 after first settle");

//         // Puppet2 doesn't claim - their 600e6 utilization is still active!
//         // Puppet1 re-allocates their 480e6
//         allocations[0] = 480e6;
//         allocations[1] = 0;
//         _allocate(puppetList, allocations);

//         // Utilize puppet1's new 480e6, but puppet2's 600e6 util is still in totalUtil
//         // totalUtil = 600e6 (puppet2's unclaimed) + 480e6 (puppet1's new) = 1080e6
//         _utilize(matchingKey, 480e6);
//         _depositSettlement(576e6); // Settlement on 1080 totalUtil

//         // Puppet2 claims - gets settlement from BOTH cycles since their util was active for both
//         // cumulative = 1.2 (first) + 576/1080 (second) ≈ 1.733
//         // realized = 600e6 * 1.733 ≈ 1040e6
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);
//         // Puppet2 benefits from being "in the pool" for both settlements
//         assertApproxEqAbs(
//             allocation.allocationBalance(matchingKey, address(puppetAccount2)),
//             1040e6,
//             1e6,
//             "Puppet2 gets both settlements"
//         );

//         // Puppet1 claims second cycle
//         // Their checkpoint was at 1.2 (after first claim), now cumulative is 1.733
//         // realized = 480e6 * (1.733 - 1.2) = 480e6 * 0.533 ≈ 256e6
//         // But wait - their allocationBalance is 960e6 (480 from first + 480 from second alloc)
//         // So final = 960e6 + 256e6 - 480e6 = 736e6
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         assertApproxEqAbs(
//             allocation.allocationBalance(matchingKey, address(puppetAccount1)),
//             736e6,
//             1e6,
//             "Puppet1 second cycle"
//         );
//     }

//     function test_lazyDistribution_claimAfterNewEpoch() public {
//         // Setup: two puppets
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 2000e6);
//         usdc.mint(address(puppetAccount2), 2000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](2);
//         puppetList[0] = address(puppetAccount1);
//         puppetList[1] = address(puppetAccount2);
//         uint[] memory allocations = new uint[](2);

//         // First allocation
//         allocations[0] = 300e6;
//         allocations[1] = 700e6;
//         _allocate(puppetList, allocations);

//         // Full utilize and settle
//         _utilize(matchingKey, 1000e6);
//         _depositSettlement(1500e6); // 50% profit

//         // Only puppet1 claims
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 450e6, "Puppet1: 300 * 1.5");

//         // New epoch starts (puppet1 re-allocates)
//         allocations[0] = 450e6;
//         allocations[1] = 0; // puppet2 doesn't add more
//         _allocate(puppetList, allocations);

//         // Puppet2 claims now (after new epoch started)
//         // Should still get correct amount from first cycle
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 1050e6, "Puppet2: 700 * 1.5");
//     }

//     // ============ Edge Case Tests ============

//     function test_edgeCase_nearTotalLoss() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 500e6);

//         // Near-total loss - deposit 1 wei to trigger settlement
//         // (with 0 settlement, cumulative doesn't increase and withdraw reverts)
//         _depositSettlement(1);

//         // Claim - gets 1 wei (the settled amount)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);
//         // allocation = 500e6 + 1 - 500e6 = 1
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 1, "Near-total loss = 1 wei");
//     }

//     function test_edgeCase_breakEven() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 500e6);

//         // Break even - same amount returns
//         _depositSettlement(500e6);

//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "Break even = original amount");
//     }

//     function test_edgeCase_dustUtilization() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 1; // 1 wei allocation

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 1); // 1 wei utilization

//         // Settlement with profit
//         _depositSettlement(2); // 100% profit but dust

//         // Should be able to claim even with dust (rounds to 0 or 1)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         // Utilization should be cleared
//         assertEq(allocation.totalUtilization(matchingKey), 0, "Dust utilization cleared");
//     }

//     function test_edgeCase_allocateDuringActiveUtilization() public {
//         // Setup: two puppets
//         TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
//         TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
//         usdc.mint(address(puppetAccount1), 1000e6);
//         usdc.mint(address(puppetAccount2), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         // First allocation from puppet1
//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount1);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 500e6);

//         // Puppet1 has active utilization, puppet2 joins
//         puppetList[0] = address(puppetAccount2);
//         allocations[0] = 300e6;
//         _allocate(puppetList, allocations);

//         // Check states
//         assertEq(allocation.getUtilization(matchingKey, address(puppetAccount1)), 500e6, "Puppet1 full utilization");
//         assertEq(allocation.getUtilization(matchingKey, address(puppetAccount2)), 0, "Puppet2 no utilization yet");
//         assertEq(allocation.totalAllocation(matchingKey), 300e6, "Only puppet2's allocation available");

//         // Utilize puppet2's allocation
//         _utilize(matchingKey, 300e6);

//         // Settlement
//         _depositSettlement(1000e6); // 25% profit on 800

//         // Both claim
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount1), 0);
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount2), 0);

//         // puppet1: 500 * 1.25 = 625, puppet2: 300 * 1.25 = 375
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount1)), 625e6, "Puppet1 profit");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount2)), 375e6, "Puppet2 profit");
//     }

//     function test_edgeCase_withdrawWithNoAllocation() public {
//         bytes32 matchingKey = _getMatchingKey();
//         address randomUser = makeAddr("randomUser");

//         // User with no allocation tries to withdraw
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, randomUser, 0);

//         // Should succeed (no-op) with 0 allocation
//         assertEq(allocation.allocationBalance(matchingKey, randomUser), 0, "Still 0");
//     }

//     function test_edgeCase_withdrawMoreThanAvailable() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);

//         vm.prank(address(masterAccount));
//         usdc.approve(address(allocation), type(uint).max);

//         // Try to withdraw more than allocated
//         vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InsufficientAllocation.selector, 500e6, 600e6));
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 600e6);
//     }

//     function test_edgeCase_multipleUtilizeSettleCycles() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 2000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 1000e6;

//         _allocate(puppetList, allocations);

//         // Partial utilize
//         _utilize(matchingKey, 400e6);
//         assertEq(allocation.getUtilization(matchingKey, address(puppetAccount)), 400e6, "First utilize");

//         // More utilization
//         _utilize(matchingKey, 300e6);
//         assertEq(allocation.getUtilization(matchingKey, address(puppetAccount)), 700e6, "Second utilize");

//         // Remaining allocation
//         assertEq(allocation.totalAllocation(matchingKey), 300e6, "300 remaining");

//         // Settlement for 700 utilized
//         _depositSettlement(840e6); // 20% profit on 700 = 840

//         // Claim
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         // Should have: 300 (remaining) + 840 (settled) = 1140
//         // But actually: remaining_alloc + realized - utilization
//         // = 1000 + 840 - 700 = 1140
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 1140e6, "After claim");
//     }

//     function test_edgeCase_syncOnlyWithdraw() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 500e6);
//         _depositSettlement(600e6);

//         uint balanceBefore = usdc.balanceOf(address(puppetAccount));

//         // Sync-only withdraw (amount = 0)
//         vm.prank(owner);
//         allocation.withdraw(usdc, matchingKey, address(puppetAccount), 0);

//         // Balance unchanged (no transfer), but allocation updated
//         assertEq(usdc.balanceOf(address(puppetAccount)), balanceBefore, "No transfer for sync");
//         assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 600e6, "Allocation updated");
//         assertEq(allocation.totalUtilization(matchingKey), 0, "Utilization cleared");
//     }

//     function test_edgeCase_pendingSettlementView() public {
//         // Setup
//         TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
//         usdc.mint(address(puppetAccount), 1000e6);

//         bytes32 matchingKey = _getMatchingKey();

//         address[] memory puppetList = new address[](1);
//         puppetList[0] = address(puppetAccount);
//         uint[] memory allocations = new uint[](1);
//         allocations[0] = 500e6;

//         _allocate(puppetList, allocations);
//         _utilize(matchingKey, 500e6);

//         // Before settlement
//         assertEq(allocation.pendingSettlement(matchingKey, address(puppetAccount)), 0, "No pending before settle");

//         // After settlement deposited but not synced
//         _depositSettlement(600e6);

//         // Trigger settle via hook (any execution)
//         masterAccount.execute(
//             ModeLib.encodeSimpleSingle(),
//             ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.balanceOf, (address(masterAccount))))
//         );

//         // Now pending should show
//         assertEq(allocation.pendingSettlement(matchingKey, address(puppetAccount)), 600e6, "Pending after settle");
//     }
// }
