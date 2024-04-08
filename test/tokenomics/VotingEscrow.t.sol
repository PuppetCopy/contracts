// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {VotingEscrow} from "src/tokenomics/VotingEscrow.sol";
import {Dictator} from "src/utils/Dictator.sol";
import {Router} from "src/utils/Router.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract VotingEscrowTests is BasicSetup {
    uint private constant MAXTIME = 2 * 365 * 86400; // 4 years

    VotingEscrow votingEscrow;

    function setUp() public override {
        BasicSetup.setUp();

        dictator.setUserRole(users.owner, MINT_PUPPET_ROLE, true);

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);

        puppetToken.mint(users.alice, 100 * 1e18);
        puppetToken.mint(users.bob, 100 * 1e18);
        puppetToken.mint(users.yossi, 100 * 1e18);

        dictator.setRoleCapability(0, address(router), router.transfer.selector, true);
        dictator.setUserRole(address(votingEscrow), 0, true);

        dictator.setPublicCapability(address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setPublicCapability(address(votingEscrow), votingEscrow.depositFor.selector, true);
        dictator.setPublicCapability(address(votingEscrow), votingEscrow.withdraw.selector, true);

        vm.stopPrank();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testParamsOnDeployment() public {
        // sanity view functions tests
        assertEq(votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E5");
        assertEq(votingEscrow.userPointHistoryTs(users.alice, 0), 0, "testParamsOnDeployment: E6");
        assertEq(votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E7");
        assertEq(votingEscrow.balanceOf(users.alice), 0, "testParamsOnDeployment: E8");
        assertEq(votingEscrow.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E9");
        assertEq(votingEscrow.balanceOfAt(users.alice, block.number), 0, "testParamsOnDeployment: E10");
        assertEq(votingEscrow.totalSupply(), 0, "testParamsOnDeployment: E11");
        assertEq(votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E12");

        votingEscrow.checkpoint();

        assertEq(votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E13");
        assertEq(votingEscrow.userPointHistoryTs(users.alice, 0), 0, "testParamsOnDeployment: E14");
        assertEq(votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E15");
        assertEq(votingEscrow.balanceOf(users.alice), 0, "testParamsOnDeployment: E16");
        assertEq(votingEscrow.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E17");
        assertEq(votingEscrow.balanceOfAt(users.alice, block.number), 0, "testParamsOnDeployment: E18");
        assertEq(votingEscrow.totalSupply(), 0, "testParamsOnDeployment: E19");
        assertEq(votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E20");
    }

    function testMutated() public {
        uint _aliceAmountLocked = puppetToken.balanceOf(users.alice) / 3;
        uint _bobAmountLocked = puppetToken.balanceOf(users.bob) / 3;
        uint _totalSupplyBefore;
        uint _votingEscrowBalanceBefore;
        uint _lockedAmountBefore;

        // --- CREATE LOCK ---

        // alice
        _checkCreateLockWrongFlows(users.alice);
        vm.startPrank(users.alice);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.alice);
        puppetToken.approve(address(router), _aliceAmountLocked);
        votingEscrow.lock(users.alice, users.alice, _aliceAmountLocked, block.timestamp + MAXTIME);
        _totalSupplyBefore = votingEscrow.totalSupply();

        vm.stopPrank();
        _checkUserVotingDataAfterCreateLock(users.alice, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // bob
        _checkCreateLockWrongFlows(users.bob);
        vm.startPrank(users.bob);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.bob);
        puppetToken.approve(address(router), _bobAmountLocked);
        votingEscrow.lock(users.bob, users.bob, _bobAmountLocked, block.timestamp + MAXTIME);
        // vm.expectRevert(VotingEscrow.VotingEscrow__InvaidLockingSchedule.selector);
        // votingEscrow.lock(users.bob, users.bob, _bobAmountLocked, block.timestamp + 8 * 86400);
        vm.stopPrank();
        _checkUserVotingDataAfterCreateLock(users.bob, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // --- DEPOSIT FOR ---
        // alice
        _checkDepositForWrongFlows(_aliceAmountLocked, users.alice, users.bob);
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), _bobAmountLocked);
        vm.stopPrank();
        vm.startPrank(users.alice);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.bob);
        uint _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
        uint _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
        votingEscrow.depositFor(users.alice, users.bob, _aliceAmountLocked);

        vm.stopPrank();
        _checkUserBalancesAfterDepositFor(
            users.alice,
            users.bob,
            _aliceBalanceBefore,
            _bobBalanceBefore,
            _aliceAmountLocked,
            _totalSupplyBefore,
            _votingEscrowBalanceBefore,
            _lockedAmountBefore
        );

        // bob
        _checkDepositForWrongFlows(_bobAmountLocked, users.bob, users.alice);
        vm.startPrank(users.bob);
        puppetToken.approve(address(router), _aliceAmountLocked);
        vm.stopPrank();
        vm.startPrank(users.bob);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.alice);
        _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
        _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
        votingEscrow.depositFor(users.bob, users.alice, _bobAmountLocked);

        vm.stopPrank();
        _checkUserBalancesAfterDepositFor(
            users.bob,
            users.alice,
            _bobBalanceBefore,
            _aliceBalanceBefore,
            _bobAmountLocked,
            _totalSupplyBefore,
            _votingEscrowBalanceBefore,
            _lockedAmountBefore
        );

        // --- INCREASE UNLOCK TIME ---

        _checkLockTimesBeforeSkip();
        _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
        _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
        _totalSupplyBefore = votingEscrow.totalSupply();

        skip(MAXTIME / 2); // skip half of the lock time
        _checkLockTimesAfterSkipHalf(_aliceBalanceBefore, _bobBalanceBefore, _totalSupplyBefore);

        _checkIncreaseUnlockTimeWrongFlows();
        vm.startPrank(users.alice);
        uint _aliceBalanceBeforeUnlock = votingEscrow.balanceOf(users.alice);
        uint _totalSupplyBeforeUnlock = votingEscrow.totalSupply();
        votingEscrow.lock(users.alice, users.alice, 0, block.timestamp + MAXTIME);
        vm.stopPrank();

        vm.startPrank(users.bob);
        uint _bobBalanceBeforeUnlock = votingEscrow.balanceOf(users.bob);
        votingEscrow.lock(users.bob, users.bob, 0, block.timestamp + MAXTIME);
        vm.stopPrank();

        _checkUserLockTimesAfterIncreaseUnlockTime(
            _aliceBalanceBeforeUnlock, _aliceBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.alice
        );
        _checkUserLockTimesAfterIncreaseUnlockTime(
            _bobBalanceBeforeUnlock, _bobBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.bob
        );

        // --- INCREASE AMOUNT ---

        _checkIncreaseAmountWrongFlows(users.alice);
        vm.startPrank(users.alice);
        _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.alice);
        puppetToken.approve(address(router), _aliceAmountLocked);
        votingEscrow.lock(users.alice, users.alice, _aliceAmountLocked, 0);
        vm.stopPrank();
        _checkUserBalancesAfterIncreaseAmount(
            users.alice, _aliceBalanceBefore, _totalSupplyBefore, _aliceAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore
        );

        _checkIncreaseAmountWrongFlows(users.bob);
        vm.startPrank(users.bob);
        _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
        _totalSupplyBefore = votingEscrow.totalSupply();
        _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
        _lockedAmountBefore = votingEscrow.lockedAmount(users.bob);
        puppetToken.approve(address(router), _bobAmountLocked);
        votingEscrow.lock(users.bob, users.bob, _bobAmountLocked, 0);
        vm.stopPrank();
        _checkUserBalancesAfterIncreaseAmount(
            users.bob, _bobBalanceBefore, _totalSupplyBefore, _bobAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore
        );

        // --- WITHDRAW ---

        _checkWithdrawWrongFlows(users.alice);

        _totalSupplyBefore = votingEscrow.totalSupply();

        skip(MAXTIME + 1); // entire lock time

        vm.startPrank(users.alice);
        _aliceBalanceBefore = puppetToken.balanceOf(users.alice);
        votingEscrow.withdraw(users.alice, users.alice);
        (uint amount, uint end) = votingEscrow.locked(users.alice);
        assertEq(amount, 0);
        assertEq(end, 0);
        vm.stopPrank();
        _checkUserBalancesAfterWithdraw(users.alice, _totalSupplyBefore, _aliceBalanceBefore);

        vm.startPrank(users.bob);
        _bobBalanceBefore = puppetToken.balanceOf(users.bob);
        votingEscrow.withdraw(users.bob, users.bob);
        vm.stopPrank();
        _checkUserBalancesAfterWithdraw(users.bob, _totalSupplyBefore, _bobBalanceBefore);
        assertEq(puppetToken.balanceOf(address(votingEscrow)), 0, "testMutated: E0");
    }

    // =======================================================
    // Internal functions
    // =======================================================

    function _checkCreateLockWrongFlows(address _user) internal {
        uint _puppetBalance = puppetToken.balanceOf(_user);
        uint _maxTime = MAXTIME;
        require(_puppetBalance > 0, "no PUPPET balance");

        vm.startPrank(_user);

        vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
        votingEscrow.lock(_user, _user, _puppetBalance, block.timestamp + _maxTime);

        puppetToken.approve(address(router), _puppetBalance);

        vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
        votingEscrow.lock(_user, _user, 0, 0);

        vm.warp(2);
        vm.expectRevert(VotingEscrow.VotingEscrow__InvaidLockingSchedule.selector);
        votingEscrow.lock(_user, _user, _puppetBalance, 3);

        puppetToken.approve(address(router), 0);

        vm.stopPrank();
    }

    function _checkUserVotingDataAfterCreateLock(
        address _user,
        uint _amountLocked,
        uint _totalSupplyBefore,
        uint _votingEscrowBalanceBefore,
        uint _lockedAmountBefore
    ) internal {
        vm.startPrank(_user);

        uint _puppetBalance = puppetToken.balanceOf(_user);
        // uint256 _maxTime = MAXTIME;
        puppetToken.approve(address(router), _puppetBalance);
        // vm.expectRevert(bytes4(keccak256("WithdrawOldTokensFirst()")));
        // votingEscrow.lock(_user, _puppetBalance, block.timestamp + _maxTime);
        puppetToken.approve(address(router), 0);

        assertTrue(votingEscrow.getLastUserSlope(_user) != 0, "_checkUserVotingDataAfterCreateLock: E0");
        assertTrue(votingEscrow.userPointHistoryTs(_user, 1) != 0, "_checkUserVotingDataAfterCreateLock: E1");
        assertAlmostEq(votingEscrow.lockedEnd(_user), block.timestamp + MAXTIME, 1e10, "_checkUserVotingDataAfterCreateLock: E2");
        assertAlmostEq(votingEscrow.balanceOf(_user), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E3");
        assertAlmostEq(votingEscrow.balanceOf(_user, block.timestamp), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E4");
        assertAlmostEq(votingEscrow.balanceOfAt(_user, block.number), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E5");

        assertAlmostEq(votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E6");
        assertAlmostEq(votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E7");
        assertEq(_votingEscrowBalanceBefore, puppetToken.balanceOf(address(votingEscrow)) - _amountLocked, "_checkUserVotingDataAfterCreateLock: E8");
        assertTrue(puppetToken.balanceOf(address(votingEscrow)) > 0, "_checkUserVotingDataAfterCreateLock: E9");
        assertEq(_votingEscrowBalanceBefore + _amountLocked, puppetToken.balanceOf(address(votingEscrow)), "_checkUserVotingDataAfterCreateLock: E10");
        assertEq(votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserVotingDataAfterCreateLock: E11");
    }

    function _checkDepositForWrongFlows(uint _amount, address _user, address _receiver) internal {
        vm.startPrank(_user);

        vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
        votingEscrow.depositFor(_user, _receiver, 0);

        vm.expectRevert(VotingEscrow.VotingEscrow__NoLockFound.selector);
        votingEscrow.depositFor(_user, users.yossi, _amount);

        vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
        votingEscrow.depositFor(_user, _receiver, _amount);

        vm.stopPrank();
    }

    function _checkUserBalancesAfterDepositFor(
        address _user,
        address _receiver,
        uint _userBalanceBefore,
        uint _receiverBalanceBefore,
        uint _amount,
        uint _totalSupplyBefore,
        uint _votingEscrowBalanceBefore,
        uint _lockedAmountBefore
    ) internal {
        assertEq(votingEscrow.balanceOf(_user), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E0");
        assertAlmostEq(votingEscrow.balanceOf(_receiver), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E1");
        assertEq(votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E2");
        assertAlmostEq(
            votingEscrow.balanceOf(_receiver, block.timestamp), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E3"
        );
        assertEq(votingEscrow.balanceOfAt(_user, block.number), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E4");
        assertAlmostEq(
            votingEscrow.balanceOfAt(_receiver, block.number), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E5"
        );
        assertAlmostEq(votingEscrow.totalSupply(), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E6");
        assertAlmostEq(votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E7");
        assertEq(puppetToken.balanceOf(address(votingEscrow)), _votingEscrowBalanceBefore + _amount, "_checkUserBalancesAfterDepositFor: E8");
        assertEq(votingEscrow.lockedAmount(_receiver), _lockedAmountBefore + _amount, "_checkUserBalancesAfterDepositFor: E9");
    }

    function _checkLockTimesBeforeSkip() internal {
        assertAlmostEq(votingEscrow.lockedEnd(users.alice), block.timestamp + MAXTIME, 1e6, "_checkLockTimesBeforeSkip: E0");
        assertAlmostEq(votingEscrow.lockedEnd(users.bob), block.timestamp + MAXTIME, 1e6, "_checkLockTimesBeforeSkip: E1");
    }

    function _checkLockTimesAfterSkipHalf(uint _aliceBalanceBefore, uint _bobBalanceBefore, uint _totalSupplyBefore) internal {
        assertAlmostEq(votingEscrow.balanceOf(users.alice), _aliceBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E0");
        assertAlmostEq(votingEscrow.balanceOf(users.bob), _bobBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E1");
        assertEq(votingEscrow.balanceOf(users.alice, block.timestamp - MAXTIME / 2), _aliceBalanceBefore, "_checkLockTimesAfterSkipHalf: E2");
        assertEq(votingEscrow.balanceOf(users.bob, block.timestamp - MAXTIME / 2), _bobBalanceBefore, "_checkLockTimesAfterSkipHalf: E3");
        assertAlmostEq(votingEscrow.totalSupply(), _totalSupplyBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E4");
        assertEq(votingEscrow.totalSupply(block.timestamp - MAXTIME / 2), _totalSupplyBefore, "_checkLockTimesAfterSkipHalf: E5");
    }

    function _checkIncreaseUnlockTimeWrongFlows() internal {
        uint _maxTime = MAXTIME;
        // uint256 _userLockEnd = _votingEscrow.lockedEnd(_user);

        vm.startPrank(users.yossi);
        vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
        votingEscrow.lock(users.yossi, users.yossi, 0, block.timestamp + _maxTime);
        vm.stopPrank();

        // vm.startPrank(_user);
        // // vm.expectRevert(bytes4(keccak256("LockTimeInThePast()")));
        // _votingEscrow.increaseUnlockTime(_userLockEnd);
        // vm.stopPrank();
    }

    function _checkUserLockTimesAfterIncreaseUnlockTime(
        uint _userBalanceBeforeUnlock,
        uint _userBalanceBefore,
        uint _totalSupplyBeforeUnlock,
        uint _totalSupplyBefore,
        address _user
    ) internal {
        assertAlmostEq(votingEscrow.lockedEnd(_user), block.timestamp + MAXTIME, 1e6, "_checkUserLockTimesAfterIncreaseUnlockTime: E0");
        assertAlmostEq(votingEscrow.balanceOf(_user), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E1");
        assertAlmostEq(
            votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E2"
        );

        // assertEq(_votingEscrow.balanceOfAtT(_user, block.timestamp - _MAXTIME / 2),
        // _votingEscrow.balanceOf(_user), "_checkUserLockTimesAfterIncreaseUnlockTime: E3");
        assertTrue(votingEscrow.totalSupply() > _totalSupplyBeforeUnlock, "_checkUserLockTimesAfterIncreaseUnlockTime: E4");
        assertAlmostEq(votingEscrow.totalSupply(), _totalSupplyBefore, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E5");
        assertAlmostEq(_userBalanceBefore, votingEscrow.balanceOf(_user), 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E6");
    }

    function _checkIncreaseAmountWrongFlows(address _user) internal {
        vm.startPrank(_user);
        vm.expectRevert();
        votingEscrow.lock(_user, _user, 0, 0);
        vm.stopPrank();
    }

    function _checkUserBalancesAfterIncreaseAmount(
        address _user,
        uint _balanceBefore,
        uint _totalSupplyBefore,
        uint _amountLocked,
        uint _votingEscrowBalanceBefore,
        uint _lockedAmountBefore
    ) internal {
        assertAlmostEq(votingEscrow.balanceOf(_user), _balanceBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E0");
        assertAlmostEq(votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E1");
        assertEq(
            puppetToken.balanceOf(address(votingEscrow)), _votingEscrowBalanceBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E2"
        );
        assertEq(votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E3");
    }

    function _checkWithdrawWrongFlows(address _user) internal {
        vm.startPrank(_user);
        vm.expectRevert(); // reverts with ```The lock didn't expire```
        votingEscrow.withdraw(_user, _user);
        vm.stopPrank();
    }

    function _checkUserBalancesAfterWithdraw(address _user, uint _totalSupplyBefore, uint _puppetBalanceBefore) internal {
        assertEq(votingEscrow.balanceOf(_user), 0, "_checkUserBalancesAfterWithdraw: E0");
        assertTrue(votingEscrow.totalSupply() < _totalSupplyBefore, "_checkUserBalancesAfterWithdraw: E1");
        assertTrue(puppetToken.balanceOf(_user) > _puppetBalanceBefore, "_checkUserBalancesAfterWithdraw: E2");
    }
}
