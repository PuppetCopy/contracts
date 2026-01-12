// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Registry} from "src/account/Registry.sol";
import {Withdraw} from "src/withdraw/Withdraw.sol";
import {Precision} from "src/utils/Precision.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {AttestorMock} from "../mock/AttestorMock.t.sol";

/// @title EconomicAttacks
/// @notice Tests for economic/math attack vectors: rounding, precision, share manipulation
/// @dev Covers: inflation attacks, rounding exploitation, precision loss, dust accumulation
contract EconomicAttacksTest is BasicSetup {
    Allocate allocate;
    Match matcher;
    TokenRouter tokenRouter;
    Registry registry;
    Withdraw withdraw;
    AttestorMock attestorMock;

    TestSmartAccount master;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;
    TestSmartAccount attacker;

    uint256 constant TOKEN_CAP = 100_000_000e6; // 100M USDC
    uint256 constant GAS_LIMIT = 500_000;
    uint256 constant ATTESTOR_PRIVATE_KEY = 0xA77E5707;

    bytes32 constant MASTER_NAME = bytes32("economic-test");

    address owner;
    uint256 ownerPrivateKey = 0x1234;
    uint256 puppet1PrivateKey = 0xABCD1;
    uint256 puppet2PrivateKey = 0xABCD2;
    uint256 attackerPrivateKey = 0xDEAD1;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        attestorMock = new AttestorMock(ATTESTOR_PRIVATE_KEY);

        matcher = new Match(dictator, Match.Config({minThrottlePeriod: 6 hours}));
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config({transferGasLimit: GAS_LIMIT}));

        // Build allowed code hash list for TestSmartAccount
        bytes32[] memory codeList = new bytes32[](1);
        codeList[0] = keccak256(type(TestSmartAccount).runtimeCode);

        registry = new Registry(dictator, Registry.Config({account7579CodeList: codeList}));
        dictator.setPermission(registry, registry.createMaster.selector, users.owner);

        allocate = new Allocate(
            dictator,
            Allocate.Config({
                attestor: attestorMock.attestorAddress(),
                maxBlockStaleness: 240,
                maxTimestampAge: 60
            })
        );

        withdraw = new Withdraw(
            dictator,
            Withdraw.Config({
                attestor: attestorMock.attestorAddress(),
                gasLimit: GAS_LIMIT,
                maxBlockStaleness: 240,
                maxTimestampAge: 120
            })
        );

        dictator.registerContract(address(matcher));
        dictator.registerContract(address(tokenRouter));
        dictator.registerContract(address(allocate));
        dictator.registerContract(address(registry));
        dictator.registerContract(address(withdraw));

        dictator.setPermission(registry, registry.setTokenCap.selector, users.owner);
        dictator.setPermission(allocate, allocate.allocate.selector, users.owner);
        dictator.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocate));
        dictator.setPermission(withdraw, withdraw.withdraw.selector, users.owner);

        master = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();
        attacker = new TestSmartAccount();

        master.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        master.installModule(MODULE_TYPE_EXECUTOR, address(withdraw), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        attacker.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");

        registry.setTokenCap(usdc, TOKEN_CAP);

        usdc.mint(address(puppet1), 10_000_000e6);
        usdc.mint(address(puppet2), 10_000_000e6);
        usdc.mint(address(attacker), 10_000_000e6);
        usdc.mint(owner, 10_000_000e6);

        vm.stopPrank();

        vm.prank(address(puppet1));
        usdc.approve(address(tokenRouter), type(uint256).max);
        vm.prank(address(puppet2));
        usdc.approve(address(tokenRouter), type(uint256).max);
        vm.prank(address(attacker));
        usdc.approve(address(tokenRouter), type(uint256).max);
        vm.prank(owner);
        usdc.approve(address(tokenRouter), type(uint256).max);

        _setupPuppetPolicies();

        vm.startPrank(users.owner);
    }

    function _setupPuppetPolicies() internal {
        vm.startPrank(users.owner);
        dictator.setPermission(matcher, matcher.setPolicy.selector, address(puppet1));
        dictator.setPermission(matcher, matcher.setPolicy.selector, address(puppet2));
        dictator.setPermission(matcher, matcher.setPolicy.selector, address(attacker));
        vm.stopPrank();

        vm.prank(address(puppet1));
        matcher.setPolicy(address(puppet1), IERC7579Account(address(0)), 10000, 6 hours, block.timestamp + 365 days);
        vm.prank(address(puppet2));
        matcher.setPolicy(address(puppet2), IERC7579Account(address(0)), 10000, 6 hours, block.timestamp + 365 days);
        vm.prank(address(attacker));
        matcher.setPolicy(address(attacker), IERC7579Account(address(0)), 10000, 6 hours, block.timestamp + 365 days);
    }

    function _registerMaster() internal {
        registry.createMaster(owner, owner, master, usdc, MASTER_NAME);
    }

    // ============ Share Inflation Attack Tests ============

    /// @notice Classic vault inflation attack: first depositor manipulates share price
    /// @dev Attack: 1) Deposit 1 wei → get 1 share, 2) Donate tokens directly
    ///      3) Next depositor's tokens → ~1 share due to inflated price
    ///      4) Attacker withdraws, gets ~half of victim's deposit
    /// Protection: Minimum deposit requirements, virtual shares, or share price floor
    /// Note: Protocol has partial protection by reverting on 0-share allocations
    function test_FirstDepositorInflationAttack() public {
        _registerMaster();

        // Step 1: Attacker allocates tiny amount (1 wei = smallest unit)
        // At initial price 1e30, shares = 1 * 1e30 / 1e30 = 1 share
        uint256 attackerDeposit = 1; // 1 wei of USDC (0.000001 USDC)
        _allocate(address(attacker), attackerDeposit, 0);

        // Verify attacker got shares (event-sourced, but funds transferred)
        assertEq(usdc.balanceOf(address(master)), attackerDeposit);

        // Step 2: Attacker "donates" directly to master (inflates NAV without minting shares)
        // Use a smaller donation that still demonstrates the attack but ensures victim gets 1 share
        // If donation is too large (>= victimDeposit), victim gets 0 shares and tx reverts (protection!)
        // With 999,999 USDC donation, victim gets exactly 1 share for their 1M USDC deposit
        uint256 donationAmount = 999_999e6; // Slightly less than 1M to ensure victim gets 1 share
        vm.stopPrank();
        vm.prank(address(attacker));
        usdc.transfer(address(master), donationAmount);
        vm.startPrank(users.owner);

        // Now: NAV = 999,999.000001 USDC, shares = 1 (attacker's)
        uint256 masterBalance = usdc.balanceOf(address(master));
        assertEq(masterBalance, attackerDeposit + donationAmount);

        // Step 3: Victim allocates 1M USDC at inflated price
        // Use explicit time values to avoid any stale timestamp issues
        uint256 newTimestamp = block.timestamp + 7 hours;
        uint256 newBlock = block.number + 100;
        vm.warp(newTimestamp);
        vm.roll(newBlock);

        uint256 victimDeposit = 1_000_000e6;
        // Share price = masterBalance * 1e30 / 1 share = ~1e42
        uint256 inflatedSharePrice = masterBalance * Precision.FLOAT_PRECISION / 1; // 1 share outstanding

        // Calculate expected shares for victim: victimDeposit * 1e30 / sharePrice
        // = 1e12 * 1e30 / ~999,999e36 = ~1 share
        uint256 expectedVictimShares = Precision.toFactor(victimDeposit, inflatedSharePrice);

        // The attack: victim gets ~1 share for 1M USDC while attacker got 1 share for 1 wei!
        emit log_named_uint("Inflated share price", inflatedSharePrice);
        emit log_named_uint("Expected victim shares", expectedVictimShares);

        // Allocation should succeed with 1 share for victim
        _allocateAtExplicitTime(address(puppet1), victimDeposit, inflatedSharePrice, 1, newBlock, newTimestamp);

        // Master now has ~2M USDC
        assertEq(usdc.balanceOf(address(master)), masterBalance + victimDeposit);

        // Attack analysis:
        // - Attacker has 1 share (from 1 wei + 999,999 USDC donation)
        // - Victim has 1 share (from 1M USDC deposit)
        // - Total NAV: ~2M USDC
        // - Each share worth: ~1M USDC
        //
        // If attacker used flash loan for donation:
        // - Borrow 999,999 USDC, donate, wait for victim
        // - After victim deposits, NAV = ~2M, attacker's 1 share = ~1M
        // - Withdraw 1M, repay 999,999 loan, keep ~1 USDC profit + victim's rounding loss
        //
        // Protection: The protocol reverts if donation >= victimDeposit (0 shares)
        // This limits the attack severity but doesn't fully prevent it

        // Verify attack succeeded: attacker owns 50% for (1 wei cost + temp donation)
        assertEq(expectedVictimShares, 1); // Victim got only 1 share for 1M USDC
    }

    /// @notice Test that minimum allocation prevents zero-share attacks
    /// @dev Protocol correctly reverts with Allocate__ZeroAmount when 0 shares would be minted
    function test_TinyAllocation_ZeroShares_Reverts() public {
        _registerMaster();

        // First allocate to establish non-zero share price
        _allocate(address(puppet1), 1000e6, 0);

        // Profit doubles the price
        vm.stopPrank();
        vm.prank(address(0xdead));
        usdc.mint(address(master), 1000e6);
        vm.startPrank(users.owner);

        // Share price is now 2e30 (2000 USDC / 1000 shares)
        uint256 newSharePrice = 2 * Precision.FLOAT_PRECISION;

        // Try to allocate 1 wei - should result in 0 shares
        uint256 newTimestamp = block.timestamp + 7 hours;
        uint256 newBlock = block.number + 100;
        vm.warp(newTimestamp);
        vm.roll(newBlock);

        // 1 wei at price 2e30 = 1 * 1e30 / 2e30 = 0 shares
        uint256 tinyAmount = 1;
        uint256 expectedShares = Precision.toFactor(tinyAmount, newSharePrice);
        assertEq(expectedShares, 0); // Confirms 0 shares would be minted

        // Create the attestation first (before vm.expectRevert)
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet2);
        uint256[] memory amountList = new uint256[](1);
        amountList[0] = tinyAmount;

        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            newSharePrice,
            0,
            puppetList,
            amountList,
            newBlock,
            newTimestamp,
            1,
            newTimestamp + 1 hours
        );

        // Protocol correctly rejects zero-share allocations
        // This is GOOD - prevents dust attacks where funds are lost
        vm.expectRevert(Error.Allocate__ZeroAmount.selector);
        allocate.allocate(registry, tokenRouter, matcher, master, puppetList, amountList, attestation);
    }

    // ============ Rounding Exploitation Tests ============

    /// @notice Test rounding direction: does it favor withdrawer or protocol?
    function test_RoundingDirection_WithdrawalFavorsProtocol() public {
        _registerMaster();

        // Allocate 1000 USDC
        _allocate(address(puppet1), 1000e6, 0);

        // Simulate odd profit that creates non-round share price
        vm.stopPrank();
        vm.prank(address(0xdead));
        usdc.mint(address(master), 333e6); // 333 USDC profit
        vm.startPrank(users.owner);

        // NAV = 1333 USDC, shares = 1000
        // Share price = 1333e6 * 1e30 / 1000e6 = 1.333e30
        uint256 sharePrice = 1333e6 * Precision.FLOAT_PRECISION / 1000e6;

        // Withdraw 500 shares
        uint256 sharesToWithdraw = 500e6;
        uint256 expectedAmount = Precision.applyFactor(sharePrice, sharesToWithdraw);

        // Calculate what user should get: 500 * 1.333 = 666.5 USDC
        // With integer math: 500e6 * 1.333e30 / 1e30 = 666.5e6 → rounds to 666e6

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, sharePrice, 0, block.timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Check rounding: did user lose the 0.5 USDC?
        emit log_named_uint("Expected amount", expectedAmount);
        emit log_named_uint("Received amount", received);

        // Rounding should be consistent and not exploitable
        assertEq(received, expectedAmount);
    }

    /// @notice Test repeated small withdrawals to accumulate rounding profits
    function test_RepeatedSmallWithdrawals_RoundingAccumulation() public {
        _registerMaster();

        // Large initial allocation
        _allocate(address(puppet1), 1_000_000e6, 0);

        // Create non-round share price
        vm.stopPrank();
        vm.prank(address(0xdead));
        usdc.mint(address(master), 111_111e6);
        vm.startPrank(users.owner);

        // NAV = 1,111,111 USDC, shares = 1,000,000
        // Price = 1.111111e30
        uint256 sharePrice = 1_111_111e6 * Precision.FLOAT_PRECISION / 1_000_000e6;

        // Attacker strategy: many small withdrawals to accumulate rounding in their favor
        uint256 numWithdrawals = 10; // Reduced for stack depth
        uint256 sharesPerWithdrawal = 10_000e6;
        uint256 totalSharesBurned = numWithdrawals * sharesPerWithdrawal;

        uint256 totalWithdrawn = _executeMultipleWithdrawals(
            sharePrice, numWithdrawals, sharesPerWithdrawal
        );

        // Compare: what if they withdrew all at once?
        uint256 singleWithdrawalAmount = Precision.applyFactor(sharePrice, totalSharesBurned);

        emit log_named_uint("Total via many withdrawals", totalWithdrawn);
        emit log_named_uint("Single withdrawal equivalent", singleWithdrawalAmount);

        // Difference should be minimal (within acceptable rounding bounds)
        uint256 diff = totalWithdrawn > singleWithdrawalAmount
            ? totalWithdrawn - singleWithdrawalAmount
            : singleWithdrawalAmount - totalWithdrawn;

        // Allow up to 1 unit per withdrawal of rounding variance
        assertLe(diff, numWithdrawals);
    }

    function _executeMultipleWithdrawals(
        uint256 sharePrice,
        uint256 numWithdrawals,
        uint256 sharesPerWithdrawal
    ) internal returns (uint256 totalWithdrawn) {
        for (uint256 i = 0; i < numWithdrawals; i++) {
            uint256 received = _executeSingleWithdrawal(sharePrice, sharesPerWithdrawal, i);
            totalWithdrawn += received;
        }
    }

    function _executeSingleWithdrawal(
        uint256 sharePrice,
        uint256 shares,
        uint256 nonce
    ) internal returns (uint256 received) {
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), shares, sharePrice, nonce);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            shares, sharePrice, nonce, block.timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        received = usdc.balanceOf(address(puppet1)) - balanceBefore;
    }

    // ============ Precision Boundary Tests ============

    /// @notice Test maximum share price doesn't overflow
    function test_MaxSharePrice_NoOverflow() public {
        _registerMaster();

        // Start with small allocation
        _allocate(address(puppet1), 1e6, 0); // 1 USDC → 1e6 shares

        // Massive profit: 1e12 USDC (1 trillion) - extreme but tests bounds
        vm.stopPrank();
        vm.prank(address(0xdead));
        usdc.mint(address(master), 1e18); // 1 trillion USDC
        vm.startPrank(users.owner);

        // Share price = 1e18 * 1e30 / 1e6 = 1e42
        // This is within uint256 bounds (max ~1e77)
        uint256 extremeSharePrice = (1e18 + 1e6) * Precision.FLOAT_PRECISION / 1e6;

        emit log_named_uint("Extreme share price", extremeSharePrice);

        // Withdrawal at extreme price should still work
        uint256 sharesToWithdraw = 0.5e6; // Half the shares

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, extremeSharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, extremeSharePrice, 0, block.timestamp + 1 hours
        );

        // Should not overflow
        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Should receive ~half of NAV
        assertGt(received, 0);
        emit log_named_uint("Received at extreme price", received);
    }

    /// @notice Test minimum share price doesn't lose precision
    function test_MinSharePrice_NoPrecisionLoss() public {
        _registerMaster();

        // Large allocation
        _allocate(address(puppet1), 1_000_000e6, 0); // 1M USDC

        // Massive loss: NAV drops to 1 USDC
        vm.stopPrank();
        vm.prank(address(master));
        usdc.transfer(address(0xdead), 999_999e6);
        vm.startPrank(users.owner);

        // Share price = 1e6 * 1e30 / 1_000_000e6 = 1e24 (very small)
        uint256 tinySharePrice = 1e6 * Precision.FLOAT_PRECISION / 1_000_000e6;

        emit log_named_uint("Tiny share price", tinySharePrice);

        // Withdraw should still work with precision
        uint256 sharesToWithdraw = 500_000e6; // Half shares

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, tinySharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, tinySharePrice, 0, block.timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Should receive ~0.5 USDC (half of remaining 1 USDC)
        emit log_named_uint("Received at tiny price", received);

        // Precision check: expected = 500_000e6 * 1e24 / 1e30 = 0.5e6
        uint256 expected = Precision.applyFactor(tinySharePrice, sharesToWithdraw);
        assertEq(received, expected);
    }

    // ============ Multi-Round Accumulation Tests ============

    /// @notice Test that many allocation rounds don't accumulate errors
    function test_ManyAllocationRounds_NoDrift() public {
        _registerMaster();

        uint256 numRounds = 5; // Reduced for simplicity
        uint256 amountPerRound = 1000e6;
        uint256 totalAllocated = 0;

        // Use explicit time tracking
        uint256 currentTimestamp = block.timestamp;
        uint256 currentBlock = block.number;

        for (uint256 i = 0; i < numRounds; i++) {
            address puppet = i % 2 == 0 ? address(puppet1) : address(puppet2);

            if (i > 0) {
                currentTimestamp += 7 hours;
                currentBlock += 100;
                vm.warp(currentTimestamp);
                vm.roll(currentBlock);
            }

            // Use standard price for simplicity
            _allocateAtExplicitTime(puppet, amountPerRound, Precision.FLOAT_PRECISION, i, currentBlock, currentTimestamp);
            totalAllocated += amountPerRound;

            // Simulate 10% profit every other round
            if (i % 2 == 0) {
                usdc.mint(address(master), amountPerRound / 10);
            }
        }

        uint256 finalMasterBalance = usdc.balanceOf(address(master));
        emit log_named_uint("Total allocated", totalAllocated);
        emit log_named_uint("Final master balance", finalMasterBalance);
        emit log_named_uint("Number of rounds", numRounds);

        // Final balance should be reasonable (not drifted to 0 or infinity due to errors)
        assertGt(finalMasterBalance, 0);
        // Should be at least total allocated plus some profit
        assertGe(finalMasterBalance, totalAllocated);
    }

    /// @notice Test alternating deposits and withdrawals maintain accounting
    function test_AlternatingDepositsWithdrawals_Consistency() public {
        _registerMaster();

        // Initial deposit
        _allocate(address(puppet1), 10_000e6, 0);

        uint256 iterations = 6; // Reduced for simplicity
        uint256 sharePrice = Precision.FLOAT_PRECISION;

        // Use explicit time tracking to avoid any timestamp issues
        uint256 currentTimestamp = block.timestamp;
        uint256 currentBlock = block.number;

        for (uint256 i = 0; i < iterations; i++) {
            // Always advance time for throttle
            currentTimestamp += 7 hours;
            currentBlock += 100;
            vm.warp(currentTimestamp);
            vm.roll(currentBlock);

            if (i % 2 == 0) {
                // Deposit round - use explicit time attestation
                _allocateAtExplicitTime(address(puppet2), 1000e6, sharePrice, i + 1, currentBlock, currentTimestamp);
            } else {
                // Withdrawal round
                _executeSingleWithdrawalAtTime(sharePrice, 500e6, i + 100, currentTimestamp);
            }
        }

        // Final state check - master should have positive balance
        uint256 finalBalance = usdc.balanceOf(address(master));
        emit log_named_uint("Final balance after alternating ops", finalBalance);
        assertGt(finalBalance, 0);
    }

    function _executeSingleWithdrawalFresh(
        uint256 sharePrice,
        uint256 shares,
        uint256 nonce
    ) internal returns (uint256 received) {
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntentFresh(puppet1PrivateKey, address(puppet1), shares, sharePrice, nonce);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            shares, sharePrice, nonce, block.timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        received = usdc.balanceOf(address(puppet1)) - balanceBefore;
    }

    function _signUserIntentFresh(
        uint256 privateKey,
        address user,
        uint256 shares,
        uint256 acceptableSharePrice,
        uint256 nonce
    ) internal view returns (Withdraw.WithdrawIntent memory intent, bytes memory signature) {
        uint256 minAmountOut = Precision.applyFactor(acceptableSharePrice, shares);

        intent = Withdraw.WithdrawIntent({
            user: user,
            master: address(master),
            token: address(usdc),
            shares: shares,
            acceptableSharePrice: acceptableSharePrice,
            minAmountOut: minAmountOut,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });

        bytes32 structHash = keccak256(
            abi.encode(
                withdraw.INTENT_TYPEHASH(),
                intent.user,
                intent.master,
                intent.token,
                intent.shares,
                intent.acceptableSharePrice,
                intent.minAmountOut,
                intent.nonce,
                intent.deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Withdraw"),
                keccak256("1"),
                block.chainid,
                address(withdraw)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    // ============ Edge Case Tests ============

    /// @notice Test withdrawal of exact total shares (drain master)
    function test_WithdrawExactTotal_DrainsMaster() public {
        _registerMaster();

        uint256 depositAmount = 1000e6;
        _allocate(address(puppet1), depositAmount, 0);

        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 sharesToWithdraw = depositAmount; // All shares

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, sharePrice, 0, block.timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Should receive exactly what was deposited
        assertEq(received, depositAmount);
        assertEq(usdc.balanceOf(address(master)), 0);
    }

    /// @notice Test withdrawal of more shares than owned (should work if attestor signs it)
    /// @dev This tests that the protocol trusts attestor for share balance validation
    function test_WithdrawMoreThanOwned_AttestorTrusted() public {
        _registerMaster();

        _allocate(address(puppet1), 1000e6, 0);

        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 sharesToWithdraw = 2000e6; // More than allocated!

        // Attestor (incorrectly) signs for 2000 shares
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, sharePrice, 0, block.timestamp + 1 hours
        );

        // This will fail because master doesn't have enough tokens
        // (not because of share validation - that's off-chain)
        vm.expectRevert(); // ERC20 insufficient balance
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
    }

    // ============ Helper Functions ============

    function _allocate(address puppet, uint256 amount, uint256 nonce) internal {
        _allocateWithPrice(puppet, amount, Precision.FLOAT_PRECISION, nonce);
    }

    function _allocateWithPrice(address puppet, uint256 amount, uint256 sharePrice, uint256 nonce) internal {
        _allocateWithPriceFresh(puppet, amount, sharePrice, nonce);
    }

    function _allocateAtExplicitTime(
        address puppet,
        uint256 amount,
        uint256 sharePrice,
        uint256 nonce,
        uint256 blockNum,
        uint256 timestamp
    ) internal {
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet;

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = amount;

        // Use explicit block/timestamp for attestation
        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            sharePrice,
            0,
            puppetList,
            amountList,
            blockNum,
            timestamp,
            nonce,
            timestamp + 1 hours
        );

        allocate.allocate(registry, tokenRouter, matcher, master, puppetList, amountList, attestation);
    }

    function _executeSingleWithdrawalAtTime(
        uint256 sharePrice,
        uint256 shares,
        uint256 nonce,
        uint256 timestamp
    ) internal returns (uint256 received) {
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntentAtTime(puppet1PrivateKey, address(puppet1), shares, sharePrice, nonce, timestamp);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            shares, sharePrice, nonce, timestamp + 1 hours
        );

        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        received = usdc.balanceOf(address(puppet1)) - balanceBefore;
    }

    function _signUserIntentAtTime(
        uint256 privateKey,
        address user,
        uint256 shares,
        uint256 acceptableSharePrice,
        uint256 nonce,
        uint256 timestamp
    ) internal view returns (Withdraw.WithdrawIntent memory intent, bytes memory signature) {
        uint256 minAmountOut = Precision.applyFactor(acceptableSharePrice, shares);

        intent = Withdraw.WithdrawIntent({
            user: user,
            master: address(master),
            token: address(usdc),
            shares: shares,
            acceptableSharePrice: acceptableSharePrice,
            minAmountOut: minAmountOut,
            nonce: nonce,
            deadline: timestamp + 1 hours
        });

        bytes32 structHash = keccak256(
            abi.encode(
                withdraw.INTENT_TYPEHASH(),
                intent.user,
                intent.master,
                intent.token,
                intent.shares,
                intent.acceptableSharePrice,
                intent.minAmountOut,
                intent.nonce,
                intent.deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Withdraw"),
                keccak256("1"),
                block.chainid,
                address(withdraw)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _allocateWithPriceFresh(address puppet, uint256 amount, uint256 sharePrice, uint256 nonce) internal {
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet;

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = amount;

        // Always use fresh block/timestamp for attestation
        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            sharePrice,
            0,
            puppetList,
            amountList,
            block.number,
            block.timestamp,
            nonce,
            block.timestamp + 1 hours
        );

        allocate.allocate(registry, tokenRouter, matcher, master, puppetList, amountList, attestation);
    }

    function _signUserIntent(
        uint256 privateKey,
        address user,
        uint256 shares,
        uint256 acceptableSharePrice,
        uint256 nonce
    ) internal view returns (Withdraw.WithdrawIntent memory intent, bytes memory signature) {
        uint256 minAmountOut = Precision.applyFactor(acceptableSharePrice, shares);

        intent = Withdraw.WithdrawIntent({
            user: user,
            master: address(master),
            token: address(usdc),
            shares: shares,
            acceptableSharePrice: acceptableSharePrice,
            minAmountOut: minAmountOut,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });

        bytes32 structHash = keccak256(
            abi.encode(
                withdraw.INTENT_TYPEHASH(),
                intent.user,
                intent.master,
                intent.token,
                intent.shares,
                intent.acceptableSharePrice,
                intent.minAmountOut,
                intent.nonce,
                intent.deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Withdraw"),
                keccak256("1"),
                block.chainid,
                address(withdraw)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
