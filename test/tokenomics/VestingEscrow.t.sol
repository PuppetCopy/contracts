// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {VestingEscrow} from "src/utils/VestingEscrow.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract VestingEscrowTests is BasicSetup {
    VestingEscrow internal _vestingEscrow;

    function setUp() public override {
        BasicSetup.setUp();

        vm.startPrank(users.owner);
        _vestingEscrow = new VestingEscrow(dictator);

        dictator.setPublicCapability(address(_vestingEscrow), _vestingEscrow.initialize.selector, true);

        vm.stopPrank();

        require(puppetToken.balanceOf(users.owner) > 0, "users.owner token balance is zero");
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testFlow() external {
        uint256 _amountToVest = puppetToken.balanceOf(users.owner);
        require(_amountToVest > 0, "VestingEscrow: amountToVest is zero");

        uint256 _startTime = block.timestamp;
        uint256 _endTime = _startTime + 365 days;
        uint256 _vestingEscrowBalanceBefore = puppetToken.balanceOf(address(_vestingEscrow));

        vm.startPrank(users.owner);
        puppetToken.approve(address(_vestingEscrow), _amountToVest);
        _vestingEscrow.initialize(address(puppetToken), users.alice, _amountToVest, _startTime, _endTime, true);
        vm.stopPrank();

        assertEq(puppetToken.balanceOf(address(_vestingEscrow)), _vestingEscrowBalanceBefore + _amountToVest, "testFlow: E0");
        assertEq(puppetToken.balanceOf(users.owner), 0, "testFlow: E1");
        assertEq(puppetToken.balanceOf(users.alice), 0, "testFlow: E2");
        assertEq(_vestingEscrow.vestedSupply(), 0, "testFlow: E3");
        assertEq(_vestingEscrow.lockedSupply(), _amountToVest, "testFlow: E4");
        assertEq(_vestingEscrow.vestedOf(users.alice), 0, "testFlow: E5");
        assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E6");
        assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest, "testFlow: E7");

        skip(365 days / 2);

        assertEq(puppetToken.balanceOf(users.alice), 0, "testFlow: E8");
        assertEq(_vestingEscrow.vestedSupply(), _amountToVest / 2, "testFlow: E9");
        assertEq(_vestingEscrow.lockedSupply(), _amountToVest / 2, "testFlow: E10");
        assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest / 2, "testFlow: E11");
        assertEq(_vestingEscrow.balanceOf(users.alice), _amountToVest / 2, "testFlow: E12");
        assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest / 2, "testFlow: E13");

        _vestingEscrow.claim(users.alice);

        assertEq(puppetToken.balanceOf(users.alice), _amountToVest / 2, "testFlow: E14");
        assertEq(_vestingEscrow.vestedSupply(), _amountToVest / 2, "testFlow: E15");
        assertEq(_vestingEscrow.lockedSupply(), _amountToVest / 2, "testFlow: E16");
        assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest / 2, "testFlow: E17");
        assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E18");
        assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest / 2, "testFlow: E19");

        skip(365 days / 2);

        assertEq(puppetToken.balanceOf(users.alice), _amountToVest / 2, "testFlow: E20");
        assertEq(_vestingEscrow.vestedSupply(), _amountToVest, "testFlow: E21");
        assertEq(_vestingEscrow.lockedSupply(), 0, "testFlow: E22");
        assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest, "testFlow: E23");
        assertEq(_vestingEscrow.balanceOf(users.alice), _amountToVest / 2, "testFlow: E24");
        assertEq(_vestingEscrow.lockedOf(users.alice), 0, "testFlow: E25");

        _vestingEscrow.claim(users.alice);

        assertEq(puppetToken.balanceOf(users.alice), _amountToVest, "testFlow: E26");
        assertEq(_vestingEscrow.vestedSupply(), _amountToVest, "testFlow: E27");
        assertEq(_vestingEscrow.lockedSupply(), 0, "testFlow: E28");
        assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest, "testFlow: E29");
        assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E30");
        assertEq(_vestingEscrow.lockedOf(users.alice), 0, "testFlow: E31");
    }
}
