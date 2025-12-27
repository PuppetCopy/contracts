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

        allocation = new Allocation(dictator, Allocation.Config({
            maxPuppetList: 100,
            transferOutGasLimit: 200_000,
            callGasLimit: 200_000,
            minFirstDepositShares: 1000 // Minimum 1000 shares for first deposit
        }));
        dictator.registerContract(address(allocation));

        masterAccount = new TestSmartAccount();
        masterAccount.installModule(MODULE_TYPE_VALIDATOR, address(this), "");
        masterAccount.installModule(MODULE_TYPE_HOOK, address(allocation), "");
        masterAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        dictator.setPermission(allocation, allocation.allocate.selector, owner);
        dictator.setPermission(allocation, allocation.utilize.selector, owner);
        dictator.setPermission(allocation, allocation.withdraw.selector, owner);
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

    function _allocate(address[] memory _puppetList, uint[] memory _amounts) internal {
        vm.prank(owner);
        allocation.allocate(usdc, address(masterAccount), _puppetList, _amounts);
    }

    function _utilize(address[] memory _puppetList, uint _amountToUtilize) internal {
        vm.prank(owner);
        allocation.utilize(usdc, address(masterAccount), _puppetList, _amountToUtilize);
    }

    function _deposit(address[] memory _puppetList, uint[] memory _amounts) internal {
        // Two-phase: allocate funds, then utilize all to mint shares
        _allocate(_puppetList, _amounts);
        uint totalAmount = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        _utilize(_puppetList, totalAmount);
    }

    function _withdraw(address _user, uint _amount) internal {
        bytes32 key = _getMatchingKey();
        vm.prank(owner);
        allocation.withdraw(usdc, key, _user, _amount);
    }

    function _openPosition(uint _amount) internal {
        // Approve venue to take funds
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(usdc), 0, abi.encodeCall(IERC20.approve, (address(mockVenue), _amount)))
        );

        // Set amount for venue to take
        mockVenue.setAmountToTake(_amount);

        // Execute venue call - triggers preCheck
        masterAccount.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(mockVenue), 0, abi.encodeCall(MockVenue.openPosition, ()))
        );
    }

    function _getPositionKey() internal view returns (bytes32) {
        return mockReader.parsePositionKey(address(masterAccount), "");
    }

    // ============ Basic Tests ============

    function test_deposit_mintsSharesAndTransfersFunds() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        _deposit(puppetList, amounts);

        // Shares minted at 1:1 for first deposit
        assertGt(allocation.userShares(matchingKey, address(puppetAccount)), 0, "Shares minted");
        assertEq(allocation.totalShares(matchingKey), allocation.userShares(matchingKey, address(puppetAccount)), "Total shares match");
        assertEq(usdc.balanceOf(address(masterAccount)), 500e6, "Funds transferred to master");
    }

    function test_sharePrice_initialIsOne() public {
        bytes32 matchingKey = _getMatchingKey();
        uint sharePrice = allocation.getSharePrice(matchingKey, usdc);
        assertEq(sharePrice, FLOAT_PRECISION, "Initial share price should be 1e30");
    }

    function test_sharePrice_increasesWithProfit() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint initialShares = allocation.totalShares(matchingKey);

        _openPosition(500e6);

        // Simulate position profit: NPV = 750e6 (50% profit)
        mockReader.setPositionValue(posKey, int256(750e6));

        uint newSharePrice = allocation.getSharePrice(matchingKey, usdc);
        uint expectedPrice = Precision.toFactor(750e6, initialShares);
        assertEq(newSharePrice, expectedPrice, "Share price should reflect NPV");
    }

    function test_sharePrice_decreasesWithLoss() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint initialShares = allocation.totalShares(matchingKey);

        _openPosition(500e6);

        // Simulate position loss: NPV = 250e6 (50% loss)
        mockReader.setPositionValue(posKey, int256(250e6));

        uint newSharePrice = allocation.getSharePrice(matchingKey, usdc);
        uint expectedPrice = Precision.toFactor(250e6, initialShares);
        assertEq(newSharePrice, expectedPrice, "Share price should reflect loss");
    }

    function test_sharePrice_zeroWhenPoolWorthless() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        _openPosition(500e6);

        // Position value is 0 (total loss)
        mockReader.setPositionValue(posKey, int256(0));

        uint sharePrice = allocation.getSharePrice(matchingKey, usdc);
        assertEq(sharePrice, 0, "Share price should be 0 when pool is worthless");
    }

    // ============ Fair Distribution Tests ============

    function test_fairDistribution_lateJoinerPaysMorePerShare() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // Alice deposits 1000 - gets shares at price 1e30
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _deposit(aliceList, aliceAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));

        _openPosition(1000e6);

        // Position doubles: NPV = 2000e6
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob deposits 1000 - gets shares at higher price (2e30)
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _deposit(bobList, bobAlloc);

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

        // Alice deposits - gets shares at initial price
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(aliceAccount);
        uint[] memory aliceAlloc = new uint[](1);
        aliceAlloc[0] = 1000e6;
        _deposit(aliceList, aliceAlloc);

        uint aliceShares = allocation.userShares(matchingKey, address(aliceAccount));
        uint totalSharesBeforeBob = allocation.totalShares(matchingKey);
        assertEq(aliceShares, totalSharesBeforeBob, "Alice owns 100%");

        _openPosition(1000e6);

        // Position profits 100%: NPV = 2000
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob deposits at higher share price
        address[] memory bobList = new address[](1);
        bobList[0] = address(bobAccount);
        uint[] memory bobAlloc = new uint[](1);
        bobAlloc[0] = 1000e6;
        _deposit(bobList, bobAlloc);

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

    function test_userValue_reflectsPoolValue() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 posKey = _getPositionKey();

        // Both deposit equal amounts
        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 500e6;
        bothAlloc[1] = 500e6;
        _deposit(bothList, bothAlloc);

        // User value should be 500 each (no profit/loss yet)
        uint aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(aliceAccount));
        uint bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bobAccount));
        assertApproxEqAbs(aliceValue, 500e6, 1, "Alice value = 500");
        assertApproxEqAbs(bobValue, 500e6, 1, "Bob value = 500");

        _openPosition(1000e6);

        // Position doubles: NPV = 2000e6
        mockReader.setPositionValue(posKey, int256(2000e6));

        // User values should double
        aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(aliceAccount));
        bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bobAccount));
        assertApproxEqAbs(aliceValue, 1000e6, 1, "Alice value = 1000 after profit");
        assertApproxEqAbs(bobValue, 1000e6, 1, "Bob value = 1000 after profit");
    }

    function test_userValue_proportionalToShares() public {
        TestSmartAccount aliceAccount = _createPuppetAccount(puppet1);
        TestSmartAccount bobAccount = _createPuppetAccount(puppet2);
        usdc.mint(address(aliceAccount), 2000e6);
        usdc.mint(address(bobAccount), 2000e6);

        bytes32 posKey = _getPositionKey();

        // Alice 2x Bob's deposit
        address[] memory bothList = new address[](2);
        bothList[0] = address(aliceAccount);
        bothList[1] = address(bobAccount);
        uint[] memory bothAlloc = new uint[](2);
        bothAlloc[0] = 600e6;
        bothAlloc[1] = 300e6;
        _deposit(bothList, bothAlloc);

        _openPosition(900e6);

        // Position gains 100%
        mockReader.setPositionValue(posKey, int256(1800e6));

        uint aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(aliceAccount));
        uint bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bobAccount));

        assertApproxEqRel(aliceValue, bobValue * 2, 0.01e18, "Alice 2x value");
        assertApproxEqAbs(aliceValue, 1200e6, 1e6, "Alice ~1200");
        assertApproxEqAbs(bobValue, 600e6, 1e6, "Bob ~600");
    }

    // ============ Withdraw Tests ============

    function test_withdraw_returnsValueAtSharePrice() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        // Withdraw full amount (500e6)
        _withdraw(address(puppetAccount), 500e6);

        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "All shares burned");
        assertEq(usdc.balanceOf(address(puppetAccount)), 1000e6, "Got funds back");
    }

    function test_withdraw_partialAmount() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint sharesBefore = allocation.userShares(matchingKey, address(puppetAccount));

        // Withdraw half amount (250e6)
        _withdraw(address(puppetAccount), 250e6);

        uint sharesAfter = allocation.userShares(matchingKey, address(puppetAccount));
        assertApproxEqRel(sharesAfter, sharesBefore / 2, 0.01e18, "Half shares remain");
        assertApproxEqAbs(usdc.balanceOf(address(puppetAccount)), 750e6, 1, "Got 250 back (500 + 250)");
    }

    function test_withdraw_withProfit() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        _openPosition(500e6);

        // Position doubles: 500 -> 1000 (simulating close with 100% profit)
        // When position closes, venue sends back 1000 (original + profit)
        usdc.mint(address(masterAccount), 1000e6); // Full return from position
        mockReader.setPositionValue(posKey, int256(0)); // Position closed

        // Withdraw full value (1000e6 after profit)
        _withdraw(address(puppetAccount), 1000e6);

        // Puppet started with 1000, deposited 500 (left with 500), now gets 1000 back = 1500 total
        assertEq(usdc.balanceOf(address(puppetAccount)), 1500e6, "Got original 500 + 500 profit");
        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "All shares burned");
    }

    function test_withdraw_withLoss() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        _openPosition(500e6);

        // Position loses 50% (simulating close with loss)
        usdc.mint(address(masterAccount), 250e6); // Only 250 comes back
        mockReader.setPositionValue(posKey, int256(0)); // Position closed

        // Withdraw all available (250e6 after loss)
        _withdraw(address(puppetAccount), 250e6);

        assertEq(usdc.balanceOf(address(puppetAccount)), 750e6, "Got original 500 - 250 loss");
        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "All shares burned");
    }

    function test_withdraw_revertsIfInsufficientLiquidity() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        _openPosition(500e6);

        // Position is open with value
        mockReader.setPositionValue(posKey, int256(500e6));

        // Cannot withdraw - funds locked in position
        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InsufficientBalance.selector, 0, 500e6));
        _withdraw(address(puppetAccount), 500e6);
    }

    function test_withdraw_revertsIfInsufficientBalance() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        // Try to withdraw more than available (500e6 + 1)
        // First 500e6 will try to come from shares, but 501e6 exceeds
        vm.expectRevert();
        _withdraw(address(puppetAccount), 501e6);
    }

    // ============ Multi-User Scenarios ============

    function test_multiUser_fairProfitDistribution() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        TestSmartAccount charlie = _createPuppetAccount(puppet3);
        usdc.mint(address(alice), 10000e6);
        usdc.mint(address(bob), 10000e6);
        usdc.mint(address(charlie), 10000e6);

        bytes32 key = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // All deposit: Alice 1000, Bob 1000, Charlie 2000 (4000 total)
        address[] memory allList = new address[](3);
        allList[0] = address(alice);
        allList[1] = address(bob);
        allList[2] = address(charlie);
        uint[] memory allocs = new uint[](3);
        allocs[0] = 1000e6;
        allocs[1] = 1000e6;
        allocs[2] = 2000e6;
        _deposit(allList, allocs);

        _openPosition(4000e6);

        // Position gains 100%: 4000 -> 8000 value
        // When position closes, 8000 comes back (original + profit)
        usdc.mint(address(masterAccount), 8000e6);
        mockReader.setPositionValue(posKey, int256(0)); // Closed

        // Check user values proportional to deposits
        uint aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(alice));
        uint bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bob));
        uint charlieValue = allocation.getUserValue(usdc, address(masterAccount), address(charlie));

        assertApproxEqAbs(aliceValue, 2000e6, 1, "Alice gets 2000 (100% profit on 1000)");
        assertApproxEqAbs(bobValue, 2000e6, 1, "Bob gets 2000 (100% profit on 1000)");
        assertApproxEqAbs(charlieValue, 4000e6, 1, "Charlie gets 4000 (100% profit on 2000)");

        // All withdraw their values
        _withdraw(address(alice), aliceValue);
        _withdraw(address(bob), bobValue);
        _withdraw(address(charlie), charlieValue);

        assertEq(allocation.totalShares(key), 0, "All shares burned");
    }

    function test_multiUser_fairLossDistribution() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 5000e6);
        usdc.mint(address(bob), 5000e6);

        bytes32 key = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // Both deposit 1000
        address[] memory bothList = new address[](2);
        bothList[0] = address(alice);
        bothList[1] = address(bob);
        uint[] memory allocs = new uint[](2);
        allocs[0] = 1000e6;
        allocs[1] = 1000e6;
        _deposit(bothList, allocs);

        _openPosition(2000e6);

        // Position loses 50%: only 1000 comes back
        usdc.mint(address(masterAccount), 1000e6);
        mockReader.setPositionValue(posKey, int256(0));

        uint aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(alice));
        uint bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bob));

        assertEq(aliceValue, bobValue, "Equal loss sharing");
        assertApproxEqAbs(aliceValue + bobValue, 1000e6, 2, "Total = 1000");
    }

    function test_lateJoiner_doesNotDiluteEarlyProfits() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 5000e6);
        usdc.mint(address(bob), 5000e6);

        bytes32 key = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        // Alice deposits first
        address[] memory aliceList = new address[](1);
        aliceList[0] = address(alice);
        uint[] memory alloc = new uint[](1);
        alloc[0] = 1000e6;
        _deposit(aliceList, alloc);

        uint aliceSharesBefore = allocation.userShares(key, address(alice));

        _openPosition(1000e6);

        // Position doubles before Bob joins (NPV = 2000)
        mockReader.setPositionValue(posKey, int256(2000e6));

        // Bob deposits at higher share price (price is now 2x)
        // Bob's 1000 USDC goes to master's balance (now balance = 1000, position = 2000)
        address[] memory bobList = new address[](1);
        bobList[0] = address(bob);
        alloc[0] = 1000e6;
        _deposit(bobList, alloc);

        uint bobShares = allocation.userShares(key, address(bob));

        // Bob has half the shares (paid 2x the price)
        assertApproxEqRel(bobShares, aliceSharesBefore / 2, 0.01e18, "Bob has half shares");

        // Position closes: Alice's 2000 NPV returns to balance
        // Total pool = 1000 (Bob's deposit) + 2000 (position return) = 3000
        usdc.mint(address(masterAccount), 2000e6); // Position return (the 2000 NPV)
        mockReader.setPositionValue(posKey, int256(0));

        uint aliceValue = allocation.getUserValue(usdc, address(masterAccount), address(alice));
        uint bobValue = allocation.getUserValue(usdc, address(masterAccount), address(bob));

        // Alice owns 2/3 of shares (1000 shares vs Bob's 500 shares)
        // Pool = 3000, Alice = 2/3 * 3000 = 2000, Bob = 1/3 * 3000 = 1000
        assertApproxEqRel(aliceValue, 2000e6, 0.02e18, "Alice gets ~2000");
        assertApproxEqRel(bobValue, 1000e6, 0.02e18, "Bob gets ~1000");
    }

    // ============ Two-Phase Allocation Tests ============

    function test_allocate_stagesFundsWithoutShares() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        _allocate(puppetList, amounts);

        // Funds transferred but no shares minted yet
        assertEq(usdc.balanceOf(address(masterAccount)), 500e6, "Funds in master");
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 500e6, "Allocation tracked");
        assertEq(allocation.totalAllocation(matchingKey), 500e6, "Total allocation tracked");
        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "No shares yet");
        assertEq(allocation.totalShares(matchingKey), 0, "No total shares yet");
    }

    function test_utilize_convertsAllocationsToShares() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        _allocate(puppetList, amounts);
        _utilize(puppetList, 500e6);

        // Allocations converted to shares
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation cleared");
        assertEq(allocation.totalAllocation(matchingKey), 0, "Total allocation cleared");
        assertGt(allocation.userShares(matchingKey, address(puppetAccount)), 0, "Shares minted");
        assertEq(allocation.totalShares(matchingKey), allocation.userShares(matchingKey, address(puppetAccount)), "Total shares match");
    }

    function test_partialUtilize_returnsUnused() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        uint balanceBefore = usdc.balanceOf(address(puppetAccount));
        _allocate(puppetList, amounts);

        // Only utilize 50% (250e6)
        _utilize(puppetList, 250e6);

        // Half returned to puppet
        assertEq(usdc.balanceOf(address(puppetAccount)), balanceBefore - 250e6, "Half returned");
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation cleared");
        assertEq(allocation.totalAllocation(matchingKey), 0, "Total allocation cleared");
    }

    function test_partialUtilize_proportionalDistribution() public {
        TestSmartAccount alice = _createPuppetAccount(puppet1);
        TestSmartAccount bob = _createPuppetAccount(puppet2);
        usdc.mint(address(alice), 1000e6);
        usdc.mint(address(bob), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        // Alice allocates 600, Bob allocates 400 (total = 1000)
        address[] memory bothList = new address[](2);
        bothList[0] = address(alice);
        bothList[1] = address(bob);
        uint[] memory amounts = new uint[](2);
        amounts[0] = 600e6;
        amounts[1] = 400e6;

        uint aliceBalBefore = usdc.balanceOf(address(alice));
        uint bobBalBefore = usdc.balanceOf(address(bob));

        _allocate(bothList, amounts);

        // Only utilize 500 (50% of total)
        _utilize(bothList, 500e6);

        // Alice: 600 * 0.5 = 300 utilized, 300 returned
        // Bob: 400 * 0.5 = 200 utilized, 200 returned
        assertEq(usdc.balanceOf(address(alice)), aliceBalBefore - 300e6, "Alice: 300 utilized, 300 back");
        assertEq(usdc.balanceOf(address(bob)), bobBalBefore - 200e6, "Bob: 200 utilized, 200 back");

        uint aliceShares = allocation.userShares(matchingKey, address(alice));
        uint bobShares = allocation.userShares(matchingKey, address(bob));
        assertApproxEqRel(aliceShares, bobShares * 3 / 2, 0.01e18, "Alice has 1.5x Bob's shares");
    }

    function test_withdraw_fromIdleAllocation() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        uint balanceBefore = usdc.balanceOf(address(puppetAccount));
        _allocate(puppetList, amounts);

        assertEq(usdc.balanceOf(address(puppetAccount)), balanceBefore - 500e6, "Funds allocated");

        // Withdraw uses idle allocation first (no shares burned)
        _withdraw(address(puppetAccount), 500e6);

        assertEq(usdc.balanceOf(address(puppetAccount)), balanceBefore, "Funds returned");
        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation cleared");
        assertEq(allocation.totalAllocation(matchingKey), 0, "Total allocation cleared");
        assertEq(allocation.userShares(matchingKey, address(puppetAccount)), 0, "No shares burned (none existed)");
    }

    function test_withdraw_fromBothAllocationAndShares() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 2000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);

        // First deposit: 500e6 utilized (has shares)
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint sharesBefore = allocation.userShares(matchingKey, address(puppetAccount));
        assertGt(sharesBefore, 0, "Should have shares");

        // Second: allocate 300e6 but don't utilize (idle allocation)
        amounts[0] = 300e6;
        _allocate(puppetList, amounts);

        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 300e6, "Has idle allocation");

        // Withdraw 500e6 - should take 300 from allocation + 200 from shares
        _withdraw(address(puppetAccount), 500e6);

        assertEq(allocation.allocationBalance(matchingKey, address(puppetAccount)), 0, "Allocation fully used");
        uint sharesAfter = allocation.userShares(matchingKey, address(puppetAccount));
        // 200e6 worth of shares burned (at 1:1 price)
        assertApproxEqRel(sharesAfter, sharesBefore * 3 / 5, 0.01e18, "~60% shares remain (300/500)");
    }

    function test_idleAllocations_dontAffectPoolValue() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        // First, create utilized shares
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint utilizationValueAfterDeposit = allocation.getUtilizationValue(matchingKey, usdc);
        assertEq(utilizationValueAfterDeposit, 500e6, "Utilization value = 500");

        // Allocate more but don't utilize
        usdc.mint(address(puppetAccount), 500e6);
        amounts[0] = 500e6;
        _allocate(puppetList, amounts);

        // Utilization value should NOT include idle allocations
        uint utilizationValueAfterAlloc = allocation.getUtilizationValue(matchingKey, usdc);
        assertEq(utilizationValueAfterAlloc, 500e6, "Utilization value unchanged by idle allocation");

        // Utilized balance excludes idle
        uint utilizedBalance = allocation.getUtilizedBalance(matchingKey, usdc);
        assertEq(utilizedBalance, 500e6, "Utilized balance excludes idle");
    }

    // ============ Edge Cases ============

    function test_zeroAllocate_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 0;

        vm.prank(owner);
        vm.expectRevert(Error.Allocation__ZeroAllocation.selector);
        allocation.allocate(usdc, address(masterAccount), puppetList, amounts);
    }

    function test_maxPuppetList_reverts() public {
        uint maxPuppets = allocation.getConfig().maxPuppetList;
        address[] memory puppetList = new address[](maxPuppets + 1);
        uint[] memory amounts = new uint[](maxPuppets + 1);

        for (uint i = 0; i <= maxPuppets; i++) {
            puppetList[i] = address(uint160(i + 1000));
            amounts[i] = 1e6;
        }

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, maxPuppets + 1, maxPuppets));
        vm.prank(owner);
        allocation.allocate(usdc, address(masterAccount), puppetList, amounts);
    }

    function test_uninstall_activeShares_reverts() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint shares = allocation.totalShares(matchingKey);
        assertGt(shares, 0, "Should have active shares");

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ActiveShares.selector, shares));
        masterAccount.uninstallModule(2, address(allocation), "");
    }

    function test_uninstall_afterFullWithdraw_succeeds() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        // Withdraw full amount
        _withdraw(address(puppetAccount), 500e6);

        assertEq(allocation.totalShares(matchingKey), 0, "No shares remaining");

        // Should succeed now
        masterAccount.uninstallModule(2, address(allocation), "");
    }

    function test_utilizationValue_includesBalance() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        uint utilizationValue = allocation.getUtilizationValue(matchingKey, usdc);
        assertEq(utilizationValue, 500e6, "Utilization value = balance");
    }

    function test_utilizationValue_includesPositionValue() public {
        TestSmartAccount puppetAccount = _createPuppetAccount(puppet1);
        usdc.mint(address(puppetAccount), 1000e6);

        bytes32 matchingKey = _getMatchingKey();
        bytes32 posKey = _getPositionKey();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppetAccount);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;
        _deposit(puppetList, amounts);

        _openPosition(500e6);

        // Set position NPV
        mockReader.setPositionValue(posKey, int256(600e6));

        uint utilizationValue = allocation.getUtilizationValue(matchingKey, usdc);
        assertEq(utilizationValue, 600e6, "Utilization value = 0 balance + 600 position NPV");
    }
}
