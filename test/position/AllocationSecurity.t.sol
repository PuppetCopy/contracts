// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocation} from "src/position/Allocation.sol";
import {VenueRegistry} from "src/position/VenueRegistry.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {MockVenueValidator, MockVenue} from "../mock/MockVenueValidator.t.sol";
import {MockERC20} from "../mock/MockERC20.t.sol";

/// @title Allocation Security Tests
/// @notice Penetration tests for share inflation attacks, rounding exploits, and other security vectors
contract AllocationSecurityTest is BasicSetup {
    Allocation allocation;
    VenueRegistry venueRegistry;
    MockVenueValidator venueValidator;
    MockVenue mockVenue;

    TestSmartAccount masterSubaccount;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;

    uint constant TOKEN_CAP = 1_000_000e6;
    uint constant MAX_PUPPET_LIST = 10;
    uint constant GAS_LIMIT = 500_000;

    bytes32 constant SUBACCOUNT_NAME = bytes32("main");
    bytes32 venueKey;
    bytes32 matchingKey;

    uint256 ownerPrivateKey = 0x1234;
    uint256 signerPrivateKey = 0x5678;
    address owner;
    address sessionSigner;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        sessionSigner = vm.addr(signerPrivateKey);

        venueRegistry = new VenueRegistry(dictator);
        allocation = new Allocation(
            dictator,
            Allocation.Config({
                venueRegistry: venueRegistry,
                masterHook: address(1),
                maxPuppetList: MAX_PUPPET_LIST,
                transferOutGasLimit: GAS_LIMIT
            })
        );

        dictator.setPermission(allocation, allocation.setCodeHash.selector, users.owner);
        allocation.setCodeHash(keccak256(type(TestSmartAccount).runtimeCode), true);

        venueValidator = new MockVenueValidator();
        mockVenue = new MockVenue();
        mockVenue.setToken(usdc);

        venueKey = keccak256("mock_venue");

        dictator.setPermission(allocation, allocation.registerMasterSubaccount.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeAllocate.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeWithdraw.selector, users.owner);
        dictator.setPermission(allocation, allocation.setTokenCap.selector, users.owner);
        dictator.setPermission(venueRegistry, venueRegistry.setVenue.selector, users.owner);

        address[] memory entrypoints = new address[](1);
        entrypoints[0] = address(mockVenue);
        venueRegistry.setVenue(venueKey, venueValidator, entrypoints);

        allocation.setTokenCap(usdc, TOKEN_CAP);

        masterSubaccount = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        masterSubaccount.installModule(MODULE_TYPE_HOOK, address(1), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        usdc.mint(address(masterSubaccount), 500e6);
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        matchingKey = keccak256(abi.encode(address(usdc), address(masterSubaccount)));
    }

    function _signIntent(Allocation.CallIntent memory intent, uint256 privateKey) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(
            allocation.CALL_INTENT_TYPEHASH(),
            intent.account,
            intent.subaccount,
            intent.token,
            intent.amount,
            intent.deadline,
            intent.nonce
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Puppet Allocation"),
            keccak256("1"),
            block.chainid,
            address(allocation)
        ));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // ============================================================================
    // Share Inflation Attack Tests
    // ============================================================================

    /// @notice Classic inflation attack: attacker deposits 1 wei, donates to inflate price
    /// Expected: Contract protects victim by reverting on zero shares
    function testExploit_ClassicInflationAttack_RevertsZeroShares() public {
        // Setup: use owner as attacker with a new subaccount
        TestSmartAccount attackerSub = new TestSmartAccount();
        attackerSub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        attackerSub.installModule(MODULE_TYPE_HOOK, address(1), "");

        // Attacker deposits just 1 wei
        usdc.mint(address(attackerSub), 1);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(attackerSub)),
            usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(attackerSub)));

        // Attacker gets 1 share for 1 wei (1:1 ratio)
        uint256 attackerShares = allocation.shareBalanceMap(key, owner);
        assertEq(attackerShares, 1, "Attacker should get 1 share for 1 wei");

        // Attacker donates 1000 USDC directly to inflate share price
        usdc.mint(address(attackerSub), 1000e6);

        // Now share price is inflated: (1000e6 + 1) assets / 1 share
        uint256 inflatedPrice = allocation.getSharePrice(key, usdc.balanceOf(address(attackerSub)));
        assertGt(inflatedPrice, 1e30, "Price is inflated after donation");

        // Victim tries to deposit 999 USDC - this would result in 0 shares
        usdc.mint(address(puppet1), 999e6);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(attackerSub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 999e6;

        uint256 victimBalanceBefore = usdc.balanceOf(address(puppet1));

        // Contract protects victim by reverting - can't steal with zero shares
        vm.expectRevert(Error.Allocation__ZeroShares.selector);
        allocation.executeAllocate(intent, sig, puppets, amounts);

        // Victim's funds are safe - balance unchanged
        assertEq(usdc.balanceOf(address(puppet1)), victimBalanceBefore, "Victim funds protected");
    }

    /// @notice Inflation attack fails if victim deposits enough to get shares
    function testExploit_InflationAttackMitigatedWithLargerDeposit() public {
        TestSmartAccount attackerSub = new TestSmartAccount();
        attackerSub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        attackerSub.installModule(MODULE_TYPE_HOOK, address(1), "");

        // Attacker deposits 1 wei
        usdc.mint(address(attackerSub), 1);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(attackerSub)),
            usdc);


        bytes32 key = keccak256(abi.encode(address(usdc), address(attackerSub)));

        // Attacker donates 1000 USDC
        usdc.mint(address(attackerSub), 1000e6);

        // Victim deposits MORE than the inflated share price - gets at least 1 share
        usdc.mint(address(puppet1), 1001e6);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(attackerSub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1001e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint256 victimShares = allocation.shareBalanceMap(key, address(puppet1));
        assertGt(victimShares, 0, "Victim gets shares with larger deposit");

        // Calculate each party's value
        uint256 totalShares = allocation.totalSharesMap(key);
        uint256 totalAssets = usdc.balanceOf(address(attackerSub));
        uint256 attackerShares = allocation.shareBalanceMap(key, owner);

        uint256 attackerValue = (totalAssets * attackerShares) / totalShares;
        uint256 victimValue = (totalAssets * victimShares) / totalShares;

        // Attacker donated 1000e6, so their value includes donation
        // But they can't steal from victim - victim gets proportional share
        assertApproxEqRel(attackerValue, 1000e6, 0.01e18, "Attacker gets ~donation back");
        assertApproxEqRel(victimValue, 1001e6, 0.01e18, "Victim gets ~deposit value");
    }

    // ============================================================================
    // Share Price Manipulation Tests
    // ============================================================================

    /// @notice Test that empty route starts fresh with 1:1 pricing
    function testExploit_EmptyRouteHasOneToOnePrice() public {
        // Share price for non-existent route should be 1:1
        bytes32 emptyKey = keccak256("nonexistent");
        uint256 price = allocation.getSharePrice(emptyKey, 0);
        assertEq(price, 1e30, "Empty route should have 1:1 share price");

        // Even with assets passed, empty shares means 1:1
        price = allocation.getSharePrice(emptyKey, 1000e6);
        assertEq(price, 1e30, "Empty route ignores passed assets for price");
    }

    /// @notice Test first depositor always gets 1:1 shares regardless of token decimals
    function testExploit_FirstDepositorGetsOneToOne_6Decimals() public {
        // USDC has 6 decimals
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 1000e6);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(sub)),
            usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));
        uint256 shares = allocation.shareBalanceMap(key, owner);

        // First depositor: shares = deposit amount (1:1)
        assertEq(shares, 1000e6, "First depositor gets 1:1 shares");
    }

    /// @notice Test first depositor with 18 decimal token
    function testExploit_FirstDepositorGetsOneToOne_18Decimals() public {
        // Create 18 decimal token
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        allocation.setTokenCap(IERC20(address(weth)), type(uint256).max);

        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        weth.mint(address(sub), 1 ether);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(sub)),
            IERC20(address(weth)));

        bytes32 key = keccak256(abi.encode(address(weth), address(sub)));

        uint256 shares = allocation.shareBalanceMap(key, owner);

        // First depositor: shares = deposit amount (1:1)
        assertEq(shares, 1 ether, "First depositor gets 1:1 shares for 18 decimal token");
    }

    /// @notice Test that tiny first deposit doesn't create exploitable state
    function testExploit_TinyFirstDeposit() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        // Minimum possible deposit: 1 wei
        usdc.mint(address(sub), 1);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(sub)),
            usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // First depositor gets 1 share
        assertEq(allocation.shareBalanceMap(key, owner), 1, "Gets 1 share for 1 wei");
        assertEq(allocation.totalSharesMap(key), 1, "Total shares is 1");

        // Share price is now 1:1
        uint256 price = allocation.getSharePrice(key, 1);
        assertEq(price, 1e30, "Share price is 1:1");
    }

    // ============================================================================
    // Donation Attack Tests
    // ============================================================================

    /// @notice Test donation to existing route doesn't unfairly benefit anyone
    function testExploit_DonationToExistingRoute() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 1000e6);

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(sub)),
            usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        uint256 ownerShares = allocation.shareBalanceMap(key, owner);
        assertEq(ownerShares, 1000e6, "Owner has 1000e6 shares");

        // External party donates to the subaccount
        usdc.mint(address(sub), 500e6);

        // Share price increases proportionally
        uint256 newPrice = allocation.getSharePrice(key, usdc.balanceOf(address(sub)));
        // Price = 1500e6 / 1000e6 * 1e30 = 1.5e30
        assertEq(newPrice, 15e29, "Price reflects donation");

        // Owner's shares are now worth more
        uint256 ownerValue = (usdc.balanceOf(address(sub)) * ownerShares) / allocation.totalSharesMap(key);
        assertEq(ownerValue, 1500e6, "Owner benefits from donation");

        // New depositor pays fair price
        usdc.mint(address(puppet1), 1500e6);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // Puppet gets 1000e6 shares (1500e6 / 1.5 price)
        uint256 puppetShares = allocation.shareBalanceMap(key, address(puppet1));
        assertEq(puppetShares, 1000e6, "Puppet gets fair shares at higher price");

        // Total assets now 3000e6, total shares 2000e6
        // Each party has 50% ownership
        uint256 totalAssets = usdc.balanceOf(address(sub));
        uint256 totalShares = allocation.totalSharesMap(key);

        assertEq((totalAssets * ownerShares) / totalShares, 1500e6, "Owner has half");
        assertEq((totalAssets * puppetShares) / totalShares, 1500e6, "Puppet has half");
    }

    // ============================================================================
    // Rounding Attack Tests
    // ============================================================================

    /// @notice Test rounding doesn't create exploitable edge cases
    function testExploit_RoundingEdgeCases() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 3);  // 3 wei

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(sub)),
            usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // Owner has 3 shares for 3 wei
        assertEq(allocation.shareBalanceMap(key, owner), 3, "Owner has 3 shares");

        // Try to deposit 1 wei - should get at least 1 share due to 1:1 or fair rounding
        usdc.mint(address(puppet1), 1);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // With 4 assets and 4 shares total, price is 1:1
        // Puppet should get 1 share for 1 wei
        uint256 puppetShares = allocation.shareBalanceMap(key, address(puppet1));
        assertEq(puppetShares, 1, "Puppet gets 1 share for 1 wei deposit");
    }

    // ============================================================================
    // Front-Running Attack Tests
    // ============================================================================

    /// @notice Test that attacker can't front-run first deposit to steal funds
    function testExploit_FrontRunFirstDeposit() public {
        // Scenario: Victim is about to create subaccount with 1000 USDC
        // Attacker front-runs with their own subaccount (can't affect victim's route)

        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");

        // Each route (subaccount) is independent
        TestSmartAccount attackerSub = new TestSmartAccount();
        TestSmartAccount victimSub = new TestSmartAccount();

        attackerSub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        attackerSub.installModule(MODULE_TYPE_HOOK, address(1), "");
        victimSub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        victimSub.installModule(MODULE_TYPE_HOOK, address(1), "");

        usdc.mint(address(attackerSub), 1);
        usdc.mint(address(victimSub), 1000e6);

        dictator.setPermission(allocation, allocation.registerMasterSubaccount.selector, attacker);
        dictator.setPermission(allocation, allocation.registerMasterSubaccount.selector, victim);
        vm.stopPrank();

        // Attacker creates their route
        vm.prank(attacker);
        allocation.registerMasterSubaccount(
            attacker,
            attacker,
            IERC7579Account(address(attackerSub)),
            usdc);

        // Victim creates their route - completely independent
        vm.prank(victim);
        allocation.registerMasterSubaccount(
            victim,
            victim,
            IERC7579Account(address(victimSub)),
            usdc);

        bytes32 victimKey = keccak256(abi.encode(address(usdc), address(victimSub)));

        // Victim gets full 1:1 shares on their independent route
        uint256 victimShares = allocation.shareBalanceMap(victimKey, victim);
        assertEq(victimShares, 1000e6, "Victim gets 1:1 shares on their route");
    }
}
