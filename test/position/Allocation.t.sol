// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {Precision} from "src/utils/Precision.sol";
import {MockERC20} from "test/mock/MockERC20.t.sol";
import {MockNpvReader, MockVenue, PassthroughReader} from "test/mock/MockNpvReader.t.sol";
import {TestSmartAccount} from "test/mock/TestSmartAccount.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {INpvReader} from "src/position/interface/INpvReader.sol";
import {Access} from "src/utils/auth/Access.sol";
import {Permission} from "src/utils/auth/Permission.sol";
import {Error} from "src/utils/Error.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";
import {ModeLib} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

contract AllocationTest is Test {
    Dictatorship dictator;
    Allocation allocation;
    TestSmartAccount masterAccount;
    MockERC20 usdc;
    MockNpvReader mockReader;
    MockVenue mockVenue;
    PassthroughReader passthroughReader;

    address owner;
    address puppet1;
    address puppet2;
    address puppet3;

    uint constant FLOAT_PRECISION = 1e30;

    function setUp() public {
        owner = makeAddr("owner");
        puppet1 = makeAddr("puppet1");
        puppet2 = makeAddr("puppet2");
        puppet3 = makeAddr("puppet3");

        vm.startPrank(owner);

        usdc = new MockERC20("USDC", "USDC", 6);
        dictator = new Dictatorship(owner);
        mockReader = new MockNpvReader();
        mockVenue = new MockVenue();
        passthroughReader = new PassthroughReader();

        allocation = new Allocation(dictator, Allocation.Config({maxPuppetList: 100, transferOutGasLimit: 200_000, callGasLimit: 200_000}));
        dictator.registerContract(address(allocation));

        masterAccount = new TestSmartAccount();
        masterAccount.installModule(MODULE_TYPE_VALIDATOR, address(this), "");
        masterAccount.installModule(MODULE_TYPE_HOOK, address(allocation), "");
        masterAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        dictator.setPermission(allocation, allocation.allocate.selector, owner);
        dictator.setPermission(allocation, allocation.utilize.selector, owner);
        dictator.setPermission(allocation, allocation.withdraw.selector, owner);
        dictator.setPermission(allocation, allocation.withdrawAllocation.selector, owner);
        dictator.setPermission(allocation, allocation.setVenueReader.selector, owner);

        // Setup mock venue
        mockVenue.setToken(usdc);
        allocation.setVenueReader(address(mockVenue), mockReader);
        // Whitelist USDC with passthrough (allows approve calls without position tracking)
        allocation.setVenueReader(address(usdc), passthroughReader);

        vm.stopPrank();
    }

    function _createPuppetAccount(address) internal returns (TestSmartAccount) {
        TestSmartAccount puppetAccount = new TestSmartAccount();
        puppetAccount.installModule(MODULE_TYPE_VALIDATOR, address(masterAccount), "");
        puppetAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        return puppetAccount;
    }

    function _getMatchingKey() internal view returns (bytes32) {
        return PositionUtils.getMatchingKey(usdc, address(masterAccount));
    }

    function _isModuleInstalled(TestSmartAccount _account) internal view returns (bool) {
        return _account.isModuleInstalled(2, address(allocation), "")
            && _account.isModuleInstalled(4, address(allocation), "");
    }

    function _allocate(address[] memory _puppetList, uint[] memory _puppetAllocations) internal {
        vm.prank(owner);
        allocation.allocate(usdc, address(masterAccount), _puppetList, _puppetAllocations);
    }

    function _utilize(address[] memory _puppetList, uint[] memory _utilizationList) internal {
        vm.prank(owner);
        allocation.utilize(usdc, address(masterAccount), _puppetList, _utilizationList);
    }

    function _openPosition(uint _amount) internal {
        // Approve venue to take funds
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.approve, (address(mockVenue), _amount)))
        );

        // Set amount for venue to take
        mockVenue.setAmountToTake(_amount);

        // Execute venue call - triggers preCheck and postCheck
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(mockVenue), 0, abi.encodeCall(MockVenue.openPosition, ()))
        );
    }

    function _closePosition(uint _amount) internal {
        // Transfer funds back from venue to master
        mockVenue.closePosition(address(masterAccount), _amount);

        // Trigger settle via a no-op venue call
        mockVenue.setAmountToTake(0);
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(mockVenue), 0, abi.encodeCall(MockVenue.openPosition, ()))
        );
    }

    function _getPositionKey() internal view returns (bytes32) {
        return mockReader.parsePositionKey(address(masterAccount), "");
    }

    // ============ Basic Tests ============

    function test_allocate_tracksIdleFunds() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(puppetList, allocations);

        // Allocation tracked but no shares yet
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "Allocation tracked");
        assertEq(allocation.totalAllocation(matchingKey), 500e6, "Total allocation tracked");
        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "No shares until utilize");
        assertEq(usdc.balanceOf(address(masterAccount)), 500e6, "Funds transferred to master");
    }

    function test_utilize_convertsToShares() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        // After utilize, shares exist and allocation is zero
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation consumed");
        assertGt(allocation.userShares(matchingKey, address(puppetAccount)), 0, "Shares minted");
        assertEq(allocation.totalAllocation(matchingKey), 0, "Total allocation consumed");
    }

    function test_withdrawAllocation_idleFunds() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(puppetList, allocations);

        // Withdraw idle allocation
        vm.prank(owner);
        allocation.withdrawAllocation(usdc, matchingKey, address(puppetAccount), 500e6);

        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation withdrawn");
        assertEq(usdc.balanceOf(address(puppetAccount)), 1000e6, "Funds returned");
    }

    // ============ Share-Based Distribution Tests ============

    function test_sharePrice_initialIsOne() public {
        bytes32 matchingKey = _getMatchingKey();
        uint sharePrice = allocation.getSharePrice(matchingKey);
        assertEq(sharePrice, FLOAT_PRECISION, "Initial share price should be 1e30");
    }

    function test_sharePrice_increasesWithNPV() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        uint initialShares = allocation.totalShares(matchingKey);

        _openPosition(500e6);

        // Simulate position profit: NPV = 750e6 (50% profit)
        mockReader.setPositionValue(posKey, int256(750e6));

        uint newSharePrice = allocation.getSharePrice(matchingKey);
        uint expectedPrice = Precision.toFactor(750e6, initialShares);
        assertEq(newSharePrice, expectedPrice, "Share price should reflect NPV");
    }

    function test_fairDistribution_lateJoinerPaysMorePerShare() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // Alice allocates and utilizes 1000 - gets shares at price 1e30
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _allocate(aliceList, aliceAlloc);
        _utilize(aliceList, aliceAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));

        _openPosition(1000e6);

        // Position doubles: NPV = 2000e6
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob allocates and utilizes 1000 - gets shares at higher price (2e30)
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _allocate(bobList, bobAlloc);
        _utilize(bobList, bobAlloc);

        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));

        // Bob should have FEWER shares for same $ (price doubled)
        assertLt(bobShares, aliceShares, "Late joiner should get fewer shares");
        assertApproxEqRel(bobShares, aliceShares / 2, 0.01e18, "Bob ~50% of Alice's shares");
    }

    function test_fairDistribution_earlyParticipantNotDiluted() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // Alice allocates and utilizes - gets shares at initial price
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _allocate(aliceList, aliceAlloc);
        _utilize(aliceList, aliceAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint totalSharesBeforeBob = allocation.totalShares(matchingKey);
        assertEq(aliceShares, totalSharesBeforeBob, "Alice owns 100%");

        _openPosition(1000e6);

        // Position profits 100%: NPV = 2000
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob allocates and utilizes at higher share price
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _allocate(bobList, bobAlloc);
        _utilize(bobList, bobAlloc);

        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));
        uint totalSharesAfterBob = allocation.totalShares(matchingKey);

        // Alice's share ownership after Bob joins
        uint aliceOwnership = (aliceShares * 1e18) / totalSharesAfterBob;
        uint bobOwnership = (bobShares * 1e18) / totalSharesAfterBob;

        // Alice: 2000 value / 3000 total = 66.7%
        // Bob: 1000 value / 3000 total = 33.3%
        assertApproxEqRel(aliceOwnership, 0.667e18, 0.01e18, "Alice ~66.7%");
        assertApproxEqRel(bobOwnership, 0.333e18, 0.01e18, "Bob ~33.3%");
    }

    function test_settlement_distributedPerShare() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();

        // Both allocate and utilize equal amounts - get equal shares
        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 500e6;
        bothAlloc[1] = 500e6;
        _allocate(bothList, bothAlloc);
        _utilize(bothList, bothAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));
        assertEq(aliceShares, bobShares, "Equal allocation = equal shares");

        _openPosition(1000e6);

        // Settlement: 200e6 returns
        _closePosition(200e6);

        uint alicePending = allocation.pendingReturn(matchingKey, address(aliceAccount));
        uint bobPending = allocation.pendingReturn(matchingKey, address(bobAccount));

        assertEq(alicePending, bobPending, "Equal shares = equal settlement");
        assertApproxEqAbs(alicePending + bobPending, 200e6, 2, "Total ~200");
    }

    function test_settlement_proportionalToShares() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();

        // Alice 2x Bob's allocation - gets 2x shares
        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 600e6;
        bothAlloc[1] = 300e6;
        _allocate(bothList, bothAlloc);
        _utilize(bothList, bothAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));
        assertApproxEqRel(aliceShares, bobShares * 2, 0.01e18, "Alice 2x Bob's shares");

        _openPosition(900e6);

        // Settlement of 300e6
        _closePosition(300e6);

        uint alicePending = allocation.pendingReturn(matchingKey, address(aliceAccount));
        uint bobPending = allocation.pendingReturn(matchingKey, address(bobAccount));

        assertApproxEqRel(alicePending, bobPending * 2, 0.01e18, "Alice 2x settlement");
        assertApproxEqAbs(alicePending, 200e6, 1e6, "Alice ~200");
        assertApproxEqAbs(bobPending, 100e6, 1e6, "Bob ~100");
    }

    // ============ Withdraw Tests ============

    function test_withdraw_claimsPendingReturns() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        _openPosition(500e6);

        usdc.mint(address(mockVenue), 100e6);
        _closePosition(600e6);

        uint pendingBefore = allocation.pendingReturn(matchingKey, address(puppetAccount));
        assertEq(pendingBefore, 600e6, "Should have 600 pending");

        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 300e6);

        assertEq(usdc.balanceOf(address(puppetAccount)), 800e6, "Puppet received 300 (500 initial + 300 withdrawn)");
    }

    function test_withdraw_burnsSharesProportionally() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        uint sharesBefore = allocation.userShares(matchingKey, address(puppetAccount));

        _openPosition(500e6);
        _closePosition(500e6);

        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 250e6);

        uint sharesAfter = allocation.userShares(matchingKey, address(puppetAccount));
        assertApproxEqRel(sharesAfter, sharesBefore / 2, 0.01e18, "Half shares burned");
    }

    function test_withdraw_partialThenFull() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        _openPosition(500e6);
        _closePosition(500e6);

        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 250e6);

        uint pendingAfterPartial = allocation.pendingReturn(matchingKey, address(puppetAccount));
        assertApproxEqAbs(pendingAfterPartial, 250e6, 1, "Should have 250 remaining");

        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 250e6);

        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "All shares burned");
        assertEq(usdc.balanceOf(address(puppetAccount)), 1000e6, "Got all funds back");
    }

    function test_allocate_preservesPendingReturns() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        _openPosition(500e6);
        _closePosition(500e6);

        uint pendingBefore = allocation.pendingReturn(matchingKey, address(puppetAccount));
        assertEq(pendingBefore, 500e6, "Should have 500 pending");

        allocations[0] = 500e6;
        _allocate(puppetList, allocations);

        uint pendingAfter = allocation.pendingReturn(matchingKey, address(puppetAccount));
        assertApproxEqAbs(pendingAfter, 500e6, 1e6, "Pending should be preserved");
    }

    function test_withdraw_requiresSettledReturns() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        _openPosition(500e6);

        uint shares = allocation.userShares(matchingKey, address(puppetAccount));
        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__SharesNotSettled.selector, shares));
        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 100e6);
    }

    function test_multiRound_continuousMixing() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        TestSmartAccount charlie = _createPuppetAccount(puppet3);
        usdc.mint(address(alice), 10000e6);
        usdc.mint(address(bob), 10000e6);
        usdc.mint(address(charlie), 10000e6);

        bytes32 key = _getMatchingKey();

        address[] memory allList = new address[](3);
        allList[0] = address(alice);
        allList[1] = address(bob);
        allList[2] = address(charlie);
        uint[] memory allocs = new uint[](3);
        allocs[0] = 1000e6;
        allocs[1] = 1000e6;
        allocs[2] = 2000e6;
        _allocate(allList, allocs);
        _utilize(allList, allocs);

        uint aliceShares = allocation.userShares(key, address(alice));
        assertGt(aliceShares, 0, "Alice has shares");

        uint bal = usdc.balanceOf(address(masterAccount));
        _openPosition(bal);
        _closePosition(bal);

        uint alicePending = allocation.pendingReturn(key, address(alice));
        uint bobPending = allocation.pendingReturn(key, address(bob));
        uint charliePending = allocation.pendingReturn(key, address(charlie));

        assertApproxEqAbs(alicePending, 1000e6, 1, "Alice gets 1000");
        assertApproxEqAbs(bobPending, 1000e6, 1, "Bob gets 1000");
        assertApproxEqAbs(charliePending, 2000e6, 1, "Charlie gets 2000");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(alice), alicePending);
        vm.prank(owner);
        allocation.withdraw(usdc, key, address(bob), bobPending);
        vm.prank(owner);
        allocation.withdraw(usdc, key, address(charlie), charliePending);

        assertEq(allocation.totalShares(key), 0, "All shares burned");
    }

    function test_interleavedAllocateWithdraw() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 5000e6);
        usdc.mint(address(bob), 5000e6);

        bytes32 key = _getMatchingKey();

        address[] memory aliceList = new address[](1);
        aliceList[0] = address(alice);
        uint[] memory alloc = new uint[](1);
        alloc[0] = 1000e6;
        _allocate(aliceList, alloc);
        _utilize(aliceList, alloc);

        _openPosition(1000e6);
        _closePosition(1000e6);

        uint alicePendingR1 = allocation.pendingReturn(key, address(alice));
        assertEq(alicePendingR1, 1000e6, "Alice pending after R1");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(alice), 400e6);

        address[] memory bobList = new address[](1);
        bobList[0] = address(bob);
        alloc[0] = 1000e6;
        _allocate(bobList, alloc);
        _utilize(bobList, alloc);

        uint bal = usdc.balanceOf(address(masterAccount));
        _openPosition(bal);
        _closePosition(bal);

        uint alicePending = allocation.pendingReturn(key, address(alice));
        uint bobPending = allocation.pendingReturn(key, address(bob));
        assertGt(alicePending, 0, "Alice has pending");
        assertGt(bobPending, 0, "Bob has pending");

        uint subaccountBal = usdc.balanceOf(address(masterAccount));
        assertApproxEqAbs(alicePending + bobPending, subaccountBal, 2, "Total pending = balance");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(bob), bobPending);
        assertEq(allocation.userShares(key, address(bob)), 0, "Bob fully exited");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(alice), alicePending);
        assertEq(allocation.userShares(key, address(alice)), 0, "Alice fully exited");
    }

    function test_fairness_profitDistribution() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 5000e6);
        usdc.mint(address(bob), 5000e6);

        bytes32 key = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory aliceList = new address[](1);
        aliceList[0] = address(alice);
        uint[] memory alloc = new uint[](1);
        alloc[0] = 1000e6;
        _allocate(aliceList, alloc);
        _utilize(aliceList, alloc);

        uint aliceSharesBefore = allocation.userShares(key, address(alice));

        _openPosition(1000e6);
        mockReader.setPositionValue(posKey, int256(2000e6));

        address[] memory bobList = new address[](1);
        bobList[0] = address(bob);
        alloc[0] = 1000e6;
        _allocate(bobList, alloc);
        _utilize(bobList, alloc);

        uint bobShares = allocation.userShares(key, address(bob));

        assertApproxEqRel(bobShares, aliceSharesBefore / 2, 0.01e18, "Bob has half shares");

        usdc.mint(address(mockVenue), 2000e6);
        _closePosition(3000e6);
        mockReader.setPositionValue(posKey, int256(0));

        uint alicePending = allocation.pendingReturn(key, address(alice));
        uint bobPending = allocation.pendingReturn(key, address(bob));

        assertApproxEqRel(alicePending, 2000e6, 0.02e18, "Alice gets ~2000");
        assertApproxEqRel(bobPending, 1000e6, 0.02e18, "Bob gets ~1000");
    }

    function test_fairness_lossDistribution() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 5000e6);
        usdc.mint(address(bob), 5000e6);

        bytes32 key = _getMatchingKey();

        address[] memory bothList = new address[](2);
        bothList[0] = address(alice);
        bothList[1] = address(bob);
        uint[] memory allocs = new uint[](2);
        allocs[0] = 1000e6;
        allocs[1] = 1000e6;
        _allocate(bothList, allocs);
        _utilize(bothList, allocs);

        _openPosition(2000e6);

        _closePosition(1000e6);

        uint alicePending = allocation.pendingReturn(key, address(alice));
        uint bobPending = allocation.pendingReturn(key, address(bob));

        assertEq(alicePending, bobPending, "Equal loss sharing");
        assertApproxEqAbs(alicePending + bobPending, 1000e6, 2, "Total = 1000");
    }

    function test_multipleSettlementRounds() public {
        TestSmartAccount puppet = _createPuppetAccount(puppet1);
        usdc.mint(address(puppet), 5000e6);

        bytes32 key = _getMatchingKey();

        address[] memory list = new address[](1);
        list[0] = address(puppet);
        uint[] memory alloc = new uint[](1);
        alloc[0] = 1000e6;
        _allocate(list, alloc);
        _utilize(list, alloc);

        _openPosition(1000e6);
        _closePosition(1000e6);
        assertEq(allocation.pendingReturn(key, address(puppet)), 1000e6, "Round 1");

        uint bal = usdc.balanceOf(address(masterAccount));
        _openPosition(bal);
        usdc.mint(address(mockVenue), bal / 5);
        _closePosition(bal + bal / 5);

        uint pendingAfterRound2 = allocation.pendingReturn(key, address(puppet));
        assertEq(pendingAfterRound2, 1200e6, "20% profit: 1200 pending");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(puppet), 600e6);

        uint pendingAfterWithdraw = allocation.pendingReturn(key, address(puppet));
        assertApproxEqAbs(pendingAfterWithdraw, 600e6, 1, "Half withdrawn");

        bal = usdc.balanceOf(address(masterAccount));
        _openPosition(bal);
        _closePosition(bal);

        uint finalPending = allocation.pendingReturn(key, address(puppet));
        uint subaccountBal = usdc.balanceOf(address(masterAccount));
        assertEq(finalPending, subaccountBal, "Pending = balance");

        vm.prank(owner);
        allocation.withdraw(usdc, key, address(puppet), finalPending);
        assertEq(allocation.userShares(key, address(puppet)), 0, "Fully exited");
    }

    // ============ Edge Cases ============

    function test_zeroAllocation_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 0;

        vm.expectRevert();
        vm.prank(owner);
        allocation.allocate(usdc, address(masterAccount), puppetList, allocations);
    }

    function test_maxPuppetList_reverts() public {
        uint maxPuppets = allocation.getConfig().maxPuppetList;
        address[] memory puppetList = new address[](maxPuppets + 1);
        uint[] memory allocations = new uint[](maxPuppets + 1);

        for (uint i = 0; i <= maxPuppets; i++) {
            puppetList[i] = address(uint160(i + 1000));
            allocations[i] = 1e6;
        }

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, maxPuppets + 1, maxPuppets));
        vm.prank(owner);
        allocation.allocate(usdc, address(masterAccount), puppetList, allocations);
    }

    function test_uninstall_activeAllocation_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);

        uint alloc = allocation.totalAllocation(matchingKey);
        assertGt(alloc, 0, "Should have active allocation");

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveShares.selector, alloc));
        masterAccount.uninstallModule(2, address(allocation), "");
    }

    function test_uninstall_activeShares_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);
        _utilize(puppetList, allocations);

        uint shares = allocation.totalShares(matchingKey);
        assertGt(shares, 0, "Should have active shares");

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveShares.selector, shares));
        masterAccount.uninstallModule(2, address(allocation), "");
    }
}
