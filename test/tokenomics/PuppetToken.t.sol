// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "src/tokenomics/PuppetToken.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract PuppetTokenTest is BasicSetup {
    uint YEAR = 31540000;

    function setUp() public override {
        super.setUp();

        dictator.setUserRole(users.owner, MINT_PUPPET_ROLE, true);
        dictator.setUserRole(users.owner, MINT_CORE_RELEASE_ROLE, true);
    }

    function testMintLimit() public {
        assertEq(puppetToken.mint(users.alice, 100e18), 100e18);

        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 901e18));
        puppetToken.mint(users.bob, 1000e18);

        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 50e18);

        puppetToken.mint(users.alice, 500e18);
        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 300e18);

        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1019e18);
        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1029e18);

        vm.warp(YEAR);

        for (uint i = 0; i < 10; i++) {
            skip(1 hours);
            puppetToken.mint(users.alice, 1000e18);
        }

        assertEq(puppetToken.getLimitAmount(), 1129e18);
    }

    function testMint() public {
        // skip(31540000);

        assertEq(puppetToken.mintCore(users.owner), 0);
        assertEq(puppetToken.mint(users.alice, 100e18), 100e18);
        assertEq(puppetToken.mineMintCount(), 100e18);
        assertEq(puppetToken.getCoreShare(), 0.5e30);

        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 50e18);

        puppetToken.mint(users.alice, 500e18);
        puppetToken.mintCore(users.bob);
        assertEq(puppetToken.balanceOf(users.bob), 300e18);

        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);

        vm.warp(YEAR + 1);

        assertEq(puppetToken.getCoreShare(), 0.25e30);
    }
}
