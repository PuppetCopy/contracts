// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.29;

// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// import {Error} from "contracts/src/utils/Error.sol";
// import {PuppetToken} from "contracts/src/tokenomics/PuppetToken.sol";
// import {Precision} from "contracts/src/utils/Precision.sol";
// import {BasicSetup} from "test/base/BasicSetup.t.sol";

// contract PuppetTest is BasicSetup {
//     uint YEAR = 31560000;

//     function setUp() public override {
//         super.setUp();

//         dictator.setPermission(puppetToken, puppetToken.mint.selector, users.owner);
//         dictator.setPermission(puppetToken, puppetToken.mintCore.selector, users.owner);
//     }

//     function testCanFrontRunToReduceMintAmountForOtherUsers() public {
//         // Assume 3 hours has passed, this should allow _decayRate to be equal to 3 * getEmissionRateLimit()
//         skip(3 hours);
//         // However, an attacker (some authorized protocol) called Bob front-runs the call to the mint function
//         puppetToken.mint(users.bob, 0); // This resets the lastMintTime which means that the call now should revert

//         // Normally Alice should be Able to mint up to 4 * getEmissionRateLimit(). but it doesnt work since _decayRate
//         // is now equal to 0. Alice can only mint a max equal to getEmissionRateLimit() even after 3 epochs of nothing
//         // minted
//         uint amountToMint = 2 * puppetToken.getEmissionRateLimit();
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Error.PuppetToken__ExceededRateLimit.selector, 1000000000000000000000, 2000000000000000000000
//             )
//         );
//         puppetToken.mint(users.alice, amountToMint);
//         uint maxAmountToMint = puppetToken.getEmissionRateLimit();
//         puppetToken.mint(users.alice, maxAmountToMint);

//         // Alice can only mint getEmissionRateLimit() effectively losing 3 * getEmissionRateLimit()
//     }

//     function testMintSmallAmountContinuouslyGivesMoreTokens() public {
//         skip(1 hours);
//         assertEq(puppetToken.getEmissionRateLimit(), 1000e18); // Max amount that can be minted in one shot at time 0

//         // Alice notices that by dividing the buys into smaller ones she can earn more tokens.
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 5);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 5);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 5);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 5);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 5);

//         assertLt(puppetToken.balanceOf(users.alice), puppetToken.getEmissionRateLimit());
//     }

//     function testMintMoreThanLimitAmount() public {
//         skip(1 hours / 2);

//         uint initialLimit = puppetToken.getEmissionRateLimit();

//         vm.expectRevert();
//         puppetToken.mint(users.alice, initialLimit + 1);

//         skip(1 hours / 2);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit());

//         uint halfAmount = puppetToken.getEmissionRateLimit() / 2;
//         vm.expectRevert();
//         puppetToken.mint(users.alice, halfAmount);
//         skip(1 hours);
//         puppetToken.mint(users.alice, puppetToken.getEmissionRateLimit() / 2);
//     }

//     function testMint() public {
//         puppetToken.mint(users.alice, 1000e18);

//         vm.expectRevert(abi.encodeWithSelector(Error.PuppetToken__ExceededRateLimit.selector, 1010e18, 2000e18));
//         puppetToken.mint(users.alice, 1000e18);
//         skip(1 hours / 2);
//         puppetToken.mint(users.alice, 500e18);

//         skip(1 hours);
//         puppetToken.mint(users.alice, 500e18);
//         assertEq(puppetToken.getEmissionRateLimit(), 1020e18);
//         skip(1 hours / 2);
//         vm.expectRevert(abi.encodeWithSelector(Error.PuppetToken__ExceededRateLimit.selector, 1020e18, 1021e18));
//         puppetToken.mint(users.alice, 1021e18);
//         skip(1 hours / 2);
//         puppetToken.mint(users.alice, 1000e18);
//         assertEq(puppetToken.getEmissionRateLimit(), 1030e18);
//     }

//     function testCoreDistribution() public {
//         for (uint i = 0; i < 200; i++) {
//             puppetToken.mint(users.alice, 500e18);
//             skip(1 hours / 2);
//         }

//         puppetToken.mintCore(users.owner);

//         assertEq(
//             Precision.applyFactor(puppetToken.getCoreShare(), puppetToken.balanceOf(users.alice)), //
//             puppetToken.mintedCoreAmount()
//         );

//         // ±4 years, 10% of the core share
//         for (uint i = 0; i < 420; i++) {
//             puppetToken.mint(users.alice, 1000e18);
//             skip(1 weeks / 2);
//         }

//         puppetToken.mintCore(users.owner);

//         assertEq(
//             Precision.applyFactor(puppetToken.getCoreShare(), puppetToken.balanceOf(users.alice)), //
//             puppetToken.mintedCoreAmount()
//         );

//         assertApproxEqAbs(puppetToken.getEmissionRateLimit(), 7234e18, 6e18);
//     }
// }
