// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.24;

// import {VotingEscrow} from "src/token/VotingEscrow.sol";
// import {Router} from "src/shared/Router.sol";

// import {BasicSetup} from "test/base/BasicSetup.t.sol";

// contract VotingEscrowTest is BasicSetup {
//     uint private constant MAXTIME = 2 * 365 * 86400; // 4 years

//     VotingEscrow votingEscrow;
//     VotingEscrowLocker votingEscrowLocker;

//     function setUp() public override {
//         BasicSetup.setUp();

//         votingEscrow = new VotingEscrow(dictator, router, puppetToken);
//         votingEscrowLocker = new VotingEscrowLocker(votingEscrow);

//         dictator.setPermission(puppetToken, users.owner, puppetToken.mint.selector);

//         puppetToken.mint(users.alice, 100 * 1e18);
//         puppetToken.mint(users.bob, 100 * 1e18);
//         puppetToken.mint(users.yossi, 100 * 1e18);

//         dictator.setPermission(router, address(votingEscrow), router.transfer.selector);
//         dictator.setPermission(router, users.owner, router.setTransferGasLimit.selector);

//         dictator.setAccess(votingEscrow, address(votingEscrowLocker));

//         vm.stopPrank();
//     }

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testMutated() public {
//         uint _aliceAmountLocked = puppetToken.balanceOf(users.alice) / 3;
//         uint _bobAmountLocked = puppetToken.balanceOf(users.bob) / 3;
//         uint _totalSupplyBefore;
//         uint _votingEscrowBalanceBefore;
//         uint _lockedAmountBefore;

//         // --- CREATE LOCK ---

//         // alice
//         _checkCreateLockWrongFlows(users.alice);
//         vm.startPrank(users.alice);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.alice).amount;
//         puppetToken.approve(address(router), _aliceAmountLocked);
//         votingEscrowLocker.lock(_aliceAmountLocked, block.timestamp + MAXTIME);
//         _totalSupplyBefore = votingEscrow.totalSupply();

//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.alice, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // bob
//         _checkCreateLockWrongFlows(users.bob);
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.bob).amount;
//         puppetToken.approve(address(router), _bobAmountLocked);
//         votingEscrowLocker.lock(_bobAmountLocked, block.timestamp + MAXTIME);
//         // vm.expectRevert(VotingEscrow.VotingEscrow__InvaidLockingSchedule.selector);
//         // votingEscrowLocker.lock(users.bob, users.bob, _bobAmountLocked, block.timestamp + 8 * 86400);
//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.bob, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- DEPOSIT FOR ---
//         // alice
//         vm.startPrank(users.owner);
//         dictator.setAccess(votingEscrow, users.alice);

//         _checkDepositForWrongFlows(_aliceAmountLocked, users.alice, users.bob);
//         vm.startPrank(users.alice);
//         puppetToken.approve(address(router), _bobAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.alice);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.bob).amount;
//         uint _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
//         uint _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
//         votingEscrow.lock(users.alice, users.bob, _aliceAmountLocked, 0);

//         // // vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(
//             users.alice,
//             users.bob,
//             _aliceBalanceBefore,
//             _bobBalanceBefore,
//             _aliceAmountLocked,
//             _totalSupplyBefore,
//             _votingEscrowBalanceBefore,
//             _lockedAmountBefore
//         );

//         vm.startPrank(users.owner);
//         dictator.removeAccess(votingEscrow, users.alice);
//         dictator.setAccess(votingEscrow, users.bob);

//         // bob
//         _checkDepositForWrongFlows(_bobAmountLocked, users.bob, users.alice);
//         vm.startPrank(users.bob);
//         puppetToken.approve(address(router), _aliceAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.alice).amount;
//         _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
//         _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
//         votingEscrow.lockFor(users.bob, users.alice, _bobAmountLocked, 0);

//         vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(
//             users.bob,
//             users.alice,
//             _bobBalanceBefore,
//             _aliceBalanceBefore,
//             _bobAmountLocked,
//             _totalSupplyBefore,
//             _votingEscrowBalanceBefore,
//             _lockedAmountBefore
//         );

//         vm.startPrank(users.owner);
//         dictator.removeAccess(votingEscrow, users.bob);

//         // --- INCREASE UNLOCK TIME ---

//         _checkLockTimesBeforeSkip();
//         _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
//         _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
//         _totalSupplyBefore = votingEscrow.totalSupply();

//         skip(MAXTIME / 2); // skip half of the lock time
//         _checkLockTimesAfterSkipHalf(_aliceBalanceBefore, _bobBalanceBefore, _totalSupplyBefore);

//         _checkIncreaseUnlockTimeWrongFlows();
//         vm.startPrank(users.alice);
//         uint _aliceBalanceBeforeUnlock = votingEscrow.balanceOf(users.alice);
//         uint _totalSupplyBeforeUnlock = votingEscrow.totalSupply();
//         votingEscrowLocker.lock(0, block.timestamp + MAXTIME);
//         vm.stopPrank();

//         vm.startPrank(users.bob);
//         uint _bobBalanceBeforeUnlock = votingEscrow.balanceOf(users.bob);
//         votingEscrowLocker.lock(0, block.timestamp + MAXTIME);
//         vm.stopPrank();

//         _checkUserLockTimesAfterIncreaseUnlockTime(
//             _aliceBalanceBeforeUnlock, _aliceBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.alice
//         );
//         _checkUserLockTimesAfterIncreaseUnlockTime(
//             _bobBalanceBeforeUnlock, _bobBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.bob
//         );

//         // --- INCREASE AMOUNT ---

//         _checkIncreaseAmountWrongFlows(users.alice);
//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = votingEscrow.balanceOf(users.alice);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.alice).amount;
//         puppetToken.approve(address(router), _aliceAmountLocked);
//         votingEscrowLocker.lock(_aliceAmountLocked, 0);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(
//             users.alice, _aliceBalanceBefore, _totalSupplyBefore, _aliceAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore
//         );

//         _checkIncreaseAmountWrongFlows(users.bob);
//         vm.startPrank(users.bob);
//         _bobBalanceBefore = votingEscrow.balanceOf(users.bob);
//         _totalSupplyBefore = votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = puppetToken.balanceOf(address(votingEscrow));
//         _lockedAmountBefore = votingEscrow.getLock(users.bob).amount;
//         puppetToken.approve(address(router), _bobAmountLocked);
//         votingEscrowLocker.lock(_bobAmountLocked, 0);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(
//             users.bob, _bobBalanceBefore, _totalSupplyBefore, _bobAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore
//         );

//         // --- WITHDRAW ---

//         _checkWithdrawWrongFlows(users.alice);

//         _totalSupplyBefore = votingEscrow.totalSupply();

//         skip(MAXTIME + 1); // entire lock time

//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = puppetToken.balanceOf(users.alice);
//         votingEscrowLocker.withdraw();
//         (uint amount, uint end) = votingEscrow.locked(users.alice);
//         assertEq(amount, 0);
//         assertEq(end, 0);
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.alice, _totalSupplyBefore, _aliceBalanceBefore);

//         vm.startPrank(users.bob);
//         _bobBalanceBefore = puppetToken.balanceOf(users.bob);
//         votingEscrowLocker.withdraw();
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.bob, _totalSupplyBefore, _bobBalanceBefore);
//         assertEq(puppetToken.balanceOf(address(votingEscrow)), 0, "testMutated: E0");
//     }

//     // =======================================================
//     // Internal functions
//     // =======================================================

//     function _checkCreateLockWrongFlows(address _user) internal {
//         uint _puppetBalance = puppetToken.balanceOf(_user);
//         uint _maxTime = MAXTIME;
//         require(_puppetBalance > 0, "no PUPPET balance");

//         vm.startPrank(_user);

//         vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
//         votingEscrowLocker.lock(_puppetBalance, block.timestamp + _maxTime);

//         puppetToken.approve(address(router), _puppetBalance);

//         vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
//         votingEscrowLocker.lock(0, 0);

//         vm.warp(2);
//         vm.expectRevert(VotingEscrow.VotingEscrow__InvaidLockingSchedule.selector);
//         votingEscrowLocker.lock(_puppetBalance, 3);

//         puppetToken.approve(address(router), 0);

//         vm.stopPrank();
//     }

//     function _checkUserVotingDataAfterCreateLock(
//         address _user,
//         uint _amountLocked,
//         uint _totalSupplyBefore,
//         uint _votingEscrowBalanceBefore,
//         uint _lockedAmountBefore
//     ) internal {
//         vm.startPrank(_user);

//         uint _puppetBalance = puppetToken.balanceOf(_user);
//         // uint256 _maxTime = MAXTIME;
//         puppetToken.approve(address(router), _puppetBalance);
//         // vm.expectRevert(bytes4(keccak256("WithdrawOldTokensFirst()")));
//         // votingEscrowLocker.lock(_user, _puppetBalance, block.timestamp + _maxTime);
//         puppetToken.approve(address(router), 0);

//         assertTrue(votingEscrow.getUserPoint(_user).slope != 0, "_checkUserVotingDataAfterCreateLock: E0");
//         assertTrue(votingEscrow.getUserPoint(_user).ts != 0, "_checkUserVotingDataAfterCreateLock: E1");
//         assertApproxEqAbs(votingEscrow.getLock(_user).end, block.timestamp + MAXTIME, 1e10, "_checkUserVotingDataAfterCreateLock: E2");
//         assertApproxEqAbs(votingEscrow.balanceOf(_user), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E3");
//         assertApproxEqAbs(votingEscrow.balanceOf(_user, block.timestamp), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E4");

//         assertApproxEqAbs(votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E6");
//         assertApproxEqAbs(
//             votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E7"
//         );
//         assertEq(_votingEscrowBalanceBefore, puppetToken.balanceOf(address(votingEscrow)) - _amountLocked, "_checkUserVotingDataAfterCreateLock: E8");
//         assertTrue(puppetToken.balanceOf(address(votingEscrow)) > 0, "_checkUserVotingDataAfterCreateLock: E9");
//         assertEq(_votingEscrowBalanceBefore + _amountLocked, puppetToken.balanceOf(address(votingEscrow)), "_checkUserVotingDataAfterCreateLock: E10");
//         assertEq(votingEscrow.getLock(_user).amount, _lockedAmountBefore + _amountLocked, "_checkUserVotingDataAfterCreateLock: E11");
//     }

//     function _checkDepositForWrongFlows(uint _amount, address _user, address _receiver) internal {
//         vm.startPrank(_user);

//         vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
//         votingEscrowLocker.lock(0, 0);

//         vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
//         votingEscrowLocker.lock(_amount, 0);

//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterDepositFor(
//         address _user,
//         address _receiver,
//         uint _userBalanceBefore,
//         uint _receiverBalanceBefore,
//         uint _amount,
//         uint _totalSupplyBefore,
//         uint _votingEscrowBalanceBefore,
//         uint _lockedAmountBefore
//     ) internal {
//         assertEq(votingEscrow.balanceOf(_user), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E0");
//         assertApproxEqAbs(votingEscrow.balanceOf(_receiver), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E1");
//         assertEq(votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E2");
//         assertApproxEqAbs(
//             votingEscrow.balanceOf(_receiver, block.timestamp), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E3"
//         );
//         assertApproxEqAbs(votingEscrow.totalSupply(), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E6");
//         assertApproxEqAbs(votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E7");
//         assertEq(puppetToken.balanceOf(address(votingEscrow)), _votingEscrowBalanceBefore + _amount, "_checkUserBalancesAfterDepositFor: E8");
//         assertEq(votingEscrow.getLock(_receiver).amount, _lockedAmountBefore + _amount, "_checkUserBalancesAfterDepositFor: E9");
//     }

//     function _checkLockTimesBeforeSkip() internal {
//         assertApproxEqAbs(votingEscrow.getLock(users.alice).end, block.timestamp + MAXTIME, 1e6, "_checkLockTimesBeforeSkip: E0");
//         assertApproxEqAbs(votingEscrow.getLock(users.bob).end, block.timestamp + MAXTIME, 1e6, "_checkLockTimesBeforeSkip: E1");
//     }

//     function _checkLockTimesAfterSkipHalf(uint _aliceBalanceBefore, uint _bobBalanceBefore, uint _totalSupplyBefore) internal {
//         assertApproxEqAbs(votingEscrow.balanceOf(users.alice), _aliceBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E0");
//         assertApproxEqAbs(votingEscrow.balanceOf(users.bob), _bobBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E1");
//         assertEq(votingEscrow.balanceOf(users.alice, block.timestamp - MAXTIME / 2), _aliceBalanceBefore, "_checkLockTimesAfterSkipHalf: E2");
//         assertEq(votingEscrow.balanceOf(users.bob, block.timestamp - MAXTIME / 2), _bobBalanceBefore, "_checkLockTimesAfterSkipHalf: E3");
//         assertApproxEqAbs(votingEscrow.totalSupply(), _totalSupplyBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E4");
//         assertEq(votingEscrow.totalSupply(block.timestamp - MAXTIME / 2), _totalSupplyBefore, "_checkLockTimesAfterSkipHalf: E5");
//     }

//     function _checkIncreaseUnlockTimeWrongFlows() internal {
//         uint _maxTime = MAXTIME;
//         // uint256 _userLockEnd = _votingEscrow.lockedEnd(_user);

//         vm.startPrank(users.yossi);
//         vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
//         votingEscrowLocker.lock(0, block.timestamp + _maxTime);
//         vm.stopPrank();

//         // vm.startPrank(_user);
//         // // vm.expectRevert(bytes4(keccak256("LockTimeInThePast()")));
//         // _votingEscrow.increaseUnlockTime(_userLockEnd);
//         // vm.stopPrank();
//     }

//     function _checkUserLockTimesAfterIncreaseUnlockTime(
//         uint _userBalanceBeforeUnlock,
//         uint _userBalanceBefore,
//         uint _totalSupplyBeforeUnlock,
//         uint _totalSupplyBefore,
//         address _user
//     ) internal {
//         assertApproxEqAbs(votingEscrow.getLock(_user).end, block.timestamp + MAXTIME, 1e6, "_checkUserLockTimesAfterIncreaseUnlockTime: E0");
//         assertApproxEqAbs(votingEscrow.balanceOf(_user), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E1");
//         assertApproxEqAbs(
//             votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E2"
//         );

//         // assertEq(_votingEscrow.balanceOfAtT(_user, block.timestamp - _MAXTIME / 2),
//         // _votingEscrow.balanceOf(_user), "_checkUserLockTimesAfterIncreaseUnlockTime: E3");
//         assertTrue(votingEscrow.totalSupply() > _totalSupplyBeforeUnlock, "_checkUserLockTimesAfterIncreaseUnlockTime: E4");
//         assertApproxEqAbs(votingEscrow.totalSupply(), _totalSupplyBefore, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E5");
//         assertApproxEqAbs(_userBalanceBefore, votingEscrow.balanceOf(_user), 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E6");
//     }

//     function _checkIncreaseAmountWrongFlows(address _user) internal {
//         vm.startPrank(_user);
//         vm.expectRevert();
//         votingEscrowLocker.lock(0, 0);
//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterIncreaseAmount(
//         address _user,
//         uint _balanceBefore,
//         uint _totalSupplyBefore,
//         uint _amountLocked,
//         uint _votingEscrowBalanceBefore,
//         uint _lockedAmountBefore
//     ) internal {
//         assertApproxEqAbs(votingEscrow.balanceOf(_user), _balanceBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E0");
//         assertApproxEqAbs(votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E1");
//         assertEq(
//             puppetToken.balanceOf(address(votingEscrow)), _votingEscrowBalanceBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E2"
//         );
//         assertEq(votingEscrow.getLock(_user).amount, _lockedAmountBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E3");
//     }

//     function _checkWithdrawWrongFlows(address _user) internal {
//         vm.startPrank(_user);
//         vm.expectRevert(); // reverts with ```The lock didn't expire```
//         votingEscrowLocker.withdraw();
//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterWithdraw(address _user, uint _totalSupplyBefore, uint _puppetBalanceBefore) internal {
//         assertEq(votingEscrow.balanceOf(_user), 0, "_checkUserBalancesAfterWithdraw: E0");
//         assertTrue(votingEscrow.totalSupply() < _totalSupplyBefore, "_checkUserBalancesAfterWithdraw: E1");
//         assertTrue(puppetToken.balanceOf(_user) > _puppetBalanceBefore, "_checkUserBalancesAfterWithdraw: E2");
//     }
// }

// contract VotingEscrowLocker {
//     VotingEscrow votingEscrow;

//     constructor(VotingEscrow _votingEscrow) {
//         votingEscrow = _votingEscrow;
//     }

//     function lock(uint _amount, uint _unlockTime) public {
//         votingEscrow.lockFor(msg.sender, msg.sender, _amount, _unlockTime);
//     }

//     function withdraw() public {
//         votingEscrow.withdrawFor(msg.sender, msg.sender);
//     }
// }
