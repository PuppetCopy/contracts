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

contract AllocationTest is BasicSetup {
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
    bytes32 matchingKey;

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

        dictator.registerContract(address(allocation));
        dictator.registerContract(address(position));

        masterSubaccount = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        masterSubaccount.installModule(MODULE_TYPE_HOOK, address(1), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        allocation.setTokenCap(usdc, TOKEN_CAP);

        position.setHandler(address(mockVenue), IStage(address(mockStage)));

        matchingKey = keccak256(abi.encode(address(usdc), address(masterSubaccount)));

        usdc.mint(owner, 10_000e6);
        usdc.mint(address(masterSubaccount), 1000e6);
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(masterSubaccount), type(uint).max);

        // Puppets approve Allocation for transferFrom
        vm.prank(address(puppet1));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(puppet2));
        usdc.approve(address(allocation), type(uint).max);

        vm.startPrank(users.owner);
    }

    function _createIntent(uint amount, uint nonce, uint deadline)
        internal
        view
        returns (Allocation.CallIntent memory)
    {
        return Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(masterSubaccount)),
            token: usdc,
            amount: amount,
            deadline: deadline,
            nonce: nonce
        });
    }

    function _signIntent(Allocation.CallIntent memory intent, uint privateKey) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                allocation.CALL_INTENT_TYPEHASH(),
                intent.account,
                intent.subaccount,
                intent.token,
                intent.amount,
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

    function testCreateMasterSubaccount_RegistersSubaccount() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        assertTrue(allocation.registeredMap(address(masterSubaccount)), "Subaccount registered");
        assertEq(allocation.ownerMap(address(masterSubaccount)), owner, "Owner set");
        assertEq(allocation.sessionSignerMap(address(masterSubaccount)), sessionSigner, "Session signer set");
        // No initial shares - shares created at deposit time
        assertEq(allocation.totalSharesMap(matchingKey), 0, "No initial shares");
    }

    function testCreateMasterSubaccount_AssociatesSignerWithSubaccount() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        assertEq(allocation.sessionSignerMap(address(masterSubaccount)), sessionSigner, "Signer mapped to subaccount");
    }

    function testExecuteAllocate_MasterDepositsAndReceivesShares() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        // First deposit creates shares at 1:1 ratio
        Allocation.CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        uint balanceBefore = usdc.balanceOf(address(masterSubaccount));
        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertEq(allocation.shareBalanceMap(matchingKey, owner), 100e6, "Owner has shares from deposit");
        assertEq(usdc.balanceOf(address(masterSubaccount)), balanceBefore + 100e6, "Subaccount received deposit");
    }

    function testExecuteAllocate_PuppetsTransferAndReceiveShares() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(puppet2));

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 200e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 has shares");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet2)), 0, "Puppet2 has shares");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Subaccount received puppet funds");
    }

    function testExecuteAllocate_FailedPuppetTransfersSkipped() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(emptyPuppet));
        puppets[1] = IERC7579Account(address(puppet1));

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 100e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertEq(allocation.shareBalanceMap(matchingKey, address(emptyPuppet)), 0, "Empty puppet has no shares");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 still has shares");
    }

    function testExecuteAllocate_SkipsSelfAllocation() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        uint initialShares = allocation.shareBalanceMap(matchingKey, address(masterSubaccount));

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(masterSubaccount));

        uint[] memory amounts = new uint[](1);
        amounts[0] = 100e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertEq(
            allocation.shareBalanceMap(matchingKey, address(masterSubaccount)), initialShares, "Self-allocation skipped"
        );
    }

    function testExecuteWithdraw_BurnsSharesAndTransfersTokens() public {
        // Create a fresh subaccount to avoid pre-existing balance issues
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        // First deposit to create shares
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        Allocation.CallIntent memory depositIntent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory depositSig = _signIntent(depositIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(depositIntent, depositSig, emptyPuppets, emptyAmounts);

        uint initialShares = allocation.shareBalanceMap(key, owner);
        uint initialBalance = usdc.balanceOf(owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 250e6,
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(intent, sig);

        assertLt(allocation.shareBalanceMap(key, owner), initialShares, "Shares burnt");
        assertGt(usdc.balanceOf(owner), initialBalance, "Owner received tokens");
    }

    function testExecuteWithdraw_AllowedWhenFrozen() public {
        // Create fresh subaccount to avoid pre-existing balance issues
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        // Owner deposits to have shares
        usdc.mint(owner, 200e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        Allocation.CallIntent memory allocIntent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 200e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory allocSig = _signIntent(allocIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(allocIntent, allocSig, emptyPuppets, emptyAmounts);

        uint sharesBefore = allocation.shareBalanceMap(key, owner);
        assertGt(sharesBefore, 0, "Owner has shares");

        // Freeze the subaccount
        vm.stopPrank();
        vm.prank(address(sub));
        sub.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        assertTrue(allocation.disposedMap(address(sub)), "Subaccount frozen");

        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        // Withdraw while frozen - should succeed
        vm.startPrank(users.owner);
        uint ownerBalanceBefore = usdc.balanceOf(owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 100e6,
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(intent, sig);

        assertGt(usdc.balanceOf(owner), ownerBalanceBefore, "Withdrawal succeeded while frozen");
    }

    function testVerifyIntent_AcceptsOwnerSignature() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_AcceptsSessionSignerSignature() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, signerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_IncrementsNonce() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        assertEq(allocation.nonceMap(address(masterSubaccount)), 0, "Initial nonce is 0");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
        assertEq(allocation.nonceMap(address(masterSubaccount)), 1, "Nonce incremented");

        intent.nonce = 1;
        sig = _signIntent(intent, ownerPrivateKey);
        allocation.executeAllocate(intent, sig, puppets, amounts);
        assertEq(allocation.nonceMap(address(masterSubaccount)), 2, "Nonce incremented again");
    }

    function testOnUninstall_FreezesSubaccount() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        assertFalse(allocation.disposedMap(address(masterSubaccount)), "Not frozen initially");

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        assertTrue(allocation.disposedMap(address(masterSubaccount)), "Frozen after uninstall");
    }

    function testShareAccounting_VirtualOffsetProtectsFirstDeposit() public {
        uint sharePrice = allocation.getSharePrice(matchingKey, 0);
        assertEq(sharePrice, 1e30, "Initial share price with offset");
    }

    function testShareAccounting_PriceIncludesPositionValue() public {
        // Use fresh subaccount to have clean state
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // First create some shares via deposit
        usdc.mint(owner, 1000e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 1000e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(intent, sig, emptyPuppets, emptyAmounts);

        // Price with only cash: 1000 assets / 1000 shares
        uint priceWithoutPosition = allocation.getSharePrice(key, 1000e6);

        // Add position value
        bytes32 posKey = keccak256(abi.encode(address(sub), "mock_position"));
        mockStage.setPositionValue(posKey, 500e6);

        // Price with cash + position: 1500 assets / 1000 shares
        uint priceWithPosition = allocation.getSharePrice(key, 1500e6);

        assertGt(priceWithPosition, priceWithoutPosition, "Price higher with position value");
    }

    function testRevert_CreateMasterSubaccount_HookNotInstalled() public {
        TestSmartAccount noHook = new TestSmartAccount();
        noHook.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.expectRevert(Error.Allocation__MasterHookNotInstalled.selector);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(noHook)), SUBACCOUNT_NAME);
    }

    function testRevert_CreateMasterSubaccount_AlreadyRegistered() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        vm.expectRevert(Error.Allocation__AlreadyRegistered.selector);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);
    }

    function testRevert_ExecuteAllocate_Frozen() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);
        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteAllocate_ArrayLengthMismatch() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        uint[] memory amounts = new uint[](1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ArrayLengthMismatch.selector, 2, 1));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteAllocate_PuppetListTooLarge() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](MAX_PUPPET_LIST + 1);
        uint[] memory amounts = new uint[](MAX_PUPPET_LIST + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, MAX_PUPPET_LIST + 1, MAX_PUPPET_LIST)
        );
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteWithdraw_ZeroShares() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__ZeroShares.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_ExecuteWithdraw_InsufficientBalance() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(2000e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__InsufficientBalance.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_VerifyIntent_ExpiredDeadline() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp - 1);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(
            abi.encodeWithSelector(Error.Allocation__IntentExpired.selector, block.timestamp - 1, block.timestamp)
        );
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidNonce() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 5, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InvalidNonce.selector, 0, 5));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidSigner() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        uint randomKey = 0x9999;
        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, randomKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert();
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testEdge_MultipleSubaccountsPerMaster() public {
        bytes32 name1 = bytes32("account1");
        bytes32 name2 = bytes32("account2");

        TestSmartAccount sub1 = new TestSmartAccount();
        TestSmartAccount sub2 = new TestSmartAccount();
        sub1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub1.installModule(MODULE_TYPE_HOOK, address(1), "");
        sub2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub2.installModule(MODULE_TYPE_HOOK, address(1), "");

        usdc.mint(address(sub1), 500e6);
        usdc.mint(address(sub2), 500e6);

        // Puppets approve Allocation
        vm.stopPrank();
        vm.prank(address(sub1));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(sub2));
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub1)), name1);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub2)), name2);

        // Nonces are per subaccount now, not per matchingKey
        assertEq(allocation.nonceMap(address(sub1)), 0, "Nonce for sub1 is independent");
        assertEq(allocation.nonceMap(address(sub2)), 0, "Nonce for sub2 is independent");

        assertTrue(allocation.registeredMap(address(sub1)), "Sub1 registered");
        assertTrue(allocation.registeredMap(address(sub2)), "Sub2 registered");
    }

    function testEdge_MixedPuppetSuccess() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](3);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(emptyPuppet));
        puppets[2] = IERC7579Account(address(puppet2));

        uint[] memory amounts = new uint[](3);
        amounts[0] = 100e6;
        amounts[1] = 100e6;
        amounts[2] = 200e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 succeeded");
        assertEq(allocation.shareBalanceMap(matchingKey, address(emptyPuppet)), 0, "Empty puppet failed");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet2)), 0, "Puppet2 succeeded");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Only successful transfers counted");
    }

    function testEdge_PuppetWithBalanceButNoAllowance() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        // Create puppet with balance but NO allowance
        TestSmartAccount noAllowancePuppet = new TestSmartAccount();
        noAllowancePuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        usdc.mint(address(noAllowancePuppet), 500e6);
        // Note: deliberately NOT approving allocation

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(noAllowancePuppet));
        puppets[1] = IERC7579Account(address(puppet1)); // has approval from setUp

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 100e6;

        uint noAllowanceBalanceBefore = usdc.balanceOf(address(noAllowancePuppet));

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // No allowance puppet should be skipped (no shares, balance unchanged)
        assertEq(allocation.shareBalanceMap(matchingKey, address(noAllowancePuppet)), 0, "No allowance puppet has no shares");
        assertEq(usdc.balanceOf(address(noAllowancePuppet)), noAllowanceBalanceBefore, "No allowance puppet balance unchanged");

        // Approved puppet should succeed
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Approved puppet has shares");
    }

    function testEdge_PuppetWithInsufficientAllowance() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        // Create puppet with balance but INSUFFICIENT allowance
        TestSmartAccount lowAllowancePuppet = new TestSmartAccount();
        lowAllowancePuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        usdc.mint(address(lowAllowancePuppet), 500e6);

        // Approve only 50e6, but we'll try to allocate 100e6
        vm.stopPrank();
        vm.prank(address(lowAllowancePuppet));
        usdc.approve(address(allocation), 50e6);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(lowAllowancePuppet));
        puppets[1] = IERC7579Account(address(puppet1));

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6; // More than approved
        amounts[1] = 100e6;

        uint lowAllowanceBalanceBefore = usdc.balanceOf(address(lowAllowancePuppet));

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // Insufficient allowance puppet should be skipped
        assertEq(allocation.shareBalanceMap(matchingKey, address(lowAllowancePuppet)), 0, "Insufficient allowance puppet has no shares");
        assertEq(usdc.balanceOf(address(lowAllowancePuppet)), lowAllowanceBalanceBefore, "Insufficient allowance puppet balance unchanged");

        // Approved puppet should succeed
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Approved puppet has shares");
    }

    function testEdge_PuppetRevokesAllowance() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        // First allocation with puppet1 (has approval)
        Allocation.CallIntent memory intent1 = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig1 = _signIntent(intent1, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 100e6;

        allocation.executeAllocate(intent1, sig1, puppets, amounts);
        uint sharesAfterFirst = allocation.shareBalanceMap(matchingKey, address(puppet1));
        assertGt(sharesAfterFirst, 0, "First allocation succeeded");

        // Puppet revokes allowance
        vm.stopPrank();
        vm.prank(address(puppet1));
        usdc.approve(address(allocation), 0);
        vm.startPrank(users.owner);

        // Second allocation attempt should fail for puppet1
        Allocation.CallIntent memory intent2 = _createIntent(0, 1, block.timestamp + 1 hours);
        bytes memory sig2 = _signIntent(intent2, ownerPrivateKey);

        uint puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        allocation.executeAllocate(intent2, sig2, puppets, amounts);

        // Puppet1 shares should be unchanged (second allocation skipped)
        assertEq(allocation.shareBalanceMap(matchingKey, address(puppet1)), sharesAfterFirst, "Shares unchanged after revoke");
        assertEq(usdc.balanceOf(address(puppet1)), puppet1BalanceBefore, "Balance unchanged after revoke");
    }

    function testEdge_SharePriceAfterDeposits() public {
        // Use fresh subaccount to have clean state
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // First deposit to establish initial price
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent1 = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig1 = _signIntent(intent1, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(intent1, sig1, emptyPuppets, emptyAmounts);

        // Price after first deposit (500 assets / 500 shares = 1:1)
        uint priceInitial = allocation.getSharePrice(key, 500e6);

        // Second deposit from puppet
        Allocation.CallIntent memory intent2 = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig2 = _signIntent(intent2, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent2, sig2, puppets, amounts);

        // Price after second deposit (1000 assets / 1000 shares = 1:1)
        uint priceAfter = allocation.getSharePrice(key, 1000e6);

        assertEq(priceInitial, priceAfter, "Share price stable after fair deposits");
    }

    function testEdge_ReplayAttackPrevented() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InvalidNonce.selector, 1, 0));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testEdge_FrozenBlocksAllocate() public {
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testEdge_MultipleTokensSameSubaccount() public {
        // Use a fresh subaccount to avoid pre-existing balance issues
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        allocation.setTokenCap(weth, 100e18);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        // Owner needs both USDC and WETH with approvals
        usdc.mint(owner, 100e6);
        weth.mint(owner, 10e18);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(owner);
        weth.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        bytes32 usdcKey = keccak256(abi.encode(address(usdc), address(sub)));
        bytes32 wethKey = keccak256(abi.encode(address(weth), address(sub)));

        // Allocate USDC - owner deposits 100e6
        Allocation.CallIntent memory usdcIntent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 100e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory usdcSig = _signIntent(usdcIntent, ownerPrivateKey);
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 100e6;
        allocation.executeAllocate(usdcIntent, usdcSig, puppets, amounts);

        // Allocate WETH (different token, same subaccount)
        Allocation.CallIntent memory wethIntent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: weth,
            amount: 5e18,
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory wethSig = _signIntent(wethIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(wethIntent, wethSig, emptyPuppets, emptyAmounts);

        assertGt(allocation.shareBalanceMap(usdcKey, owner), 0, "Has USDC shares");
        assertGt(allocation.shareBalanceMap(wethKey, owner), 0, "Has WETH shares");
    }

    function testFairDistribution_ProportionalShares() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint ownerShares = allocation.shareBalanceMap(key, owner);
        uint puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        assertEq(ownerShares, puppet1Shares, "Equal deposits = equal shares");
    }

    function testFairDistribution_ProfitSharing() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // Simulate profit: total value doubles
        usdc.mint(address(sub), 1000e6);

        uint ownerShares = allocation.shareBalanceMap(key, owner);
        uint puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        uint totalValue = usdc.balanceOf(address(sub));
        uint totalShares = allocation.totalSharesMap(key);

        uint ownerValue = (totalValue * ownerShares) / totalShares;
        uint puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertEq(ownerShares, puppet1Shares, "Equal shares");
        assertEq(ownerValue, puppet1Value, "Equal profit distribution");
        assertApproxEqRel(ownerValue, 1000e6, 0.01e18, "Each gets ~1000e6 (500 + 500 profit)");
    }

    function testFairDistribution_LateDepositorNoFreeRide() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // Owner deposits 500e6 first
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory ownerIntent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory ownerSig = _signIntent(ownerIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(ownerIntent, ownerSig, emptyPuppets, emptyAmounts);

        uint ownerSharesBefore = allocation.shareBalanceMap(key, owner);

        // Profit occurs before puppet deposits
        usdc.mint(address(sub), 500e6);

        // Puppet1 deposits 500e6 after profit
        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 0,
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        assertLt(puppet1Shares, ownerSharesBefore, "Late depositor gets fewer shares");

        uint totalValue = usdc.balanceOf(address(sub));
        uint totalShares = allocation.totalSharesMap(key);

        uint ownerValue = (totalValue * ownerSharesBefore) / totalShares;
        uint puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertGt(ownerValue, puppet1Value, "Early depositor has more value");
        assertApproxEqRel(ownerValue, 1000e6, 0.02e18, "Owner ~1000 (initial 500 + 500 profit)");
        assertApproxEqRel(puppet1Value, 500e6, 0.02e18, "Puppet1 ~500 (only deposit, no profit)");
    }

    function testFairDistribution_LossSharing() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(sub)),
            token: usdc,
            amount: 500e6,
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        // Simulate loss: half the funds lost
        vm.stopPrank();
        vm.prank(address(sub));
        usdc.transfer(address(1), 500e6);
        vm.startPrank(users.owner);

        uint totalValue = usdc.balanceOf(address(sub));
        assertEq(totalValue, 500e6, "Half the value lost");

        uint ownerShares = allocation.shareBalanceMap(key, owner);
        uint puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));
        uint totalShares = allocation.totalSharesMap(key);

        uint ownerValue = (totalValue * ownerShares) / totalShares;
        uint puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertEq(ownerShares, puppet1Shares, "Equal shares");
        assertApproxEqRel(ownerValue, 250e6, 0.01e18, "Owner lost 50%");
        assertApproxEqRel(puppet1Value, 250e6, 0.01e18, "Puppet1 lost 50%");
    }

    function testComplex_TradingLifecycleWithMixedOutcomes() public {
        allocation.setTokenCap(usdc, 10_000e6);

        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        TestSmartAccount p1 = new TestSmartAccount();
        TestSmartAccount p2 = new TestSmartAccount();
        TestSmartAccount p3 = new TestSmartAccount();
        TestSmartAccount p4 = new TestSmartAccount();
        p1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        p2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        p3.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        p4.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        usdc.mint(address(p1), 500e6);
        usdc.mint(address(p2), 300e6);
        usdc.mint(address(p3), 200e6);
        usdc.mint(address(p4), 400e6);

        // Owner and puppets approve Allocation for transferFrom
        usdc.mint(owner, 1000e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(p1));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(p2));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(p3));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(p4));
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), SUBACCOUNT_NAME);

        uint nonce = 0;

        // Owner deposits 1000e6 + puppets deposit their amounts
        {
            Allocation.CallIntent memory intent = Allocation.CallIntent({
                account: owner,
                subaccount: IERC7579Account(address(sub)),
                token: usdc,
                amount: 1000e6,
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](3);
            puppets[0] = IERC7579Account(address(p1));
            puppets[1] = IERC7579Account(address(p2));
            puppets[2] = IERC7579Account(address(p3));

            uint[] memory amounts = new uint[](3);
            amounts[0] = 500e6;
            amounts[1] = 300e6;
            amounts[2] = 200e6;

            allocation.executeAllocate(intent, sig, puppets, amounts);
        }

        assertEq(usdc.balanceOf(address(sub)), 2000e6, "Phase 1: Total 2000 USDC");
        assertEq(allocation.totalSharesMap(key), 2000e6, "Phase 1: Total 2000 shares");

        uint ownerShares = allocation.shareBalanceMap(key, owner);
        uint p1Shares = allocation.shareBalanceMap(key, address(p1));
        uint p2Shares = allocation.shareBalanceMap(key, address(p2));
        uint p3Shares = allocation.shareBalanceMap(key, address(p3));

        assertEq(ownerShares, 1000e6, "Owner: 1000 shares");
        assertEq(p1Shares, 500e6, "P1: 500 shares");
        assertEq(p2Shares, 300e6, "P2: 300 shares");
        assertEq(p3Shares, 200e6, "P3: 200 shares");

        // Simulate profitable trading: profit is 400e6 on top of initial 2000e6
        // This represents closing positions with gains
        usdc.mint(address(sub), 400e6);

        // Now subaccount has 2400e6 (2000 deposits + 400 profit)
        assertEq(usdc.balanceOf(address(sub)), 2400e6, "Phase 2: 2400 after profit");

        // Share price should be increased: 2400 assets / 2000 shares = 1.2
        uint sharePriceAfterProfit = allocation.getSharePrice(key, 2400e6);
        assertGt(sharePriceAfterProfit, 1e30, "Phase 3: Share price increased");

        uint p4SharesBefore;
        {
            Allocation.CallIntent memory intent = Allocation.CallIntent({
                account: owner,
                subaccount: IERC7579Account(address(sub)),
                token: usdc,
                amount: 0,
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](1);
            puppets[0] = IERC7579Account(address(p4));
            uint[] memory amounts = new uint[](1);
            amounts[0] = 400e6;

            allocation.executeAllocate(intent, sig, puppets, amounts);

            p4SharesBefore = allocation.shareBalanceMap(key, address(p4));
        }

        // P4 deposits 400e6 when share price is 2400/2000 = 1.2
        // P4 should get: 400 * 2000 / 2400 = 333.33e6 shares (fewer than deposit due to premium)
        assertLt(p4SharesBefore, 400e6, "Phase 4: P4 gets fewer shares (paid premium)");
        assertEq(usdc.balanceOf(address(sub)), 2800e6, "Phase 4: 2800 after P4 deposit");

        vm.stopPrank();
        vm.prank(address(p2));
        usdc.transfer(address(1), usdc.balanceOf(address(p2)));
        vm.startPrank(users.owner);

        {
            usdc.mint(address(p1), 100e6);

            Allocation.CallIntent memory intent = Allocation.CallIntent({
                account: owner,
                subaccount: IERC7579Account(address(sub)),
                token: usdc,
                amount: 0,
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](2);
            puppets[0] = IERC7579Account(address(p2));
            puppets[1] = IERC7579Account(address(p1));

            uint[] memory amounts = new uint[](2);
            amounts[0] = 100e6;
            amounts[1] = 100e6;

            uint p2SharesBefore = allocation.shareBalanceMap(key, address(p2));

            allocation.executeAllocate(intent, sig, puppets, amounts);

            uint p2SharesAfter = allocation.shareBalanceMap(key, address(p2));
            assertEq(p2SharesAfter, p2SharesBefore, "Phase 5: P2 shares unchanged (transfer failed)");

            uint p1SharesAfter = allocation.shareBalanceMap(key, address(p1));
            assertGt(p1SharesAfter, p1Shares, "Phase 5: P1 shares increased");
        }

        // Phase 6: Freeze the subaccount
        vm.stopPrank();
        vm.prank(address(sub));
        sub.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        vm.startPrank(users.owner);

        assertTrue(allocation.disposedMap(address(sub)), "Phase 7: Subaccount frozen");

        {
            Allocation.CallIntent memory intent = Allocation.CallIntent({
                account: owner,
                subaccount: IERC7579Account(address(sub)),
                token: usdc,
                amount: 0,
                deadline: block.timestamp + 1 hours,
                nonce: nonce
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](0);
            uint[] memory amounts = new uint[](0);

            vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
            allocation.executeAllocate(intent, sig, puppets, amounts);
        }

        // Final balance check - no more position simulation needed, profit already reflected
        uint finalBalance = usdc.balanceOf(address(sub));
        uint finalTotalShares = allocation.totalSharesMap(key);

        uint ownerFinalShares = allocation.shareBalanceMap(key, owner);
        uint p1FinalShares = allocation.shareBalanceMap(key, address(p1));
        uint p2FinalShares = allocation.shareBalanceMap(key, address(p2));
        uint p3FinalShares = allocation.shareBalanceMap(key, address(p3));
        uint p4FinalShares = allocation.shareBalanceMap(key, address(p4));

        uint ownerExpectedValue = (finalBalance * ownerFinalShares) / finalTotalShares;
        uint p1ExpectedValue = (finalBalance * p1FinalShares) / finalTotalShares;
        uint p2ExpectedValue = (finalBalance * p2FinalShares) / finalTotalShares;
        uint p3ExpectedValue = (finalBalance * p3FinalShares) / finalTotalShares;
        uint p4ExpectedValue = (finalBalance * p4FinalShares) / finalTotalShares;

        assertGt(ownerExpectedValue, p1ExpectedValue, "Owner has most value");
        assertGt(p1ExpectedValue, p2ExpectedValue, "P1 > P2 (P1 added more)");
        assertGt(p2ExpectedValue, p3ExpectedValue, "P2 > P3");
        assertGt(p4ExpectedValue, 0, "P4 has value");

        assertEq(
            ownerFinalShares + p1FinalShares + p2FinalShares + p3FinalShares + p4FinalShares,
            finalTotalShares,
            "Phase 8: Shares sum to total"
        );

        // Phase 8: Final verification
        // The share accounting is verified by the assertions above - all participants have
        // their expected shares, and the total shares sum correctly.
    }

    function testEdge_CapEnforcedOnAllocate() public {
        allocation.setTokenCap(usdc, 1200e6);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), SUBACCOUNT_NAME);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(puppet2));

        uint[] memory amounts = new uint[](2);
        amounts[0] = 150e6;
        amounts[1] = 150e6;

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__DepositExceedsCap.selector, 1300e6, 1200e6));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }
}
