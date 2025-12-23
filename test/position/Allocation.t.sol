// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {PuppetAccount} from "src/position/PuppetAccount.sol";
import {PuppetModule} from "src/position/PuppetModule.sol";
import {SubaccountModule} from "src/position/SubaccountModule.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {MockERC20} from "test/mock/MockERC20.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "src/utils/interfaces/IERC7579Account.sol";
import {Access} from "src/utils/auth/Access.sol";
import {Permission} from "src/utils/auth/Permission.sol";

interface IPuppetModuleValidate {
    function validatePolicy(address _trader, IERC20 _collateralToken, uint _requestedAmount) external returns (uint);
}

contract MockSmartAccount {
    mapping(uint256 => address) public installedModules;

    function setInstalledModule(uint256 _moduleType, address _module) external {
        installedModules[_moduleType] = _module;
    }

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata) external view returns (bool) {
        return installedModules[moduleTypeId] == module;
    }

    function transfer(IERC20 token, address to, uint amount) external {
        token.transfer(to, amount);
    }

    // Execute validation through this account (msg.sender becomes this account)
    function executeValidation(address _module, address _trader, IERC20 _collateralToken, uint _requestedAmount)
        external
        returns (uint)
    {
        return IPuppetModuleValidate(_module).validatePolicy(_trader, _collateralToken, _requestedAmount);
    }
}

contract AllocationTest is Test {
    Dictatorship dictator;
    PuppetAccount puppetAccount;
    PuppetModule puppetModule;
    Allocation allocation;
    SubaccountModule traderHook;
    MockSmartAccount traderSubaccount;
    MockERC20 usdc;

    address owner;
    address trader;
    address puppet1;
    address puppet2;
    address puppet3;

    uint constant PRECISION = 1e30;

    function setUp() public {
        owner = makeAddr("owner");
        trader = makeAddr("trader");
        puppet1 = makeAddr("puppet1");
        puppet2 = makeAddr("puppet2");
        puppet3 = makeAddr("puppet3");

        vm.startPrank(owner);

        usdc = new MockERC20("USDC", "USDC", 6);
        dictator = new Dictatorship(owner);

        // Deploy Allocation first
        allocation = new Allocation(dictator, Allocation.Config({maxPuppetList: 100}));
        dictator.registerContract(allocation);

        // Deploy PuppetAccount (stores puppet policy state)
        puppetAccount = new PuppetAccount(dictator);
        dictator.registerContract(puppetAccount);

        // Deploy PuppetModule (contains validation logic)
        puppetModule = new PuppetModule(puppetAccount, address(allocation));

        // Deploy SubaccountModule (for trader subaccounts)
        traderHook = new SubaccountModule(allocation);

        // Deploy MockSmartAccount (simulates an ERC-7579 wallet for trader)
        traderSubaccount = new MockSmartAccount();
        traderSubaccount.setInstalledModule(4, address(traderHook)); // Hook module type

        // Set permissions for PuppetModule to call PuppetAccount
        dictator.setPermission(puppetAccount, puppetAccount.registerPuppet.selector, address(puppetModule));
        dictator.setPermission(puppetAccount, puppetAccount.setPolicy.selector, address(puppetModule));
        dictator.setPermission(puppetAccount, puppetAccount.removePolicy.selector, address(puppetModule));

        // Set permissions for SubaccountModule to call Allocation
        dictator.setPermission(allocation, allocation.registerSubaccount.selector, address(traderHook));
        dictator.setPermission(allocation, allocation.syncSettlement.selector, address(traderHook));
        dictator.setPermission(allocation, allocation.syncUtilization.selector, address(traderHook));

        // Owner permissions for testing
        dictator.setPermission(allocation, allocation.allocate.selector, owner);
        dictator.setPermission(allocation, allocation.utilize.selector, owner);
        dictator.setPermission(allocation, allocation.settle.selector, owner);
        dictator.setPermission(allocation, allocation.realize.selector, owner);
        dictator.setPermission(allocation, allocation.withdraw.selector, owner);
        dictator.setPermission(allocation, allocation.registerSubaccount.selector, owner);

        vm.stopPrank();

        // Register trader subaccount by simulating hook installation
        vm.prank(address(traderSubaccount));
        traderHook.onInstall("");
    }

    function _fundPuppet(address _puppet, uint _amount) internal {
        usdc.mint(_puppet, _amount);
        // Puppet approves Allocation to pull funds
        vm.prank(_puppet);
        usdc.approve(address(allocation), type(uint).max);
    }

    function _createPuppetSubaccount(address _puppet) internal returns (MockSmartAccount) {
        MockSmartAccount puppetSubaccount = new MockSmartAccount();
        puppetSubaccount.setInstalledModule(1, address(puppetModule)); // Validator module type

        // Register puppet by simulating module installation
        vm.prank(address(puppetSubaccount));
        puppetModule.onInstall("");

        // Fund the subaccount and set approval
        usdc.mint(address(puppetSubaccount), 0); // Will be funded separately
        vm.prank(address(puppetSubaccount));
        usdc.approve(address(allocation), type(uint).max);

        return puppetSubaccount;
    }

    function _setPolicy(address _puppetSubaccount, address _trader, uint _allowanceRate) internal {
        vm.prank(_puppetSubaccount);
        puppetModule.setPolicy(
            _trader,
            usdc,
            abi.encode(PuppetModule.PolicyParams({allowanceRate: _allowanceRate, throttleActivity: 1 hours, expiry: block.timestamp + 30 days}))
        );
    }

    function _getTraderMatchingKey(address _trader) internal view returns (bytes32) {
        return PositionUtils.getTraderMatchingKey(usdc, _trader);
    }

    function _allocate(
        address _trader,
        uint _traderAllocation,
        address[] memory _puppetList,
        uint[] memory _puppetAllocations
    ) internal {
        vm.prank(owner);
        allocation.allocate(
            usdc,
            _trader,
            IERC7579Account(address(traderSubaccount)),
            _traderAllocation,
            _puppetList,
            _puppetAllocations,
            address(puppetModule)
        );
    }

    function _utilize(bytes32 _traderKey, uint _amount) internal {
        // Simulate funds leaving traderSubaccount to GMX
        vm.prank(address(traderSubaccount));
        usdc.transfer(address(0xdead), _amount);
        vm.prank(owner);
        allocation.utilize(_traderKey, _amount, "");
    }

    function _depositSettlement(uint _amount) internal {
        // Mint to trader subaccount (simulating funds returning from GMX)
        usdc.mint(address(traderSubaccount), _amount);
    }

    function test_singlePuppet_profit() public {
        // Setup: create puppet subaccount with 1000 USDC, sets 100% allowance policy
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);
        _setPolicy(address(puppetSubaccount), trader, 10000); // 100%

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Allocate: puppet allocates 500 USDC (50% of 1000)
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(trader, 0, puppetList, allocations);

        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 500e6, "Puppet allocation should be 500");
        assertEq(allocation.totalAllocation(traderKey), 500e6, "Total allocation should be 500");
        assertEq(usdc.balanceOf(address(traderSubaccount)), 500e6, "Trader subaccount should have 500 USDC");

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
        allocation.realize(traderKey, address(puppetSubaccount));

        uint puppetAllocation = allocation.allocationBalance(traderKey, address(puppetSubaccount));
        assertEq(puppetAllocation, 600e6, "Puppet allocation should be 600 after profit");
    }

    function test_singlePuppet_loss() public {
        // Setup: create puppet subaccount with 1000 USDC, sets 100% allowance policy
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);
        _setPolicy(address(puppetSubaccount), trader, 10000); // 100%

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Allocate: puppet allocates 500 USDC
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(trader, 0, puppetList, allocations);

        // Utilize: trader uses 500 USDC
        _utilize(traderKey, 500e6);

        // Settlement: position returns 400 USDC (20% loss)
        _depositSettlement(400e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetSubaccount));

        uint puppetAllocation = allocation.allocationBalance(traderKey, address(puppetSubaccount));
        assertEq(puppetAllocation, 400e6, "Puppet allocation should be 400 after loss");
    }

    function test_multiplePuppets_profitDistribution() public {
        // Setup: two puppet subaccounts with different allocations
        MockSmartAccount puppetSubaccount1 = _createPuppetSubaccount(puppet1);
        MockSmartAccount puppetSubaccount2 = _createPuppetSubaccount(puppet2);
        usdc.mint(address(puppetSubaccount1), 1000e6);
        usdc.mint(address(puppetSubaccount2), 2000e6);
        _setPolicy(address(puppetSubaccount1), trader, 10000); // 100%
        _setPolicy(address(puppetSubaccount2), trader, 10000); // 100%

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Allocate: puppet1 = 300, puppet2 = 600
        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppetSubaccount1);
        puppetList[1] = address(puppetSubaccount2);
        uint[] memory allocations = new uint[](2);
        allocations[0] = 300e6;
        allocations[1] = 600e6;

        _allocate(trader, 0, puppetList, allocations);

        assertEq(allocation.totalAllocation(traderKey), 900e6, "Total allocation should be 900");

        // Utilize all
        _utilize(traderKey, 900e6);

        // Settlement: 50% profit -> 1350 USDC returned
        _depositSettlement(1350e6);

        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Realize both
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetSubaccount1));
        vm.prank(owner);
        allocation.realize(traderKey, address(puppetSubaccount2));

        // puppet1: 300 * 1.5 = 450
        // puppet2: 600 * 1.5 = 900
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount1)), 450e6, "Puppet1 should have 450");
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount2)), 900e6, "Puppet2 should have 900");
    }

    function test_policyValidation_exceedsAllowance_skipped() public {
        // Setup: create puppet subaccount with 1000 USDC, 50% allowance
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);
        _setPolicy(address(puppetSubaccount), trader, 5000); // 50% allowance

        bytes32 traderKey = _getTraderMatchingKey(trader);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 600e6; // Trying to allocate 60% when only 50% allowed

        // Should NOT revert, but skip the puppet (zero allocation reverts)
        vm.expectRevert();
        _allocate(trader, 0, puppetList, allocations);

        // Verify no allocation happened
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 0, "Puppet should have 0 allocation");
    }

    function test_policyValidation_expired_skipped() public {
        // Setup: create puppet subaccount with 1000 USDC
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Set policy that expires in 1 day
        vm.prank(address(puppetSubaccount));
        puppetModule.setPolicy(
            trader,
            usdc,
            abi.encode(PuppetModule.PolicyParams({allowanceRate: 10000, throttleActivity: 1 hours, expiry: block.timestamp + 1 days}))
        );

        // Skip past expiry
        skip(2 days);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        // Should NOT revert, but skip the puppet (zero allocation reverts)
        vm.expectRevert();
        _allocate(trader, 0, puppetList, allocations);

        // Verify no allocation happened
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 0, "Puppet should have 0 allocation");
    }

    function test_policyValidation_throttle_skipped() public {
        // Setup: create puppet subaccount with 1000 USDC
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);
        _setPolicy(address(puppetSubaccount), trader, 10000); // 100%, 1 hour throttle

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // First allocation
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 100e6;

        _allocate(trader, 0, puppetList, allocations);
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 100e6, "First allocation should succeed");

        // Try to allocate again immediately - should be skipped due to throttle (zero allocation reverts)
        allocations[0] = 100e6;
        vm.expectRevert();
        _allocate(trader, 0, puppetList, allocations);

        // Skip 1 hour, should work now
        skip(1 hours + 1);
        _allocate(trader, 0, puppetList, allocations);
        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 200e6, "Second allocation should succeed after throttle");
    }

    function test_withdraw() public {
        // Setup: create puppet subaccount with 1000 USDC
        MockSmartAccount puppetSubaccount = _createPuppetSubaccount(puppet1);
        usdc.mint(address(puppetSubaccount), 1000e6);
        _setPolicy(address(puppetSubaccount), trader, 10000);

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Allocate
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetSubaccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(trader, 0, puppetList, allocations);

        // Trader subaccount needs to approve Allocation to pull funds back for withdraw
        vm.prank(address(traderSubaccount));
        usdc.approve(address(allocation), type(uint).max);

        // Withdraw (no utilization yet, so can withdraw)
        vm.prank(owner);
        allocation.withdraw(usdc, traderKey, address(puppetSubaccount), 200e6);

        assertEq(allocation.allocationBalance(traderKey, address(puppetSubaccount)), 300e6, "Allocation should be 300 after withdraw");
        assertEq(usdc.balanceOf(address(puppetSubaccount)), 700e6, "Puppet should have 700 USDC (500 remaining + 200 withdrawn)");
    }

    function test_noUtilization_settleReverts() public {
        bytes32 traderKey = _getTraderMatchingKey(trader);

        vm.expectRevert();
        vm.prank(owner);
        allocation.settle(traderKey, usdc);
    }
}
