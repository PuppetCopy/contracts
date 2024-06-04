// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "src/utils/Precision.sol";

import {PuppetToken} from "src/token/PuppetToken.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract PuppetTokenTest is BasicSetup {
    uint YEAR = 31560000;

    function setUp() public override {
        super.setUp();

        dictator.setPermission(puppetToken, users.owner, puppetToken.mint.selector);
        dictator.setPermission(puppetToken, users.owner, puppetToken.mintCore.selector);
    }

    function testMint() public {
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
    }

    function testCoreDistribution() public {
        for (uint i = 0; i < 200; i++) {
            puppetToken.mint(users.alice, 500e18);
            skip(1 hours / 2);

            puppetToken.mintCore(users.owner);
        }

        assertEq(
            Precision.applyFactor(puppetToken.getCoreShare(), puppetToken.balanceOf(users.alice)), //
            puppetToken.mintedCoreAmount()
        );

        // ±4 years, 10% of the core share
        for (uint i = 0; i < 420; i++) {
            puppetToken.mint(users.alice, 1000e18);
            skip(1 weeks / 2);
        }

        puppetToken.mintCore(users.owner);

        assertEq(
            Precision.applyFactor(puppetToken.getCoreShare(), puppetToken.balanceOf(users.alice)), //
            puppetToken.mintedCoreAmount()
        );

        assertApproxEqAbs(puppetToken.getLimitAmount(), 7234e18, 6e18);
    }
}
