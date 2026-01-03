// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocation} from "src/position/Allocation.sol";
import {Position} from "src/position/Position.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {MockStage, MockVenue} from "../mock/MockStage.t.sol";
import {MockERC20} from "../mock/MockERC20.t.sol";

/// @title Allocation Security Tests
/// @notice Penetration tests for share inflation attacks, rounding exploits, and other security vectors
contract AllocationSecurityTest is BasicSetup {
    Allocation allocation;
    Position position;
    MockStage mockStage;
    MockVenue mockVenue;

    TestSmartAccount masterSubaccount;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;

    uint constant TOKEN_CAP = 1_000_000e6;
    uint constant MAX_PUPPET_LIST = 10;
    uint constant GAS_LIMIT = 500_000;
    bytes32 constant SUBACCOUNT_NAME = bytes32("main");

    bytes32 stageKey;

    uint ownerPrivateKey = 0x1234;
    uint signerPrivateKey = 0x5678;
    address owner;
    address sessionSigner;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        sessionSigner = vm.addr(signerPrivateKey);

        position = new Position(dictator);
        allocation = new Allocation(
            dictator,
            Allocation.Config({
                position: position,
                masterHook: address(1),
                maxPuppetList: MAX_PUPPET_LIST,
                transferOutGasLimit: GAS_LIMIT
            })
        );

        dictator.setPermission(allocation, allocation.setCodeHash.selector, users.owner);
        allocation.setCodeHash(keccak256(type(TestSmartAccount).runtimeCode), true);

        mockStage = new MockStage();
        mockVenue = new MockVenue();
        mockVenue.setToken(usdc);

        stageKey = keccak256("mock_stage");

        dictator.setPermission(allocation, allocation.registerMasterSubaccount.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeAllocate.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeWithdraw.selector, users.owner);
        dictator.setPermission(allocation, allocation.setTokenCap.selector, users.owner);
        dictator.setPermission(position, position.setHandler.selector, users.owner);

        position.setHandler(address(mockVenue), IStage(address(mockStage)));

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

        // Puppets approve Allocation for transferFrom
        vm.stopPrank();
        vm.prank(address(puppet1));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(puppet2));
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);
    }

    function _signIntent(Allocation.CallIntent memory intent, uint privateKey) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                allocation.CALL_INTENT_TYPEHASH(),
                intent.account,
                intent.subaccount,
                intent.token,
                intent.amount,
                intent.triggerNetValue,
                intent.acceptableNetValue,
                intent.positionParamsHash,
                intent.deadline,
                intent.nonce
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Allocation"),
                keccak256("1"),
                block.chainid,
                address(allocation)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _emptyPositionParams() internal pure returns (Allocation.PositionParams memory) {
        return Allocation.PositionParams({
            stages: new IStage[](0),
            positionKeys: new bytes32[][](0)
        });
    }

    function _registerSubaccount(IERC7579Account sub, MockERC20 token) internal {
        // Seed subaccount before registration (required by Allocation)
        token.mint(address(sub), 1);
        allocation.registerMasterSubaccount(owner, sessionSigner, sub, IERC20(address(token)), SUBACCOUNT_NAME);
    }

    // ============================================================================
    // Share Inflation Attack Tests
    // ============================================================================

    /// @notice Classic inflation attack: attacker deposits 1 wei, donates to inflate price
    /// Expected: Contract protects victim by skipping allocations that would result in zero shares
    function testExploit_ClassicInflationAttack_SkipsZeroShares() public {
        // Setup: use owner as attacker with a new subaccount
        TestSmartAccount attackerSub = new TestSmartAccount();
        attackerSub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        attackerSub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(attackerSub, usdc);

        // Attacker makes first deposit of 1 wei
        usdc.mint(owner, 1);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.PositionParams memory emptyParams = _emptyPositionParams();
        Allocation.CallIntent memory attackerIntent = Allocation.CallIntent({
            account: owner,
            subaccount: attackerSub,
            token: usdc,
            amount: 1,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory attackerSig = _signIntent(attackerIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(attackerIntent, attackerSig, emptyPuppets, emptyAmounts, emptyParams);

        // Attacker gets 1 share for 1 wei (1:1 ratio)
        uint attackerShares = allocation.shareBalanceMap(attackerSub, owner);
        assertEq(attackerShares, 1, "Attacker should get 1 share for 1 wei");

        // Attacker donates 1000 USDC directly to inflate share price
        usdc.mint(address(attackerSub), 1000e6);

        // Now share price is inflated: (1000e6 + 1) assets / 1 share
        uint inflatedPrice = allocation.getSharePrice(attackerSub, usdc.balanceOf(address(attackerSub)));
        assertGt(inflatedPrice, 1e30, "Price is inflated after donation");

        // Victim tries to deposit 999 USDC - this would result in 0 shares
        // Mint enough for victim to attempt the deposit
        usdc.mint(address(puppet1), 999e6);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: attackerSub,
            token: usdc,
            amount: 0,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 999e6;

        uint victimBalanceBefore = usdc.balanceOf(address(puppet1));

        // Contract protects victim by skipping dust allocations that would result in 0 shares
        allocation.executeAllocate(intent, sig, puppets, amounts, emptyParams);

        // Victim's funds are safe - balance unchanged (transfer was skipped)
        assertEq(usdc.balanceOf(address(puppet1)), victimBalanceBefore, "Victim funds protected");

        // Victim got 0 shares (allocation was skipped)
        assertEq(allocation.shareBalanceMap(attackerSub, address(puppet1)), 0, "Victim got no shares");
    }

    /// @notice Test that empty route starts fresh with 1:1 pricing
    function testExploit_EmptyRouteHasOneToOnePrice() public {
        // Share price for non-existent subaccount should be 1:1
        IERC7579Account nonexistent = IERC7579Account(address(0x1234));
        uint price = allocation.getSharePrice(nonexistent, 0);
        assertEq(price, 1e30, "Empty route should have 1:1 share price");

        // Even with assets passed, empty shares means 1:1
        price = allocation.getSharePrice(nonexistent, 1000e6);
        assertEq(price, 1e30, "Empty route ignores passed assets for price");
    }

    /// @notice Test first depositor always gets 1:1 shares regardless of token decimals
    function testExploit_FirstDepositorGetsOneToOne_6Decimals() public {
        // USDC has 6 decimals
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // First deposit via executeAllocate
        usdc.mint(owner, 1000e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.PositionParams memory emptyParams = _emptyPositionParams();
        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: sub,
            token: usdc,
            amount: 1000e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(intent, sig, emptyPuppets, emptyAmounts, emptyParams);

        uint shares = allocation.shareBalanceMap(sub, owner);

        // First depositor: shares = deposit amount (1:1)
        assertEq(shares, 1000e6, "First depositor gets 1:1 shares");
    }

    /// @notice Test that tiny first deposit doesn't create exploitable state
    function testExploit_TinyFirstDeposit() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // First deposit of 1 wei
        usdc.mint(owner, 1);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.PositionParams memory emptyParams = _emptyPositionParams();
        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: sub,
            token: usdc,
            amount: 1,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(intent, sig, emptyPuppets, emptyAmounts, emptyParams);

        // First depositor gets 1 share
        assertEq(allocation.shareBalanceMap(sub, owner), 1, "Gets 1 share for 1 wei");
        assertEq(allocation.totalSharesMap(sub), 1, "Total shares is 1");

        // Share price is now 1:1
        uint price = allocation.getSharePrice(sub, 1);
        assertEq(price, 1e30, "Share price is 1:1");
    }
}
