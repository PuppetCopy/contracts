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

/// @title TimingAttacks
/// @notice Tests for timing-related attack vectors and staleness issues
/// @dev Covers: stale attestations, front-running, deadline manipulation, price movements
contract TimingAttacksTest is BasicSetup {
    Allocate allocate;
    Match matcher;
    TokenRouter tokenRouter;
    Registry registry;
    Withdraw withdraw;
    AttestorMock attestorMock;

    TestSmartAccount master;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;

    uint256 constant TOKEN_CAP = 10_000_000e6;
    uint256 constant GAS_LIMIT = 500_000;
    uint256 constant ATTESTOR_PRIVATE_KEY = 0xA77E5707;

    bytes32 constant MASTER_NAME = bytes32("timing-test");

    // User private keys for signing intents
    address owner;
    uint256 ownerPrivateKey = 0x1234;
    uint256 puppet1PrivateKey = 0xABCD1;
    uint256 puppet2PrivateKey = 0xABCD2;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        attestorMock = new AttestorMock(ATTESTOR_PRIVATE_KEY);

        matcher = new Match(dictator, Match.Config({minThrottlePeriod: 6 hours}));
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config({transferGasLimit: GAS_LIMIT}));

        // Build allowed code hash list for TestSmartAccount
        bytes32[] memory codeList = new bytes32[](1);
        codeList[0] = keccak256(type(TestSmartAccount).runtimeCode);

        registry = new Registry(dictator, Registry.Config({
            masterHook: users.owner,
            account7579CodeList: codeList
        }));

        allocate = new Allocate(
            dictator,
            Allocate.Config({
                attestor: attestorMock.attestorAddress(),
                maxBlockStaleness: 240,  // ~1 hour at 15s blocks
                maxTimestampAge: 60      // 60 seconds
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

        // Register contracts
        dictator.registerContract(address(matcher));
        dictator.registerContract(address(tokenRouter));
        dictator.registerContract(address(allocate));
        dictator.registerContract(address(registry));
        dictator.registerContract(address(withdraw));

        // Set permissions
        dictator.setPermission(registry, registry.setTokenCap.selector, users.owner);
        dictator.setPermission(allocate, allocate.allocate.selector, users.owner);
        dictator.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocate));
        dictator.setPermission(withdraw, withdraw.withdraw.selector, users.owner);

        // Create accounts
        master = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        // Install executors
        master.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        master.installModule(MODULE_TYPE_EXECUTOR, address(withdraw), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");

        registry.setTokenCap(usdc, TOKEN_CAP);

        // Fund accounts
        usdc.mint(address(puppet1), 10_000e6);
        usdc.mint(address(puppet2), 10_000e6);
        usdc.mint(owner, 10_000e6);

        vm.stopPrank();

        // Approvals
        vm.prank(address(puppet1));
        usdc.approve(address(tokenRouter), type(uint256).max);
        vm.prank(address(puppet2));
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
        vm.stopPrank();

        vm.prank(address(puppet1));
        matcher.setPolicy(address(puppet1), IERC7579Account(address(0)), 10000, 6 hours, block.timestamp + 365 days);
        vm.prank(address(puppet2));
        matcher.setPolicy(address(puppet2), IERC7579Account(address(0)), 10000, 6 hours, block.timestamp + 365 days);
    }

    function _registerMaster() internal {
        registry.createMaster(owner, owner, master, usdc, MASTER_NAME);
    }

    // ============ Stale Attestation Tests ============

    /// @notice Test: Attestation signed at price X, but price moved UP before execution
    /// @dev User loses value because they withdraw at old (lower) price
    /// Protection: User's acceptableSharePrice in intent
    function test_StaleAttestation_PriceMovedUp_UserLoses() public {
        _registerMaster();

        // 1. Puppet allocates 1000 USDC at price 1.0
        _allocate(address(puppet1), 1000e6, 0);
        assertEq(usdc.balanceOf(address(master)), 1000e6);

        // 2. Master makes profit (NAV doubles)
        usdc.mint(address(master), 1000e6);
        // Now: NAV = 2000, shares = 1000, price = 2.0

        // 3. Attestor signs withdrawal at OLD price (1.0) - simulating stale read
        uint256 staleSharePrice = Precision.FLOAT_PRECISION; // 1.0
        uint256 sharesToWithdraw = 500e6;

        // 4. User signs intent with acceptableSharePrice = staleSharePrice
        //    This is the vulnerability: user accepted 1.0 but actual is 2.0
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(
            puppet1PrivateKey,
            address(puppet1),
            sharesToWithdraw,
            staleSharePrice, // acceptableSharePrice
            0
        );

        // 5. Attestor signs attestation at stale price
        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw,
            address(puppet1),
            address(master),
            address(usdc),
            sharesToWithdraw,
            staleSharePrice,
            0,
            block.timestamp + 1 hours
        );

        // 6. Execute withdrawal
        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // User got 500 USDC (500 shares * 1.0 price)
        assertEq(received, 500e6);

        // But at fair price (2.0), they should have gotten 1000 USDC
        // User lost 500 USDC due to stale attestation
        uint256 fairValue = Precision.applyFactor(2 * Precision.FLOAT_PRECISION, sharesToWithdraw);
        assertEq(fairValue, 1000e6);
        assertEq(fairValue - received, 500e6); // Lost value
    }

    /// @notice Test: User protects themselves with higher acceptableSharePrice
    /// @dev Withdrawal should revert if attestor provides lower price
    function test_StaleAttestation_UserProtection_RejectsLowPrice() public {
        _registerMaster();

        _allocate(address(puppet1), 1000e6, 0);
        usdc.mint(address(master), 1000e6); // NAV = 2000, price = 2.0

        uint256 sharesToWithdraw = 500e6;
        uint256 userExpectedPrice = 2 * Precision.FLOAT_PRECISION; // User expects 2.0
        uint256 staleAttestorPrice = Precision.FLOAT_PRECISION;     // Attestor signs 1.0

        // User signs intent with high acceptableSharePrice
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(
            puppet1PrivateKey,
            address(puppet1),
            sharesToWithdraw,
            userExpectedPrice, // Won't accept less than 2.0
            0
        );

        // Attestor signs with stale (lower) price
        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw,
            address(puppet1),
            address(master),
            address(usdc),
            sharesToWithdraw,
            staleAttestorPrice, // Lower than user's acceptable
            0,
            block.timestamp + 1 hours
        );

        // Should revert because attestor price < user's acceptable price
        vm.expectRevert(Error.Withdraw__SharePriceBelowMin.selector);
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
    }

    /// @notice Test: Attestation signed at high price, but NAV dropped before execution
    /// @dev Attacker extracts more than fair share (value extraction attack)
    /// Protection: Short deadlines, attestor monitoring
    function test_StaleAttestation_PriceMovedDown_Extraction() public {
        _registerMaster();

        // 1. Two puppets allocate
        _allocate(address(puppet1), 1000e6, 0);

        vm.warp(block.timestamp + 7 hours);
        vm.roll(block.number + 100);

        _allocate(address(puppet2), 1000e6, 1);

        assertEq(usdc.balanceOf(address(master)), 2000e6);
        // Total shares: 2000, NAV: 2000, price: 1.0

        // 2. Attestor signs withdrawal for puppet1 at current price
        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 sharesToWithdraw = 1000e6;

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw,
            address(puppet1),
            address(master),
            address(usdc),
            sharesToWithdraw,
            sharePrice,
            0,
            block.timestamp + 1 hours
        );

        // 3. BEFORE tx lands, Master loses 50% (simulate via burn)
        // In reality: trading loss, hack, etc.
        vm.stopPrank();
        vm.prank(address(master));
        usdc.transfer(address(0xdead), 1000e6);
        vm.startPrank(users.owner);

        // Now: NAV = 1000, shares = 2000, fair price = 0.5
        assertEq(usdc.balanceOf(address(master)), 1000e6);

        // 4. Puppet1 executes withdrawal at OLD (higher) price
        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Puppet1 got 1000 USDC (full NAV!) at stale price
        assertEq(received, 1000e6);

        // Master now has 0, puppet2 is left with nothing
        assertEq(usdc.balanceOf(address(master)), 0);

        // This is the extraction attack: puppet1 got 1000 but fair share was 500
    }

    // ============ Deadline Tests ============

    /// @notice Test: Attestation expires before execution
    function test_Deadline_AttestationExpired() public {
        _registerMaster();
        _allocate(address(puppet1), 1000e6, 0);

        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 sharesToWithdraw = 500e6;
        uint256 shortDeadline = block.timestamp + 30; // 30 seconds

        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0);

        // Override intent deadline to short value
        intent.deadline = shortDeadline;
        // Re-sign with correct deadline
        (intent, intentSig) = _signUserIntentWithDeadline(
            puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0, shortDeadline
        );

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw,
            address(puppet1),
            address(master),
            address(usdc),
            sharesToWithdraw,
            sharePrice,
            0,
            shortDeadline
        );

        // Warp past deadline
        vm.warp(block.timestamp + 60);

        vm.expectRevert(Error.Withdraw__ExpiredDeadline.selector);
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
    }

    /// @notice Test: Allocation attestation becomes stale (block too old)
    function test_Allocation_BlockStaleness_Rejected() public {
        _registerMaster();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        // Sign attestation at current block with very long deadline (won't expire)
        uint256 attestedBlock = block.number;
        uint256 attestedTimestamp = block.timestamp;

        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            Precision.FLOAT_PRECISION,
            0,
            puppetList,
            amountList,
            attestedBlock,
            attestedTimestamp,
            0,
            attestedTimestamp + 24 hours // Long deadline so it doesn't expire first
        );

        // Advance beyond maxBlockStaleness (240 blocks) but not past deadline
        vm.roll(block.number + 250);
        vm.warp(block.timestamp + 50); // Only 50 seconds, well within deadline

        // Should revert with block staleness error
        vm.expectRevert(); // Allocate__AttestationBlockStale
        allocate.allocate(registry, tokenRouter, matcher, master, puppetList, amountList, attestation);
    }

    /// @notice Test: Allocation attestation becomes stale (timestamp too old)
    function test_Allocation_TimestampStaleness_Rejected() public {
        _registerMaster();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        uint256 attestedBlock = block.number;
        uint256 attestedTimestamp = block.timestamp;

        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            Precision.FLOAT_PRECISION,
            0,
            puppetList,
            amountList,
            attestedBlock,
            attestedTimestamp,
            0,
            attestedTimestamp + 24 hours // Long deadline so it doesn't expire first
        );

        // Advance time beyond maxTimestampAge (60s) but keep blocks reasonable
        vm.warp(block.timestamp + 120);
        vm.roll(block.number + 8);

        // Should revert with timestamp staleness error
        vm.expectRevert(); // Allocate__AttestationTimestampStale
        allocate.allocate(registry, tokenRouter, matcher, master, puppetList, amountList, attestation);
    }

    // ============ Front-Running Tests ============

    /// @notice Test: Attacker front-runs large withdrawal with their own
    /// @dev First withdrawal drains funds, second fails or gets less
    function test_FrontRun_WithdrawalRace() public {
        _registerMaster();

        // Both puppets allocate
        _allocate(address(puppet1), 1000e6, 0);

        vm.warp(block.timestamp + 7 hours);
        vm.roll(block.number + 100);

        _allocate(address(puppet2), 1000e6, 1);

        // Master has 2000, each puppet has 1000 shares
        assertEq(usdc.balanceOf(address(master)), 2000e6);

        uint256 sharePrice = Precision.FLOAT_PRECISION;

        // Puppet1 signs withdrawal for ALL their shares
        (
            Withdraw.WithdrawIntent memory intent1,
            bytes memory intentSig1
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), 1000e6, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation1,
            bytes memory attestationSig1
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            1000e6, sharePrice, 0, block.timestamp + 1 hours
        );

        // Puppet2 also signs withdrawal for ALL their shares (same nonce scope, different nonce)
        (
            Withdraw.WithdrawIntent memory intent2,
            bytes memory intentSig2
        ) = _signUserIntent(puppet2PrivateKey, address(puppet2), 1000e6, sharePrice, 1);

        (
            Withdraw.WithdrawAttestation memory attestation2,
            bytes memory attestationSig2
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet2), address(master), address(usdc),
            1000e6, sharePrice, 1, block.timestamp + 1 hours
        );

        // Puppet1's tx lands first (or attacker front-runs)
        withdraw.withdraw(intent1, attestation1, intentSig1, attestationSig1);
        assertEq(usdc.balanceOf(address(puppet1)), 10_000e6); // 9000 + 1000 withdrawn
        assertEq(usdc.balanceOf(address(master)), 1000e6);

        // Puppet2's tx lands second - should succeed since Master has funds
        withdraw.withdraw(intent2, attestation2, intentSig2, attestationSig2);
        assertEq(usdc.balanceOf(address(puppet2)), 10_000e6);
        assertEq(usdc.balanceOf(address(master)), 0);

        // Both got their fair share - no attack possible when attestor is honest
        // The attack vector is when attestor signs for more than available
    }

    /// @notice Test: Attestor signs withdrawals totaling more than NAV
    /// @dev Second withdrawal fails due to insufficient balance
    function test_AttestorOvercommit_SecondWithdrawalFails() public {
        _registerMaster();

        _allocate(address(puppet1), 1000e6, 0);
        // Only 1000 in master

        uint256 sharePrice = Precision.FLOAT_PRECISION;

        // Attestor (maliciously or erroneously) signs TWO withdrawals for 600 each
        // Total = 1200 but only 1000 available

        (
            Withdraw.WithdrawIntent memory intent1,
            bytes memory intentSig1
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), 600e6, sharePrice, 0);

        (
            Withdraw.WithdrawAttestation memory attestation1,
            bytes memory attestationSig1
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            600e6, sharePrice, 0, block.timestamp + 1 hours
        );

        (
            Withdraw.WithdrawIntent memory intent2,
            bytes memory intentSig2
        ) = _signUserIntent(puppet1PrivateKey, address(puppet1), 600e6, sharePrice, 1);

        (
            Withdraw.WithdrawAttestation memory attestation2,
            bytes memory attestationSig2
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            600e6, sharePrice, 1, block.timestamp + 1 hours
        );

        // First withdrawal succeeds
        withdraw.withdraw(intent1, attestation1, intentSig1, attestationSig1);
        assertEq(usdc.balanceOf(address(master)), 400e6);

        // Second withdrawal fails - insufficient balance
        vm.expectRevert(); // ERC20 transfer will fail
        withdraw.withdraw(intent2, attestation2, intentSig2, attestationSig2);
    }

    // ============ Concurrent Operation Tests ============

    /// @notice Test: Allocation happens between withdrawal signing and execution
    /// @dev Share price might change, but user protected by acceptableSharePrice
    function test_AllocationDuringWithdrawal_PriceUnchanged() public {
        _registerMaster();

        _allocate(address(puppet1), 1000e6, 0);

        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 sharesToWithdraw = 500e6;

        // Puppet1 signs withdrawal with long deadline (to survive the time warp)
        uint256 longDeadline = block.timestamp + 24 hours;
        (
            Withdraw.WithdrawIntent memory intent,
            bytes memory intentSig
        ) = _signUserIntentWithDeadline(puppet1PrivateKey, address(puppet1), sharesToWithdraw, sharePrice, 0, longDeadline);

        (
            Withdraw.WithdrawAttestation memory attestation,
            bytes memory attestationSig
        ) = attestorMock.signWithdrawAttestation(
            withdraw, address(puppet1), address(master), address(usdc),
            sharesToWithdraw, sharePrice, 0, longDeadline
        );

        // BEFORE withdrawal executes, puppet2 allocates (requires throttle period)
        vm.warp(block.timestamp + 7 hours);
        vm.roll(block.number + 100);
        _allocate(address(puppet2), 1000e6, 1);

        // Master now has 2000, but share price is still 1.0 if shares doubled
        // (1000 puppet1 shares + 1000 new puppet2 shares, NAV = 2000)

        // Withdrawal still executes at attested price
        uint256 balanceBefore = usdc.balanceOf(address(puppet1));
        withdraw.withdraw(intent, attestation, intentSig, attestationSig);
        uint256 received = usdc.balanceOf(address(puppet1)) - balanceBefore;

        // Got 500 USDC as expected
        assertEq(received, 500e6);
    }

    // ============ Helper Functions ============

    function _allocate(address puppet, uint256 amount, uint256 nonce) internal {
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet;

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = amount;

        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            Precision.FLOAT_PRECISION,
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
        return _signUserIntentWithDeadline(
            privateKey, user, shares, acceptableSharePrice, nonce, block.timestamp + 1 hours
        );
    }

    function _signUserIntentWithDeadline(
        uint256 privateKey,
        address user,
        uint256 shares,
        uint256 acceptableSharePrice,
        uint256 nonce,
        uint256 deadline
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
            deadline: deadline
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
