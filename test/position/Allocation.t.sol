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
        dictator.setPermission(allocation, allocation.withdraw.selector, owner);
        dictator.setPermission(allocation, allocation.setVenueReader.selector, owner);
        dictator.setPermission(allocation, allocation.distributeShares.selector, owner);

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

    function _openPosition(uint _amount) internal {
        // Approve venue to take funds
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.approve, (address(mockVenue), _amount)))
        );

        // Set amount for venue to take
        mockVenue.setAmountToTake(_amount);

        // Execute venue call - triggers preCheck (position tracking) and postCheck (utilization detection)
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

    function test_allocate_basic() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(puppetList, allocations);

        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6);
        assertEq(allocation.totalAllocation(matchingKey), 500e6);
        assertEq(usdc.balanceOf(address(masterAccount)), 500e6);
    }

    function test_withdraw_noShares() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;

        _allocate(puppetList, allocations);

        vm.prank(owner);
        allocation.withdraw(usdc, matchingKey, address(puppetAccount), 200e6);

        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 300e6);
        assertEq(usdc.balanceOf(address(puppetAccount)), 700e6);
    }

    // ============ Share-Based Distribution Tests ============

    function test_sharePrice_initialIsOne() public {
        bytes32 matchingKey = _getMatchingKey();
        uint sharePrice = allocation.getSharePrice(matchingKey);
        assertEq(sharePrice, FLOAT_PRECISION, "Initial share price should be 1e30");
    }

    function test_distributeShares_firstDistribution() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);

        // Open position - funds leave subaccount, pendingUtilization increases
        _openPosition(500e6);

        assertEq(allocation.pendingUtilization(matchingKey), 500e6, "Pending utilization should be 500");

        // Distribute shares at initial price (1e30)
        vm.prank(owner);
        allocation.distributeShares(matchingKey, puppetList);

        uint userShares = allocation.userShares(matchingKey, address(puppetAccount));
        assertGt(userShares, 0, "User should have shares");
        assertEq(allocation.totalShares(matchingKey), userShares, "Total shares should match");
        assertEq(allocation.pendingUtilization(matchingKey), 0, "Pending should be cleared");
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

        _openPosition(500e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, puppetList);

        uint initialShares = allocation.totalShares(matchingKey);

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

        // Alice allocates 1000
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _allocate(aliceList, aliceAlloc);

        _openPosition(1000e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, aliceList);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));

        // Position doubles: NPV = 2000e6
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob allocates 1000
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _allocate(bobList, bobAlloc);

        _openPosition(1000e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, bobList);

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

        // Alice joins
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _allocate(aliceList, aliceAlloc);

        _openPosition(1000e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, aliceList);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint totalSharesBeforeBob = allocation.totalShares(matchingKey);
        assertEq(aliceShares, totalSharesBeforeBob, "Alice owns 100%");

        // Position profits 100%: NPV = 2000
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob joins with same nominal amount
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _allocate(bobList, bobAlloc);

        _openPosition(1000e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, bobList);

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

        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 500e6;
        bothAlloc[1] = 500e6;
        _allocate(bothList, bothAlloc);

        _openPosition(1000e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, bothList);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));
        assertEq(aliceShares, bobShares, "Equal allocation = equal shares");

        // Settlement: 200e6 returns
        _closePosition(200e6);

        uint alicePending = allocation.pendingSettlement(matchingKey, address(aliceAccount));
        uint bobPending = allocation.pendingSettlement(matchingKey, address(bobAccount));

        assertEq(alicePending, bobPending, "Equal shares = equal settlement");
        assertApproxEqAbs(alicePending + bobPending, 200e6, 2, "Total ~200");
    }

    function test_settlement_proportionalToShares() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 600e6;
        bothAlloc[1] = 300e6;
        _allocate(bothList, bothAlloc);

        _openPosition(900e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, bothList);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint bobShares = allocation.userShares(matchingKey, address(bobAccount));
        assertApproxEqRel(aliceShares, bobShares * 2, 0.01e18, "Alice 2x Bob's shares");

        // Settlement of 300e6
        _closePosition(300e6);

        uint alicePending = allocation.pendingSettlement(matchingKey, address(aliceAccount));
        uint bobPending = allocation.pendingSettlement(matchingKey, address(bobAccount));

        assertApproxEqRel(alicePending, bobPending * 2, 0.01e18, "Alice 2x settlement");
        assertApproxEqAbs(alicePending, 200e6, 1e6, "Alice ~200");
        assertApproxEqAbs(bobPending, 100e6, 1e6, "Bob ~100");
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

    function test_uninstall_noActiveShares_succeeds() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory allocations = new uint[](1);
        allocations[0] = 500e6;
        _allocate(puppetList, allocations);

        assertTrue(_isModuleInstalled(masterAccount));
        masterAccount.uninstallModule(2, address(allocation), "");
        assertFalse(_isModuleInstalled(masterAccount));
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

        _openPosition(500e6);

        vm.prank(owner);
        allocation.distributeShares(matchingKey, puppetList);

        uint shares = allocation.totalShares(matchingKey);
        assertGt(shares, 0, "Should have active shares");

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveShares.selector, shares));
        masterAccount.uninstallModule(2, address(allocation), "");
    }
}
