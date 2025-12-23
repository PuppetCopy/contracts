// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {Account as PuppetAccount} from "src/position/Account.sol";
import {Allocation} from "src/position/Allocation.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {TraderSubaccountHook} from "src/position/TraderSubaccountHook.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {MockERC20} from "test/mock/MockERC20.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Access} from "src/utils/auth/Access.sol";
import {Permission} from "src/utils/auth/Permission.sol";

contract MockSmartAccount {
    address public installedHook;

    function setInstalledHook(address _hook) external {
        installedHook = _hook;
    }

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata) external view returns (bool) {
        return moduleTypeId == 4 && module == installedHook;
    }

    function transfer(IERC20 token, address to, uint amount) external {
        token.transfer(to, amount);
    }
}

contract AllocationTest is Test {
    Dictatorship dictator;
    TokenRouter tokenRouter;
    AccountStore accountStore;
    PuppetAccount account;
    Allocation allocation;
    Subscribe subscribe;
    TraderSubaccountHook hook;
    MockSmartAccount traderAccount;
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

        // Deploy TokenRouter
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config({transferGasLimit: 200_000}));
        dictator.registerContract(tokenRouter);

        // Deploy AccountStore
        accountStore = new AccountStore(dictator, tokenRouter);

        // Deploy Account
        account = new PuppetAccount(dictator, accountStore, PuppetAccount.Config({transferOutGasLimit: 200_000}));
        dictator.registerContract(account);

        // Deploy Allocation
        allocation = new Allocation(dictator, Allocation.Config({maxPuppetList: 100}));
        dictator.registerContract(allocation);

        // Deploy Subscribe
        subscribe = new Subscribe(
            dictator,
            Subscribe.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        dictator.registerContract(subscribe);

        // Deploy TraderSubaccountHook
        hook = new TraderSubaccountHook(allocation);

        // Deploy MockSmartAccount (simulates an ERC-7579 wallet)
        traderAccount = new MockSmartAccount();
        traderAccount.setInstalledHook(address(hook));

        // Set access permissions
        dictator.setAccess(Access(address(accountStore)), address(account));
        dictator.setAccess(Access(address(accountStore)), owner);
        dictator.setAccess(Access(address(accountStore)), address(traderAccount));

        // TokenRouter permission
        dictator.setPermission(tokenRouter, TokenRouter.transfer.selector, address(accountStore));

        // Account functions that Allocation calls
        dictator.setPermission(account, PuppetAccount.setUserBalance.selector, address(allocation));
        dictator.setPermission(account, PuppetAccount.setBalanceList.selector, address(allocation));
        dictator.setPermission(account, PuppetAccount.transferOut.selector, address(allocation));
        dictator.setPermission(account, PuppetAccount.getBalanceList.selector, address(allocation));

        // Allocation functions that Subscribe calls
        dictator.setPermission(allocation, Allocation.initializeTraderActivityThrottle.selector, address(subscribe));

        // Hook permissions for registration and sync
        dictator.setPermission(allocation, Allocation.registerSubaccount.selector, address(hook));
        dictator.setPermission(allocation, Allocation.syncSettlement.selector, address(hook));
        dictator.setPermission(allocation, Allocation.syncUtilization.selector, address(hook));

        // Owner permissions for testing
        dictator.setPermission(account, PuppetAccount.deposit.selector, owner);
        dictator.setPermission(account, PuppetAccount.setDepositCapList.selector, owner);
        dictator.setPermission(account, PuppetAccount.setUserBalance.selector, owner);
        dictator.setPermission(account, PuppetAccount.setBalanceList.selector, owner);
        dictator.setPermission(account, PuppetAccount.transferOut.selector, owner);

        dictator.setPermission(allocation, Allocation.allocate.selector, owner);
        dictator.setPermission(allocation, Allocation.utilize.selector, owner);
        dictator.setPermission(allocation, Allocation.settle.selector, owner);
        dictator.setPermission(allocation, Allocation.realize.selector, owner);
        dictator.setPermission(allocation, Allocation.withdraw.selector, owner);
        dictator.setPermission(allocation, Allocation.registerSubaccount.selector, owner);

        dictator.setPermission(subscribe, Subscribe.rule.selector, owner);

        // Set deposit caps
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = usdc;
        uint[] memory caps = new uint[](1);
        caps[0] = 1_000_000e6; // 1M USDC cap
        account.setDepositCapList(tokens, caps);

        vm.stopPrank();

        // Register trader account by simulating hook installation
        // (onInstall is called by the smart account when installing the hook)
        vm.prank(address(traderAccount));
        hook.onInstall("");
    }

    function _deposit(address _user, uint _amount) internal {
        usdc.mint(_user, _amount);
        vm.prank(_user);
        usdc.approve(address(tokenRouter), _amount);
        vm.prank(owner);
        account.deposit(usdc, _user, _user, _amount);
    }

    function _setRule(address _puppet, address _trader, uint _allowanceRate) internal {
        vm.prank(owner);
        subscribe.rule(
            allocation,
            usdc,
            _puppet,
            _trader,
            Subscribe.RuleParams({
                allowanceRate: _allowanceRate,
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );
    }

    function _getTraderMatchingKey(address _trader) internal view returns (bytes32) {
        return PositionUtils.getTraderMatchingKey(usdc, _trader);
    }

    function _utilize(bytes32 _traderKey, uint _amount) internal {
        // Simulate funds leaving address(traderAccount) to GMX
        vm.prank(address(traderAccount));
        usdc.transfer(address(0xdead), _amount);
        vm.prank(owner);
        allocation.utilize(_traderKey, _amount);
    }

    // Deposit settlement funds to address(traderAccount) (simulating funds returning from GMX position)
    // Mints to BOTH locations because:
    // - address(traderAccount): where settle() reads the actual balance to compute unaccounted funds
    // - AccountStore: where withdraw() needs liquidity (withdraw only updates balance mappings,
    //   doesn't transfer from address(traderAccount), so AccountStore needs tokens for user withdrawals)
    function _depositSettlement(uint _amount) internal {
        usdc.mint(address(traderAccount), _amount);
        usdc.mint(address(accountStore), _amount);
    }

    function test_singlePuppet_profit() public {
        // Setup: puppet1 deposits 1000 USDC, sets 100% allowance
        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000); // 100%

        // Trader deposits 1000 USDC
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Fund: trader contributes 1000, puppet1 contributes 1000 (total 2000)
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Verify allocation (funds in address(traderAccount), not yet utilized)
        assertEq(allocation.allocationBalance(traderKey, trader), 1000e6, "trader allocation");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 allocation");
        assertEq(allocation.totalAllocation(traderKey), 2000e6, "total allocation");
        assertEq(allocation.totalUtilization(traderKey), 0, "no utilization yet");

        // Verify address(traderAccount) received funds
        assertEq(usdc.balanceOf(address(traderAccount)), 2000e6, "address(traderAccount) balance");

        // Utilize: all 2000 goes into a position (O(1) - no participant list needed)
        _utilize(traderKey, 2000e6);

        // Verify utilization (lazy calculation)
        assertEq(allocation.getUserUtilization(traderKey, trader), 1000e6, "trader utilization");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 utilization");
        assertEq(allocation.totalUtilization(traderKey), 2000e6, "total utilization");
        assertEq(allocation.totalAllocation(traderKey), 0, "allocation consumed");

        // Simulate profit: 2000 -> 2400 (20% profit)
        _depositSettlement(2400e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Check pending settlements
        uint traderPending = allocation.pendingSettlement(traderKey, trader);
        uint puppet1Pending = allocation.pendingSettlement(traderKey, puppet1);

        console.log("Trader pending:", traderPending);
        console.log("Puppet1 pending:", puppet1Pending);

        // Each should get 1200 (50% of 2400)
        assertEq(traderPending, 1200e6, "trader pending");
        assertEq(puppet1Pending, 1200e6, "puppet1 pending");

        // Realize - converts utilization back to allocation
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // Verify allocation balances (funds now in allocation, ready for next position)
        assertEq(allocation.allocationBalance(traderKey, trader), 1200e6, "trader allocation after realize");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1200e6, "puppet1 allocation after realize");

        // Withdraw to Account balance (optional - for users who want to exit)
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 1200e6);
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 1200e6);

        // Verify Account balances
        assertEq(account.userBalanceMap(usdc, trader), 1200e6, "trader final balance");
        assertEq(account.userBalanceMap(usdc, puppet1), 1200e6, "puppet1 final balance");
    }

    function test_singlePuppet_loss() public {
        // Setup: puppet1 deposits 1000 USDC, sets 100% allowance
        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000); // 100%

        // Trader deposits 1000 USDC
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Fund: total 2000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Utilize all funds
        _utilize(traderKey, 2000e6);

        // Simulate loss: 2000 -> 1600 (20% loss)
        _depositSettlement(1600e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Check pending settlements - each should get 800 (50% of 1600)
        uint traderPending = allocation.pendingSettlement(traderKey, trader);
        uint puppet1Pending = allocation.pendingSettlement(traderKey, puppet1);

        assertEq(traderPending, 800e6, "trader pending (loss)");
        assertEq(puppet1Pending, 800e6, "puppet1 pending (loss)");

        // Net P&L: put in 1000, got back 800 = -200 loss each
    }

    function test_multiplePuppets_proportionalDistribution() public {
        // Setup: 3 puppets with different contributions
        _deposit(puppet1, 1000e6);
        _deposit(puppet2, 500e6);
        _deposit(puppet3, 500e6);
        _setRule(puppet1, trader, 10000); // 100% of 1000 = 1000
        _setRule(puppet2, trader, 10000); // 100% of 500 = 500
        _setRule(puppet3, trader, 5000);  // 50% of 500 = 250

        // Trader deposits 250 USDC
        _deposit(trader, 250e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](3);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;
        puppetList[2] = puppet3;

        // Fund: trader=250, puppet1=1000, puppet2=500, puppet3=250, total=2000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 250e6, puppetList);

        // Verify allocation
        assertEq(allocation.allocationBalance(traderKey, trader), 250e6, "trader alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet2), 500e6, "puppet2 alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet3), 250e6, "puppet3 alloc");
        assertEq(allocation.totalAllocation(traderKey), 2000e6, "total alloc");

        // Utilize all 2000 (O(1))
        _utilize(traderKey, 2000e6);

        // Verify utilization (lazy calculation)
        assertEq(allocation.getUserUtilization(traderKey, trader), 250e6, "trader util");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 util");
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 500e6, "puppet2 util");
        assertEq(allocation.getUserUtilization(traderKey, puppet3), 250e6, "puppet3 util");
        assertEq(allocation.totalUtilization(traderKey), 2000e6, "total util");

        // Settle with 2000 (break-even)
        _depositSettlement(2000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each should get back exactly what they put in
        assertEq(allocation.pendingSettlement(traderKey, trader), 250e6, "trader break-even");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1000e6, "puppet1 break-even");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 break-even");
        assertEq(allocation.pendingSettlement(traderKey, puppet3), 250e6, "puppet3 break-even");
    }

    function test_multiplePuppets_profitDistribution() public {
        // Setup: puppet1=1000, puppet2=500, trader=500, total=2000
        _deposit(puppet1, 1000e6);
        _deposit(puppet2, 500e6);
        _setRule(puppet1, trader, 10000);
        _setRule(puppet2, trader, 10000);
        _deposit(trader, 500e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        // Utilize all funds
        _utilize(traderKey, 2000e6);

        // 50% profit: 2000 -> 3000
        _depositSettlement(3000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Distribution:
        // puppet1: 1000/2000 * 3000 = 1500
        // puppet2: 500/2000 * 3000 = 750
        // trader: 500/2000 * 3000 = 750
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1500e6, "puppet1 profit share");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 750e6, "puppet2 profit share");
        assertEq(allocation.pendingSettlement(traderKey, trader), 750e6, "trader profit share");

        // Total distributed = 3000
        uint total = allocation.pendingSettlement(traderKey, puppet1) +
                     allocation.pendingSettlement(traderKey, puppet2) +
                     allocation.pendingSettlement(traderKey, trader);
        assertEq(total, 3000e6, "total distribution");
    }

    function test_multipleSettlements() public {
        // Test multiple fund/settle cycles accumulate correctly
        _deposit(puppet1, 2000e6);
        _setRule(puppet1, trader, 5000); // 50%
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // First fund: trader=500, puppet1=1000, total=1500
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        // Utilize all funds
        _utilize(traderKey, 1500e6);

        // First settle: 1500 -> 1800 (20% profit)
        _depositSettlement(1800e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // puppet1: 1000/1500 * 1800 = 1200
        // trader: 500/1500 * 1800 = 600
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1200e6, "puppet1 after first settle");
        assertEq(allocation.pendingSettlement(traderKey, trader), 600e6, "trader after first settle");

        // Realize puppet1's share to allocation
        // puppet1 started with 2000, contributed 1000 (50% of 2000), remaining 1000 in Account
        // Settlement of 1800 -> puppet1 gets 1000/1500 * 1800 = 1200 -> now in allocation
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1200e6, "puppet1 allocation after realize");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 0, "puppet1 util cleared");

        // Withdraw to Account balance
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 1200e6);
        // puppet1 Account balance = 1000 (remaining from initial deposit) + 1200 (withdrawn) = 2200
        assertEq(account.userBalanceMap(usdc, puppet1), 2200e6, "puppet1 final balance");

        // Trader still has pending
        assertEq(allocation.pendingSettlement(traderKey, trader), 600e6, "trader still pending");
    }

    function test_noUtilization_settleReverts() public {
        bytes32 traderKey = _getTraderMatchingKey(trader);

        vm.prank(owner);
        vm.expectRevert();
        allocation.settle(traderKey, usdc);
    }

    function test_zeroRealize() public {
        // Scenario: User calls realize after utilize but BEFORE settlement
        // This is a destructive operation - realize without settlement zeros out the position

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Utilize funds
        _utilize(traderKey, 2000e6);

        // Verify state before realize
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 util before");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 alloc before");
        assertEq(allocation.totalUtilization(traderKey), 2000e6, "total util before");

        // No settlement yet, realize returns 0
        vm.prank(owner);
        uint realized = allocation.realize(traderKey, puppet1);
        assertEq(realized, 0, "no pending to realize");

        // IMPORTANT: Realize without settlement zeros out the position!
        // newAllocation = allocationBalance + realized - utilization = 1000 + 0 - 1000 = 0
        assertEq(allocation.allocationBalance(traderKey, puppet1), 0, "puppet1 alloc zeroed");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 0, "puppet1 util cleared");
        assertEq(allocation.totalUtilization(traderKey), 1000e6, "total util reduced by puppet1");

        // Trader's utilization is unaffected
        assertEq(allocation.getUserUtilization(traderKey, trader), 1000e6, "trader util unchanged");
    }

    // ============ Front-Running Prevention Tests ============

    function test_frontRunningPrevention() public {
        // Scenario: puppet1 joins, position opens, attacker tries to front-run settlement

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Fund and utilize
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // Position is profitable, about to settle
        // Attacker (puppet2) tries to front-run by funding now
        _deposit(puppet2, 1000e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours); // Pass throttle

        address[] memory attackerList = new address[](1);
        attackerList[0] = puppet2;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, attackerList);

        // Attacker now has allocation, but their checkpoint is AFTER the utilize()
        assertEq(allocation.allocationBalance(traderKey, puppet2), 1000e6, "attacker has allocation");

        // Settlement happens
        _depositSettlement(2400e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Attacker gets NOTHING because they joined after utilize()
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 0, "attacker has zero utilization");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 0, "attacker gets zero settlement");

        // Original participants get their fair share
        assertEq(allocation.pendingSettlement(traderKey, trader), 1200e6, "trader gets profit");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1200e6, "puppet1 gets profit");
    }

    function test_frontRunning_multipleSettlements() public {
        // Scenario: Attacker joins between two settlements, should only earn from second

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Round 1: fund and utilize
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // First settlement: 100% profit (2000 -> 4000)
        _depositSettlement(4000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Verify round 1 earnings
        assertEq(allocation.pendingSettlement(traderKey, trader), 2000e6, "trader r1 pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 2000e6, "puppet1 r1 pending");

        // Realize round 1
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // Attacker joins AFTER first profitable round
        _deposit(puppet2, 2000e6);
        _setRule(puppet2, trader, 10000);
        vm.warp(block.timestamp + 2 hours);

        address[] memory round2List = new address[](2);
        round2List[0] = puppet1;
        round2List[1] = puppet2;

        // Round 2: all participate (trader=2000, puppet1=2000, puppet2=2000)
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, round2List);

        // Total allocation: 2000 + 2000 + 2000 = 6000
        _utilize(traderKey, 6000e6);

        // Second settlement: break-even
        _depositSettlement(6000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Attacker only gets their fair share from round 2 (not round 1 profits)
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 2000e6, "attacker only gets r2 share");
        assertEq(allocation.pendingSettlement(traderKey, trader), 2000e6, "trader r2 share");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 2000e6, "puppet1 r2 share");
    }

    function test_frontRunning_cannotEscapeLosses() public {
        // Scenario: User tries to withdraw before a losing position settles

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // Position is losing (not yet settled)
        // User tries to withdraw - but they can't because funds are utilized
        uint available = allocation.getAvailableAllocation(traderKey, puppet1);
        assertEq(available, 0, "no available allocation during utilization");

        // User cannot escape the loss
        vm.prank(owner);
        vm.expectRevert();
        allocation.withdraw(account, usdc, traderKey, puppet1, 1);

        // Settlement with 50% loss
        _depositSettlement(1000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // User must take their loss
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 500e6, "puppet1 takes loss");
    }

    function test_frontRunning_joinAfterUtilize_noEarnings() public {
        // Scenario: Attacker joins after utilize, should have ZERO utilization
        // This is the core front-running protection

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Full utilize
        _utilize(traderKey, 2000e6);

        // Attacker joins AFTER utilize
        _deposit(puppet2, 1000e6);
        _setRule(puppet2, trader, 10000);
        vm.warp(block.timestamp + 2 hours);

        address[] memory attackerList = new address[](1);
        attackerList[0] = puppet2;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, attackerList);

        // Attacker has allocation but ZERO utilization
        assertEq(allocation.allocationBalance(traderKey, puppet2), 1000e6, "attacker has allocation");
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 0, "attacker ZERO utilization");

        // Original participants have full utilization
        assertEq(allocation.getUserUtilization(traderKey, trader), 1000e6, "trader full util");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 full util");

        // Settlement: 100% profit
        _depositSettlement(4000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Attacker gets NOTHING
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 0, "attacker gets ZERO");

        // Original participants split the profit equally
        assertEq(allocation.pendingSettlement(traderKey, trader), 2000e6, "trader gets half");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 2000e6, "puppet1 gets half");

        // Realize and verify attacker's allocation is preserved for next round
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // Attacker's 1000 is ready for next utilize
        assertEq(allocation.allocationBalance(traderKey, puppet2), 1000e6, "attacker alloc preserved");
        assertEq(allocation.getAvailableAllocation(traderKey, puppet2), 1000e6, "attacker available for next");
    }

    function test_frontRunning_fundingDuringUtilization_isolated() public {
        // Scenario: User funds MORE while having active utilization
        // New funds should NOT participate in current position

        _deposit(puppet1, 2000e6);
        _setRule(puppet1, trader, 5000); // 50% = 1000
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // First fund: puppet1 contributes 1000 (50% of 2000)
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 initial alloc");

        // Utilize all
        _utilize(traderKey, 2000e6);

        // puppet1 funds MORE while position is open
        vm.warp(block.timestamp + 2 hours);
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList);

        // puppet1 now has more allocation (1000 + 500 = 1500)
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1500e6, "puppet1 increased alloc");

        // But their utilization is still only 1000 (from first fund)
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 util unchanged");

        // Settlement: 2000 -> 3000 (50% profit)
        _depositSettlement(3000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // puppet1 only earns on original 1000 utilization, not new 500
        // puppet1: 1000/2000 * 3000 = 1500
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1500e6, "puppet1 earns on original only");

        // Realize
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // After realize: original 1500 alloc - 1000 util + 1500 realized = 2000
        assertEq(allocation.allocationBalance(traderKey, puppet1), 2000e6, "puppet1 final alloc");
    }

    // ============ New Puppet Joining Mid-Flow Tests ============

    function test_newPuppetJoins_afterFirstSettle() public {
        // Scenario: puppet1 and trader do first cycle, puppet2 joins for second cycle

        // Round 1: puppet1 + trader
        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;

        // Fund round 1: total 2000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList1);
        _utilize(traderKey, 2000e6);

        // Settle round 1 with 20% profit: 2000 -> 2400
        _depositSettlement(2400e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Verify round 1 pending (50% each)
        assertEq(allocation.pendingSettlement(traderKey, trader), 1200e6, "trader pending r1");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1200e6, "puppet1 pending r1");

        // Realize both - funds go back to ALLOCATION (not Account)
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // Verify allocation after realize
        assertEq(allocation.allocationBalance(traderKey, trader), 1200e6, "trader alloc after r1");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1200e6, "puppet1 alloc after r1");

        // Now puppet2 joins for round 2
        _deposit(puppet2, 500e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours); // Pass throttle period

        // For round 2, existing allocation stays, fund() just adds puppet2
        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = puppet2;

        // Fund round 2: puppet2 adds 500 from Account
        // trader and puppet1 already have allocation from r1
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList2);

        // Verify allocation: trader=1200 (from r1), puppet1=1200 (from r1), puppet2=500 (new)
        assertEq(allocation.allocationBalance(traderKey, trader), 1200e6, "trader alloc r2");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1200e6, "puppet1 alloc r2");
        assertEq(allocation.allocationBalance(traderKey, puppet2), 500e6, "puppet2 alloc r2");

        // Utilize all 2900 (1200 + 1200 + 500)
        _utilize(traderKey, 2900e6);

        // Settle round 2 with break-even: 2900 -> 2900
        _depositSettlement(2900e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Distribution based on utilization shares (break-even, everyone gets back what they put in):
        assertEq(allocation.pendingSettlement(traderKey, trader), 1200e6, "trader pending r2");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1200e6, "puppet1 pending r2");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 pending r2");
    }

    function test_newPuppetJoins_midAllocation_beforeUtilize() public {
        // Scenario: First fund with puppet1, then fund again adding puppet2 before utilizing

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 2000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;

        // First fund: trader=500, puppet1=1000, total allocation=1500
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList1);

        assertEq(allocation.allocationBalance(traderKey, trader), 500e6, "trader alloc after fund1");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 alloc after fund1");
        assertEq(allocation.totalAllocation(traderKey), 1500e6, "total alloc after fund1");

        // puppet2 joins and funds before any utilization
        _deposit(puppet2, 500e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours);

        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = puppet2;

        // Second fund: trader=500, puppet2=500, adding to allocation pool
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList2);

        // Total allocation now: trader=1000, puppet1=1000, puppet2=500
        assertEq(allocation.allocationBalance(traderKey, trader), 1000e6, "trader alloc after fund2");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 alloc after fund2");
        assertEq(allocation.allocationBalance(traderKey, puppet2), 500e6, "puppet2 alloc after fund2");
        assertEq(allocation.totalAllocation(traderKey), 2500e6, "total alloc after fund2");

        // Now utilize all 2500
        _utilize(traderKey, 2500e6);

        // Verify utilization matches allocation
        assertEq(allocation.getUserUtilization(traderKey, trader), 1000e6, "trader util");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 util");
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 500e6, "puppet2 util");

        // Settle with break-even
        _depositSettlement(2500e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each gets back what they put in
        assertEq(allocation.pendingSettlement(traderKey, trader), 1000e6, "trader pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1000e6, "puppet1 pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 pending");
    }

    function test_partialUtilization_realizeBetweenPositions() public {
        // Scenario: Partial utilize, realize, then new puppet joins for second position

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;

        // Fund: trader=1000, puppet1=1000, total allocation=2000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList1);

        // Partial utilize: only 1000 of 2000 (50%)
        _utilize(traderKey, 1000e6);

        // Each utilized 500 (50% of their 1000 allocation)
        assertEq(allocation.getUserUtilization(traderKey, trader), 500e6, "trader util partial");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util partial");
        assertEq(allocation.getAvailableAllocation(traderKey, trader), 500e6, "trader alloc remaining");
        assertEq(allocation.getAvailableAllocation(traderKey, puppet1), 500e6, "puppet1 alloc remaining");

        // Settle first position: 1000 -> 1200 (20% profit)
        _depositSettlement(1200e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each pending: 500/1000 * 1200 = 600
        assertEq(allocation.pendingSettlement(traderKey, trader), 600e6, "trader pending pos1");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 600e6, "puppet1 pending pos1");

        // REALIZE before next position (proper pattern)
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // After realize: utilization converts to allocation
        // trader: 500 (remaining alloc) + 600 (realized) = 1100 allocation
        // puppet1: 500 (remaining alloc) + 600 (realized) = 1100 allocation
        assertEq(allocation.allocationBalance(traderKey, trader), 1100e6, "trader alloc after realize");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1100e6, "puppet1 alloc after realize");

        // Withdraw to Account balance for this test scenario
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 600e6);
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 600e6);

        // Balances after withdraw: trader/puppet1 each have 600 in Account
        assertEq(account.userBalanceMap(usdc, trader), 600e6, "trader balance after pos1");
        assertEq(account.userBalanceMap(usdc, puppet1), 600e6, "puppet1 balance after pos1");

        // Remaining allocation: trader=500, puppet1=500
        assertEq(allocation.allocationBalance(traderKey, trader), 500e6, "trader remaining alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 500e6, "puppet1 remaining alloc");

        // puppet2 joins
        _deposit(puppet2, 500e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours);

        // Utilize remaining allocation (trader=500, puppet1=500) + puppet2's new allocation
        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = puppet2;

        // Fund again: adds puppet2's 500
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList2);

        // Allocation: trader=500, puppet1=500, puppet2=500
        assertEq(allocation.allocationBalance(traderKey, puppet2), 500e6, "puppet2 alloc");
        assertEq(allocation.totalAllocation(traderKey), 1500e6, "total alloc for pos2");

        // Utilize all remaining 1500
        _utilize(traderKey, 1500e6);

        // Settle second position: 1500 -> 1500 (break-even)
        _depositSettlement(1500e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each gets back what they put in (break-even)
        assertEq(allocation.pendingSettlement(traderKey, trader), 500e6, "trader pending pos2");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 500e6, "puppet1 pending pos2");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 pending pos2");
    }

    function test_mixedFlow_allRealizeBetweenRounds() public {
        // Scenario: all participants realize between rounds - proper pattern

        _deposit(puppet1, 2000e6);
        _setRule(puppet1, trader, 5000); // 50%
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);

        // Round 1
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList1);
        _utilize(traderKey, 1500e6);

        // Settle with 100% profit: 1500 -> 3000
        _depositSettlement(3000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // pending: trader=1000, puppet1=2000
        assertEq(allocation.pendingSettlement(traderKey, trader), 1000e6, "trader pending r1");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 2000e6, "puppet1 pending r1");

        // BOTH realize and withdraw before round 2 (full exit from allocation)
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // After realize: trader alloc=1000, puppet1 alloc=2000
        assertEq(allocation.allocationBalance(traderKey, trader), 1000e6, "trader alloc after realize");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 2000e6, "puppet1 alloc after realize");

        // Withdraw all to Account balance
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 1000e6);
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 2000e6);

        // trader started with 1000, contributed 500, remaining 500, withdrawn 1000 = 1500
        assertEq(account.userBalanceMap(usdc, trader), 1500e6, "trader balance after withdraw");
        assertEq(account.userBalanceMap(usdc, puppet1), 3000e6, "puppet1 balance after withdraw"); // 1000 + 2000

        // New puppet2 joins
        _deposit(puppet2, 1000e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours);

        // For round 2, we need to simulate tokens moving from address(traderAccount) to AccountStore
        // In real flow, this would happen via a transfer mechanism after settle
        // Here we simulate by minting the withdrawn amounts to AccountStore
        usdc.mint(address(accountStore), 3000e6); // trader(1000) + puppet1(2000)
        vm.prank(owner);
        accountStore.syncTokenBalance(IERC20(address(usdc)));

        // Round 2: all three participate
        address[] memory puppetList2 = new address[](2);
        puppetList2[0] = puppet1;
        puppetList2[1] = puppet2;

        // trader has 1000e6, puppet1 has 3000e6 (50% = 1500), puppet2 has 1000e6
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList2);
        _utilize(traderKey, 3000e6);

        // Settle with break-even
        _depositSettlement(3000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Distribution based on r2 utilization:
        // trader: 500/3000 * 3000 = 500
        // puppet1: 1500/3000 * 3000 = 1500
        // puppet2: 1000/3000 * 3000 = 1000
        assertEq(allocation.pendingSettlement(traderKey, trader), 500e6, "trader pending r2");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1500e6, "puppet1 pending r2");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 1000e6, "puppet2 pending r2");
    }

    function test_withdrawAutoRealizes() public {
        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Utilize half
        _utilize(traderKey, 1000e6);

        // Settle with profit: 1000 -> 1500
        _depositSettlement(1500e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // trader has 500 utilized, pending 750 (50% of 1500)
        assertEq(allocation.getUserUtilization(traderKey, trader), 500e6, "trader util before withdraw");
        assertEq(allocation.pendingSettlement(traderKey, trader), 750e6, "trader pending before withdraw");

        // Withdraw auto-realizes first
        // After realize: allocation = 1000 - 500 + 750 = 1250
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 1000e6);

        // trader withdrew 1000 from their realized 1250
        assertEq(account.userBalanceMap(usdc, trader), 1000e6, "trader balance after withdraw");
        assertEq(allocation.allocationBalance(traderKey, trader), 250e6, "trader remaining allocation");
        assertEq(allocation.getUserUtilization(traderKey, trader), 0, "trader util cleared");
    }

    function test_withdrawWithoutUtilization() public {
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory emptyList = new address[](0);

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, emptyList);

        // No utilization - can withdraw directly
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 500e6);

        assertEq(account.userBalanceMap(usdc, trader), 500e6, "trader withdrew");
        assertEq(allocation.allocationBalance(traderKey, trader), 500e6, "trader remaining");
    }

    function test_withdrawDuringUtilization_autoRealizes() public {
        // Scenario: User wants to withdraw while having active utilization
        // The withdraw auto-realizes pending settlement first

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Partial utilize: 50%
        _utilize(traderKey, 1000e6);

        // Each has 500 utilized, 500 available
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util");
        assertEq(allocation.getAvailableAllocation(traderKey, puppet1), 500e6, "puppet1 available");

        // Settle with break-even
        _depositSettlement(1000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // puppet1 pending: 500 (their utilization back)
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 500e6, "puppet1 pending");

        // puppet1 withdraws 700 - this auto-realizes first
        // After realize: allocation = 1000 - 500 + 500 = 1000
        // After withdraw: allocation = 1000 - 700 = 300
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 700e6);

        assertEq(account.userBalanceMap(usdc, puppet1), 700e6, "puppet1 balance");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 300e6, "puppet1 remaining");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 0, "puppet1 util cleared");
    }

    function test_cannotWithdrawBeforeSettlement() public {
        // Scenario: User tries to withdraw while utilized but before settlement
        // This should revert - can't exit a position before it settles

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Partial utilize: 50%
        _utilize(traderKey, 1000e6);

        // Each has 500 utilized, 500 available (but NO settlement yet)
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 0, "puppet1 no pending yet");

        // puppet1 tries to withdraw - should revert because utilization not settled
        vm.prank(owner);
        vm.expectRevert();
        allocation.withdraw(account, usdc, traderKey, puppet1, 100e6);

        // After settlement, withdraw works
        _depositSettlement(1000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 500e6);
        assertEq(account.userBalanceMap(usdc, puppet1), 500e6, "puppet1 withdrew after settle");
    }

    function test_multipleUtilizations_withoutRealize() public {
        // Scenario: Multiple utilize() calls without realize() in between
        // This tests the multiplicative approach for correct accounting

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Fund: trader=1000, puppet1=1000, total=2000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // First utilize: 1000 of 2000 (50%)
        _utilize(traderKey, 1000e6);

        // Each utilized 500 (50% of their 1000)
        assertEq(allocation.getUserUtilization(traderKey, trader), 500e6, "trader util after first");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util after first");
        assertEq(allocation.totalAllocation(traderKey), 1000e6, "total alloc after first");

        // Second utilize: 500 of remaining 1000 (50% of remaining)
        _utilize(traderKey, 500e6);

        // With multiplicative: remaining was 0.5, now 0.5 * 500/1000 = 0.25
        // Utilization = 1000 * (1.0 - 0.25) = 750 for each
        assertEq(allocation.getUserUtilization(traderKey, trader), 750e6, "trader util after second");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 750e6, "puppet1 util after second");
        assertEq(allocation.totalAllocation(traderKey), 500e6, "total alloc after second");

        // Third utilize: 250 of remaining 500 (50% of remaining)
        _utilize(traderKey, 250e6);

        // remaining = 0.25 * 250/500 = 0.125
        // Utilization = 1000 * (1.0 - 0.125) = 875 for each
        assertEq(allocation.getUserUtilization(traderKey, trader), 875e6, "trader util after third");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 875e6, "puppet1 util after third");

        // Settle: 1750 total utilized -> 2625 (50% profit)
        _depositSettlement(2625e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each gets half of 2625 = 1312.5, rounded to 1312e6
        assertEq(allocation.pendingSettlement(traderKey, trader), 1312500000, "trader pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1312500000, "puppet1 pending");

        // Realize both
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // After realize: 125 (remaining alloc) - 875 (util) + 1312.5 (realized) = 562.5
        // Wait, allocationBalance is 1000, utilization was 875
        // So: 1000 - 875 + 1312.5 = 1437.5
        assertEq(allocation.allocationBalance(traderKey, trader), 1437500000, "trader final alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1437500000, "puppet1 final alloc");
    }

    function test_multipleUtilizations_newUserJoinsMidway() public {
        // Scenario: Multiple utilizations with a new user joining between them

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = puppet1;

        // Initial fund: trader=1000, puppet1=1000
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList1);

        // First utilize: 1000 of 2000 (50%)
        _utilize(traderKey, 1000e6);

        assertEq(allocation.getUserUtilization(traderKey, trader), 500e6, "trader util after first");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util after first");

        // puppet2 joins now
        _deposit(puppet2, 1000e6);
        _setRule(puppet2, trader, 10000);

        vm.warp(block.timestamp + 2 hours);

        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = puppet2;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList2);

        // puppet2 has allocation but ZERO utilization (joined after first utilize)
        assertEq(allocation.allocationBalance(traderKey, puppet2), 1000e6, "puppet2 has alloc");
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 0, "puppet2 ZERO util");

        // Total allocation now: 1000 (remaining from first) + 1000 (puppet2) = 2000
        assertEq(allocation.totalAllocation(traderKey), 2000e6, "total alloc after puppet2 joins");

        // Second utilize: 1000 of 2000
        _utilize(traderKey, 1000e6);

        // trader/puppet1: had 500 util, now get 50% of their remaining 500 = 250 more
        // But their snapshot is 1000 and checkpoint was at remaining=0.5
        // After second utilize: remaining = 0.5 * 1000/2000 = 0.25
        // utilization = 1000 * (1.0 - 0.25) = 750
        assertEq(allocation.getUserUtilization(traderKey, trader), 750e6, "trader util after second");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 750e6, "puppet1 util after second");

        // puppet2: checkpoint at remaining=0.5, now remaining=0.25
        // utilization = 1000 * (0.5 - 0.25) / 0.5 = 500
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 500e6, "puppet2 util after second");

        // Settle: 1500 total utilized (750+750) but wait, totalUtilization tracks this
        // totalUtilization = 1000 + 1000 = 2000
        assertEq(allocation.totalUtilization(traderKey), 2000e6, "total utilization");

        // Settle with break-even: 2000 -> 2000
        _depositSettlement(2000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Each gets back proportional to their utilization
        // trader: 750/2000 * 2000 = 750
        // puppet1: 750/2000 * 2000 = 750
        // puppet2: 500/2000 * 2000 = 500
        assertEq(allocation.pendingSettlement(traderKey, trader), 750e6, "trader pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 750e6, "puppet1 pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 pending");
    }

    // ============ Edge Case Tests ============

    function test_utilize100Percent_epochTransition() public {
        // Scenario: Utilize exactly 100% of allocation, triggering epoch advance on next fund
        // Simple case: new user funds after epoch advance (doesn't have old checkpoint)

        _deposit(trader, 2000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory emptyList = new address[](0);

        // Epoch 0: Fund and utilize 100%
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, emptyList);

        uint epochBefore = allocation.currentEpoch(traderKey);
        assertEq(epochBefore, 0, "starts at epoch 0");

        _utilize(traderKey, 1000e6);
        assertEq(allocation.totalAllocation(traderKey), 0, "all allocation utilized");
        assertEq(allocation.epochRemaining(traderKey, 0), 0, "epoch remaining is 0");

        // Settle and realize
        _depositSettlement(1000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        vm.prank(owner);
        allocation.realize(traderKey, trader);

        // Fund again - triggers epoch advance (epochRemaining[0] = 0)
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, emptyList);

        uint epochAfter = allocation.currentEpoch(traderKey);
        assertEq(epochAfter, 1, "epoch advanced to 1");

        // Trader's checkpoint is still epoch 0
        assertEq(allocation.userEpoch(traderKey, trader), 0, "trader checkpoint still epoch 0");
        assertEq(allocation.getUserUtilization(traderKey, trader), 1000e6, "trader shows old snapshot as util");

        // Allocation is correctly updated
        assertEq(allocation.allocationBalance(traderKey, trader), 1500e6, "trader alloc");

        // Realize now works - it detects user is in old epoch with no pending, just syncs epoch
        vm.prank(owner);
        allocation.realize(traderKey, trader);

        // Trader is now synced to epoch 1
        assertEq(allocation.userEpoch(traderKey, trader), 1, "trader now in epoch 1");
        assertEq(allocation.getUserUtilization(traderKey, trader), 0, "trader util cleared");

        // Utilize in new epoch
        _utilize(traderKey, 1500e6);
        assertEq(allocation.getUserUtilization(traderKey, trader), 1500e6, "trader util in new epoch");
    }

    function test_settleWithZeroAmount_totalLoss() public {
        // Scenario: Position loses everything - settle with 0

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // Total loss: settle with 0
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Everyone gets 0 back
        assertEq(allocation.pendingSettlement(traderKey, trader), 0, "trader gets nothing");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 0, "puppet1 gets nothing");

        // Realize - utilization clears but no funds returned
        vm.prank(owner);
        allocation.realize(traderKey, trader);
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // Allocation balance becomes 0 (had 1000, utilized 1000, got back 0)
        assertEq(allocation.allocationBalance(traderKey, trader), 0, "trader alloc is 0");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 0, "puppet1 alloc is 0");
    }

    function test_fundWithZeroTraderAmount_onlyPuppets() public {
        // Scenario: Trader contributes 0, only puppets fund

        _deposit(puppet1, 1000e6);
        _deposit(puppet2, 500e6);
        _setRule(puppet1, trader, 10000);
        _setRule(puppet2, trader, 10000);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Trader contributes 0
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList);

        assertEq(allocation.allocationBalance(traderKey, trader), 0, "trader has 0 alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 alloc");
        assertEq(allocation.allocationBalance(traderKey, puppet2), 500e6, "puppet2 alloc");
        assertEq(allocation.totalAllocation(traderKey), 1500e6, "total alloc");

        // Utilize and settle
        _utilize(traderKey, 1500e6);

        assertEq(allocation.getUserUtilization(traderKey, trader), 0, "trader 0 util");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 util");
        assertEq(allocation.getUserUtilization(traderKey, puppet2), 500e6, "puppet2 util");

        _depositSettlement(1500e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        assertEq(allocation.pendingSettlement(traderKey, trader), 0, "trader 0 pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1000e6, "puppet1 pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet2), 500e6, "puppet2 pending");
    }

    function test_userInOldEpoch_getsFullUtilization() public {
        // Scenario: User doesn't realize after 100% utilization + epoch advance
        // Their utilization should still be correctly calculated

        _deposit(puppet1, 2000e6); // Extra for second round
        _setRule(puppet1, trader, 5000); // 50%
        _deposit(trader, 2000e6); // Extra for second round

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Epoch 0: Fund and utilize 100%
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // Settle epoch 0
        _depositSettlement(2000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Only trader realizes
        vm.prank(owner);
        allocation.realize(traderKey, trader);

        // puppet1 does NOT realize - they're stuck in old epoch
        uint puppet1Epoch = allocation.userEpoch(traderKey, puppet1);
        assertEq(puppet1Epoch, 0, "puppet1 still in epoch 0");

        // Trigger new epoch by funding with remaining Account balances
        // trader has 1000 in Account, puppet1 has 1000 in Account
        vm.warp(block.timestamp + 2 hours);
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        uint currentEpoch = allocation.currentEpoch(traderKey);
        assertEq(currentEpoch, 1, "now in epoch 1");

        // puppet1's utilization should return full snapshot (they're in old epoch)
        // Since userEpoch < currentEpoch, getUserUtilization returns snapshot
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 1000e6, "puppet1 full util (old epoch)");

        // puppet1 can still realize their epoch 0 earnings
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);

        // After realize, they're synced to new epoch
        assertEq(allocation.userEpoch(traderKey, puppet1), 1, "puppet1 now in epoch 1");
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 0, "puppet1 util cleared");
    }

    function test_traderInPuppetList_protectedByBalanceCheck() public {
        // Edge case: Trader is also in the puppet list
        // System protects against double allocation via balance deduction order:
        // 1. Puppet contributions calculated from ORIGINAL balances
        // 2. Trader amount deducted first
        // 3. Puppet amounts deducted - but trader's balance is now reduced!
        // This causes insufficient balance when trying to deduct puppet contribution

        _deposit(trader, 1000e6);
        _setRule(trader, trader, 10000); // Trader subscribes to themselves (100%)

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = trader; // Trader in puppet list!

        // This should revert because:
        // - Puppet contribution calculated: 100% of 1000 = 1000
        // - Trader contribution: 1000
        // - Total would need: 2000, but only 1000 deposited
        // Actually the flow is: trader balance set first, then setBalanceList for puppets
        // which tries to set trader balance again (as puppet) causing issues
        vm.prank(owner);
        vm.expectRevert(); // BankStore__InsufficientBalance or similar
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
    }

    function test_duplicatePuppetsInList() public {
        // Edge case: Same puppet appears twice in the list
        // Could cause double deduction

        _deposit(puppet1, 2000e6);
        _setRule(puppet1, trader, 5000); // 50% = 1000 per occurrence
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet1; // Duplicate!

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // puppet1 appears twice, but second time they have less balance
        // First: 50% of 2000 = 1000, remaining = 1000
        // Second: would be 50% of 1000 = 500, but throttle blocks it
        // Actually throttle is set on first occurrence, so second is skipped
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 only funded once due to throttle");
    }

    function test_utilizeLargerThanAllocation_reverts() public {
        // Edge case: Try to utilize more than available allocation

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Try to utilize more than total allocation (2000)
        vm.prank(owner);
        vm.expectRevert(); // Should underflow or revert
        allocation.utilize(traderKey, 2001e6);
    }

    function test_withdrawExactAllocation() public {
        // Edge case: Withdraw exactly the full allocation

        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory emptyList = new address[](0);

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, emptyList);

        // Withdraw exact allocation
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, trader, 1000e6);

        assertEq(allocation.allocationBalance(traderKey, trader), 0, "trader alloc is 0");
        assertEq(account.userBalanceMap(usdc, trader), 1000e6, "trader got funds back");
    }

    function test_realizeWithNoPendingAndNoUtilization() public {
        // Edge case: Call realize when user has no utilization and no pending

        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory emptyList = new address[](0);

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, emptyList);

        // No utilization - realize should return 0 and not change state
        uint allocBefore = allocation.allocationBalance(traderKey, trader);

        vm.prank(owner);
        uint realized = allocation.realize(traderKey, trader);

        assertEq(realized, 0, "nothing to realize");
        assertEq(allocation.allocationBalance(traderKey, trader), allocBefore, "alloc unchanged");
    }

    // ============ DDoS / Griefing Prevention Tests ============

    function test_puppetCannotWithdrawDuringActivePosition() public {
        // Scenario: Puppet tries to withdraw during active utilization to grief trader

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Full utilization - position is open
        _utilize(traderKey, 2000e6);

        // Puppet tries to withdraw - should fail (no settlement yet)
        vm.prank(owner);
        vm.expectRevert();
        allocation.withdraw(account, usdc, traderKey, puppet1, 1);

        // Puppet has 0 available allocation during full utilization
        assertEq(allocation.getAvailableAllocation(traderKey, puppet1), 0, "no available during full util");
    }

    function test_puppetCanWithdrawAvailableDuringPartialUtilization() public {
        // Scenario: Partial utilization - puppet can withdraw non-utilized portion
        // This is allowed because the non-utilized funds aren't part of the position

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        // Partial utilization - 50%
        _utilize(traderKey, 1000e6);

        // Puppet has 500 utilized, 500 available
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 500e6, "puppet1 util");
        assertEq(allocation.getAvailableAllocation(traderKey, puppet1), 500e6, "puppet1 available");

        // Puppet cannot withdraw because they have utilization without settlement
        vm.prank(owner);
        vm.expectRevert();
        allocation.withdraw(account, usdc, traderKey, puppet1, 100e6);

        // After settlement, puppet can withdraw available portion
        _depositSettlement(1000e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Now withdraw works - auto-realizes first
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 500e6);

        assertEq(account.userBalanceMap(usdc, puppet1), 500e6, "puppet withdrew");
    }

    function test_puppetMassExitAfterLoss_traderUnaffected() public {
        // Scenario: All puppets exit after a losing position
        // This is legitimate behavior - trader's own allocation is unaffected

        _deposit(puppet1, 1000e6);
        _deposit(puppet2, 1000e6);
        _setRule(puppet1, trader, 10000);
        _setRule(puppet2, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);

        _utilize(traderKey, 3000e6);

        // 50% loss
        _depositSettlement(1500e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // All puppets realize and withdraw everything
        vm.prank(owner);
        allocation.realize(traderKey, puppet1);
        vm.prank(owner);
        allocation.realize(traderKey, puppet2);

        // puppet1: 1000 utilized, gets back 500
        // puppet2: 1000 utilized, gets back 500
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 500e6);
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet2, 500e6);

        // Before realize: trader's allocationBalance mapping still shows original amount
        // (balance is only updated on realize)
        assertEq(allocation.allocationBalance(traderKey, trader), 1000e6, "trader balance before realize");

        // Trader realizes to update their allocation with loss
        vm.prank(owner);
        allocation.realize(traderKey, trader);

        // After realize: trader also took 50% loss (fair proportional distribution)
        // newAllocation = 1000e6 (original) + 500e6 (settlement) - 1000e6 (utilization) = 500e6
        assertEq(allocation.allocationBalance(traderKey, trader), 500e6, "trader also lost 50%");

        // Key point: puppets withdrawing doesn't harm trader beyond the actual loss
        // The trader's loss is the same regardless of whether puppets withdraw or not
    }

    function test_throttlePreventsRapidReentry() public {
        // Scenario: Puppet tries to rapidly exit and re-enter to game the system

        _deposit(puppet1, 2000e6);
        _setRule(puppet1, trader, 5000); // 50%
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // First fund
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        // puppet1 contributed 1000 (50% of 2000), has 1000 remaining in Account
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 first alloc");

        // Try to fund again immediately - should be throttled
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        // puppet1's allocation should NOT increase (throttled)
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1000e6, "puppet1 throttled");

        // After throttle period, can fund again
        vm.warp(block.timestamp + 2 hours);
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 0, puppetList);

        // Now puppet1 contributed more
        assertEq(allocation.allocationBalance(traderKey, puppet1), 1500e6, "puppet1 funded after throttle");
    }

    function test_multipleSettlesBeforeRealize() public {
        // Edge case: Multiple settle() calls accumulate before realize

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000);
        _deposit(trader, 1000e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 1000e6, puppetList);
        _utilize(traderKey, 2000e6);

        // First settle: 2000 -> 2200
        _depositSettlement(2200e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Second settle: add another 200
        _depositSettlement(200e6);
        vm.prank(owner);
        allocation.settle(traderKey, usdc);

        // Total settled: 2400
        // Each should get 1200
        assertEq(allocation.pendingSettlement(traderKey, trader), 1200e6, "trader pending");
        assertEq(allocation.pendingSettlement(traderKey, puppet1), 1200e6, "puppet1 pending");

        // Realize gets all accumulated settlements
        vm.prank(owner);
        allocation.realize(traderKey, trader);

        // trader: 1000 (alloc) - 1000 (util) + 1200 (realized) = 1200
        assertEq(allocation.allocationBalance(traderKey, trader), 1200e6, "trader final alloc");
    }

    function test_puppetWithdrawBetweenFundAndUtilize_causesUnderflow() public {
        // VULNERABILITY: Puppet can withdraw after fund() but before utilize()
        // This causes utilize() to underflow because totalAllocation < utilize amount

        _deposit(puppet1, 1000e6);
        _setRule(puppet1, trader, 10000); // 100%
        _deposit(trader, 500e6);

        bytes32 traderKey = _getTraderMatchingKey(trader);
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Step 1: Fund the position
        vm.prank(owner);
        allocation.allocate(account, subscribe, usdc, trader, address(traderAccount), 500e6, puppetList);

        // totalAllocation = 1500 (trader: 500, puppet: 1000)
        assertEq(allocation.totalAllocation(traderKey), 1500e6, "total after fund");

        // Step 2: Puppet's utilization is 0 after fund (before utilize)
        // This is because epochRemaining hasn't decreased yet
        assertEq(allocation.getUserUtilization(traderKey, puppet1), 0, "puppet util is 0");

        // Step 3: Puppet front-runs utilize() by withdrawing
        vm.prank(owner);
        allocation.withdraw(account, usdc, traderKey, puppet1, 1000e6);

        // totalAllocation is now only 500
        assertEq(allocation.totalAllocation(traderKey), 500e6, "total after puppet withdraw");

        // Step 4: utilize() is called with original amount (1500) - THIS SHOULD FAIL
        // In real scenario, the funds were already sent to GMX, so we need to utilize 1500
        // Simulate funds leaving address(traderAccount) to GMX
        vm.prank(address(traderAccount));
        usdc.transfer(address(0xdead), 1500e6);

        // Now utilize should underflow: 500 - 1500
        vm.expectRevert();
        vm.prank(owner);
        allocation.utilize(traderKey, 1500e6);
    }
}
