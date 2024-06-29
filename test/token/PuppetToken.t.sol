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

    function testCanFrontRunToReduceMintAmountForOtherUsers() public {
        // Assume 3 hours has passed, this should allow _decayRate to be equal to 3 * getLimitAmount()
        skip(3 hours);
        // However, an attacker (some authorized protocol) called Bob front-runs the call to the mint function
        puppetToken.mint(users.bob, 0); // This resets the lastMintTime which means that the call now should revert

        // Normally Alice should be Able to mint up to 4 * getLimitAmount(). but it doesnt work since _decayRate is now equal to 0. Alice can only
        // mint a max equal to getLimitAmount() even after 3 epochs of nothing minted
        uint amountToMint = 2 * puppetToken.getLimitAmount();
        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 1000000000000000000000, 2000000000000000000000));
        puppetToken.mint(users.alice, amountToMint);
        uint maxAmountToMint = puppetToken.getLimitAmount();
        puppetToken.mint(users.alice, maxAmountToMint);

        // Alice can only mint getLimitAmount() effectively losing 3 * getLimitAmount()
    }

    function testMintSmallAmountContinuouslyGivesMoreTokens() public {
        skip(1 hours);
        assertEq(puppetToken.getLimitAmount(), 1000e18); // Max amount that can be minted in one shot at time 0

        // Alice notices that by dividing the buys into smaller ones she can earn more tokens.
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 5);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 5);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 5);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 5);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 5);

        assertLt(puppetToken.balanceOf(users.alice), puppetToken.getLimitAmount());
    }

    function testMintMoreThanLimitAmount() public {
        skip(1 hours / 2);

        uint initialLimit = puppetToken.getLimitAmount();

        vm.expectRevert();
        puppetToken.mint(users.alice, initialLimit);

        skip(1 hours / 2);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount());

        uint halfAmount = puppetToken.getLimitAmount() / 2;
        vm.expectRevert();
        puppetToken.mint(users.alice, halfAmount);
        skip(1 hours);
        puppetToken.mint(users.alice, puppetToken.getLimitAmount() / 2);
    }

    function testMint() public {
        skip(1 hours);
        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 1000e18, 1001e18));
        puppetToken.mint(users.alice, 1001e18);

        assertEq(puppetToken.mint(users.alice, 100e18), 100e18);

        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 1001e18, 1100e18));
        puppetToken.mint(users.alice, 1000e18);
        puppetToken.mint(users.alice, 500e18);

        skip(1 hours);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1016e18);
        skip(1 hours / 2);
        vm.expectRevert(abi.encodeWithSelector(PuppetToken.PuppetToken__ExceededRateLimit.selector, 1016e18, 1492e18));
        puppetToken.mint(users.alice, 1000e18);
        skip(1 hours / 2);
        puppetToken.mint(users.alice, 1000e18);
        assertEq(puppetToken.getLimitAmount(), 1026e18);
    }

    function testCoreDistribution() public {
        skip(1 hours / 2);

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
