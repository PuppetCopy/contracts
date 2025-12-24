// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {MockERC20} from "test/mock/MockERC20.t.sol";
import {TestSmartAccount} from "test/mock/TestSmartAccount.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {Access} from "src/utils/auth/Access.sol";
import {Permission} from "src/utils/auth/Permission.sol";
import {Error} from "src/utils/Error.sol";

/**
 * @title AllocationTest
 * @notice Tests for Allocation contract as bundler
 * @dev Simulates flow: Trader calls allocate(), Allocation executes transfers from puppets
 */
contract AllocationTest is Test {
    Dictatorship dictator;
    Allocation allocation;
    TestSmartAccount traderAccount; // Trader's 7579 account
    MockERC20 usdc;

    address owner;
    address puppet1;
    address puppet2;
    address puppet3;

    uint constant PRECISION = 1e30;

    function setUp() public {
        owner = makeAddr("owner");
        puppet1 = makeAddr("puppet1");
        puppet2 = makeAddr("puppet2");
        puppet3 = makeAddr("puppet3");

        vm.startPrank(owner);

        usdc = new MockERC20("USDC", "USDC", 6);
        dictator = new Dictatorship(owner);

        // Deploy Allocation (executor + hook module)
        allocation = new Allocation(dictator, Allocation.Config({maxPuppetList: 100}));
        dictator.registerContract(allocation);

        // Deploy TestSmartAccount for trader
        traderAccount = new TestSmartAccount();
        // Install Allocation as hook (type 4) for settlement/utilization sync
        traderAccount.installModule(4, address(allocation), "");
        // Install Allocation as executor (type 2) - triggers onInstall() which registers the subaccount
        traderAccount.installModule(2, address(allocation), "");

        // Owner permissions for testing (owner simulates router)
        dictator.setPermission(allocation, allocation.allocate.selector, owner);
        dictator.setPermission(allocation, allocation.utilize.selector, owner);
        dictator.setPermission(allocation, allocation.settle.selector, owner);
        dictator.setPermission(allocation, allocation.realize.selector, owner);
        dictator.setPermission(allocation, allocation.withdraw.selector, owner);

        vm.stopPrank();
    }

    /**
     * @notice Create puppet account with trader as allowed validator
     * @dev Simulates: puppet subscribes to trader via Smart Sessions (validator module)
     */
    function _createPuppetAccount(address) internal returns (TestSmartAccount) {
        TestSmartAccount puppetAccount = new TestSmartAccount();
        // Install trader as validator (type 1) - simulates Smart Sessions subscription
        puppetAccount.installModule(1, address(traderAccount), "");
        return puppetAccount;
    }

    function _getTraderMatchingKey() internal view returns (bytes32) {
        return PositionUtils.getTraderMatchingKey(usdc, address(traderAccount));
    }

    /**
     * @notice Trader gathers allocations from puppets
     * @dev Router calls allocate() with trader as parameter
     */
    function _allocate(
        uint _traderAllocation,
        address[] memory _puppetList,
        uint[] memory _puppetAllocations
    ) internal {
        // Owner (simulating router) calls allocate with trader as parameter
        vm.prank(owner);
        allocation.allocate(
            usdc,
            IERC7579Account(address(traderAccount)),
            _traderAllocation,
            _puppetList,
            _puppetAllocations
        );
    }

    function _utilize(bytes32 _traderKey, uint _amount) internal {
        // Simulate funds leaving trader account to GMX
        vm.prank(address(traderAccount));
        usdc.transfer(address(0xdead), _amount);
        vm.prank(owner);
        allocation.utilize(_traderKey, _amount, "");
    }

    function _depositSettlement(uint _amount) internal {
        // Mint to trader account (simulating funds returning from GMX)
        usdc.mint(address(traderAccount), _amount);
    }

    function test_singlePuppet_profit() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate: trader gathers 500 USDC from puppet
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        assertEq(allocation.allocationBalance(traderKey, address(puppetAccount)), 500e6, "Puppet allocation should be 500");
        assertEq(allocation.totalAllocation(traderKey), 500e6, "Total allocation should be 500");
        assertEq(usdc.balanceOf(address(traderAccount)), 500e6, "Trader account should have 500 USDC");

        // Utilize: trader uses 500 USDC
        _utilize(traderKey, 500e6);

        assertEq(allocation.totalUtilization(traderKey), 500e6, "Total utilization should be 500");
        assertEq(allocation.totalAllocation(traderKey), 0, "Total allocation should be 0 after utilize");

        // Settlement: position returns 600 USDC (20% profit)
        _depositSettlement(600e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetAccount));

        uint puppetAllocation = allocation.allocationBalance(traderKey, address(puppetAccount));
        assertEq(puppetAllocation, 600e6, "Puppet allocation should be 600 after profit");
    }

    function test_singlePuppet_loss() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate: trader gathers 500 USDC from puppet
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        // Utilize: trader uses 500 USDC
        _utilize(traderKey, 500e6);

        // Settlement: position returns 400 USDC (20% loss)
        _depositSettlement(400e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetAccount));

        uint puppetAllocation = allocation.allocationBalance(traderKey, address(puppetAccount));
        assertEq(puppetAllocation, 400e6, "Puppet allocation should be 400 after loss");
    }

    function test_multiplePuppets_profitDistribution() public {
        // Setup: two puppet accounts with different allocations
        TestSmartAccount puppetAccount1 = _createPuppetAccount(puppet1);
        TestSmartAccount puppetAccount2 = _createPuppetAccount(puppet2);
        usdc.mint(address(puppetAccount1), 1000e6);
        usdc.mint(address(puppetAccount2), 2000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate: puppet1 = 300, puppet2 = 600
        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppetAccount1);
        puppetList[1] = address(puppetAccount2);
        uint[] memory allocations = new uint[](2);
        allocations[0] = 300e6;
        allocations[1] = 600e6;

        _allocate(0, puppetList, allocations);

        assertEq(allocation.totalAllocation(traderKey), 900e6, "Total allocation should be 900");

        // Utilize all
        _utilize(traderKey, 900e6);

        // Settlement: 50% profit -> 1350 USDC returned
        _depositSettlement(1350e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize both
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetAccount1));
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetAccount2));

        // puppet1: 300 * 1.5 = 450
        // puppet2: 600 * 1.5 = 900
        assertEq(allocation.allocationBalance(traderKey, address(puppetAccount1)), 450e6, "Puppet1 should have 450");
        assertEq(allocation.allocationBalance(traderKey, address(puppetAccount2)), 900e6, "Puppet2 should have 900");
    }

    function test_withdraw() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        // Trader account needs to approve Allocation to pull funds back for withdraw
        vm.prank(address(traderAccount));
        usdc.approve(address(allocation), type(uint).max);

        // Withdraw (no utilization yet, so can withdraw)
        vm.prank(owner);
        allocation.withdraw(usdc, traderKey, address(puppetAccount), 200e6);

        assertEq(allocation.allocationBalance(traderKey, address(puppetAccount)), 300e6, "Allocation should be 300 after withdraw");
        assertEq(usdc.balanceOf(address(puppetAccount)), 700e6, "Puppet should have 700 USDC (500 remaining + 200 withdrawn)");
    }

    function test_noUtilization_settleReverts() public {
        bytes32 traderKey = _getTraderMatchingKey();

        vm.expectRevert();
        vm.prank(owner);
        allocation.settle(traderKey, usdc);
    }

    function test_zeroAllocation_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 0;

        vm.expectRevert();
        vm.prank(owner);
        allocation.allocate(
            usdc,
            IERC7579Account(address(traderAccount)),
            0,
            puppetList,
            allocations
        );
    }

    function test_puppetRejectsTrader_skipped() public {
        // Create two puppets - one allows trader, one doesn't
        TestSmartAccount puppetAllowed = _createPuppetAccount(puppet1);
        TestSmartAccount puppetRejected = new TestSmartAccount(); // No permission set

        usdc.mint(address(puppetAllowed), 1000e6);
        usdc.mint(address(puppetRejected), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppetAllowed);
        puppetList[1] = address(puppetRejected);
        uint[] memory amounts = new uint[](2);
        amounts[0] = 500e6;
        amounts[1] = 500e6;

        // Allocate - puppetRejected should be skipped, puppetAllowed should succeed
        _allocate(0, puppetList, amounts);

        // Only puppetAllowed's allocation should be recorded
        assertEq(allocation.allocationBalance(traderKey, address(puppetAllowed)), 500e6);
        assertEq(allocation.allocationBalance(traderKey, address(puppetRejected)), 0);
        assertEq(allocation.totalAllocation(traderKey), 500e6);
        assertEq(usdc.balanceOf(address(traderAccount)), 500e6);
    }

    function test_allPuppetsReject_reverts() public {
        // Create puppet that doesn't allow trader
        TestSmartAccount puppetRejected = new TestSmartAccount();
        usdc.mint(address(puppetRejected), 1000e6);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetRejected);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        // Should revert because 0 allocation after all puppets rejected
        vm.expectRevert();
        vm.prank(owner);
        allocation.allocate(
            usdc,
            IERC7579Account(address(traderAccount)),
            0,
            puppetList,
            amounts
        );
    }

    function test_install_idempotent() public {
        // Trader is already registered from setUp (installed as both hook and executor)
        assertTrue(allocation.registeredSubaccount(traderAccount), "Should be registered");

        // Installing executor again - both still installed, no state change
        traderAccount.installModule(2, address(allocation), "");
        assertTrue(allocation.registeredSubaccount(traderAccount), "Should still be registered");
    }

    // ============ Uninstall Tests ============

    function test_uninstall_noActiveUtilization_succeeds() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        // No utilization - trader can uninstall
        assertTrue(allocation.registeredSubaccount(traderAccount), "Should be registered before uninstall");

        // Uninstall executor module - triggers Allocation.onUninstall()
        traderAccount.uninstallModule(2, address(allocation), "");

        assertFalse(allocation.registeredSubaccount(traderAccount), "Should be unregistered after uninstall");

        // Allocations still exist - puppets can withdraw
        assertEq(allocation.allocationBalance(traderKey, address(puppetAccount)), 500e6, "Allocation should remain");
    }

    function test_uninstall_activeUtilization_reverts() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        // Utilize funds (position opened)
        _utilize(traderKey, 500e6);
        assertEq(allocation.totalUtilization(traderKey), 500e6, "Utilization should be active");

        // Attempt to uninstall - should fail due to active utilization
        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveUtilization.selector, 500e6));
        traderAccount.uninstallModule(2, address(allocation), "");

        // Still registered
        assertTrue(allocation.registeredSubaccount(traderAccount), "Should still be registered");
    }

    function test_uninstall_afterSettlement_succeeds() public {
        // Setup: create puppet account with 1000 USDC
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey();

        // Allocate
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(0, puppetList, allocations);

        // Utilize all
        _utilize(traderKey, 500e6);

        // Settlement returns funds
        _depositSettlement(600e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize to clear utilization
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetAccount));

        assertEq(allocation.totalUtilization(traderKey), 0, "Utilization should be zero after realize");

        // Now uninstall should succeed
        traderAccount.uninstallModule(2, address(allocation), "");

        assertFalse(allocation.registeredSubaccount(traderAccount), "Should be unregistered");
    }

    function test_allocate_afterUninstall_reverts() public {
        // Setup puppet
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        // Uninstall trader executor module
        traderAccount.uninstallModule(2, address(allocation), "");

        // Attempt to allocate after uninstall
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        vm.expectRevert(Error.Allocation__UnregisteredSubaccount.selector);
        vm.prank(owner);
        allocation.allocate(
            usdc,
            IERC7579Account(address(traderAccount)),
            0,
            puppetList,
            allocations
        );
    }

    function test_uninstall_idempotent() public {
        // Uninstall executor first - both still show installed → unregisters
        traderAccount.uninstallModule(2, address(allocation), "");
        assertFalse(allocation.registeredSubaccount(traderAccount), "Should be unregistered");

        // Uninstall hook - only hook shows installed → no-op (already unregistered)
        traderAccount.uninstallModule(4, address(allocation), "");
        assertFalse(allocation.registeredSubaccount(traderAccount), "Should still be unregistered");
    }
}
