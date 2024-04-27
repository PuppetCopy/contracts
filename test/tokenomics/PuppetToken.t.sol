// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

import {Role} from "script/Const.sol";


contract PuppetTokenTest is BasicSetup {
    uint YEAR = 31540000;

    function setUp() public override {
        super.setUp();

        dictator.setUserRole(users.owner, Role.MINT_PUPPET, true);
        dictator.setUserRole(users.owner, Role.MINT_CORE_RELEASE, true);
    }

    function testMintLimit() public {
        assertEq(puppetToken.mint(users.alice, 100e18), 100e18);

        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 901e18));
        puppetToken.mint(users.alice, 1000e18);

        puppetToken.mint(users.alice, 500e18);

        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1016e18);
        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1026e18);

        vm.warp(YEAR);

        for (uint i = 0; i < 10; i++) {
            skip(1 hours);
            puppetToken.mint(users.alice, 1000e18);
        }

        assertEq(puppetToken.getLimitAmount(), 1126e18);
    }

    function testMint() public {
        assertEq(puppetToken.mintCore(users.owner), 0);
        assertEq(puppetToken.mint(users.alice, 200e18), 200e18);
        assertEq(puppetToken.mineMintCount(), 200e18);
        assertEq(puppetToken.getCoreShare(), 1e30);

        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 200e18);

        puppetToken.mint(users.alice, 800e18);
        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 1000e18);

        skip(YEAR / 2);
        puppetToken.mint(users.alice, 1000e18);
        skip(YEAR / 2);
        puppetToken.mint(users.alice, 1000e18);

        assertEq(puppetToken.balanceOf(users.alice), 3000e18);

        assertEq(puppetToken.getCoreShare(), 0.5e30);

        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 1500e18);

        skip(YEAR / 4);
        puppetToken.mint(users.alice, 1000e18);
        skip(YEAR / 4);
        puppetToken.mint(users.alice, 1000e18);
        skip(YEAR / 4);
        puppetToken.mint(users.alice, 1000e18);
        skip(YEAR / 4);

        assertEq(puppetToken.balanceOf(users.alice), 6000e18);

        assertAlmostEq(puppetToken.getCoreShare(), 0.333e30, 0.001e30);

        puppetToken.mintCore(users.bob);
        assertAlmostEq(puppetToken.balanceOf(users.bob), 2000e18, 0.001e18);
    }
}
