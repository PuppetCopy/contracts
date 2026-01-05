// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {UserRouter} from "src/UserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {PositionParams, CallIntent, SubaccountInfo} from "src/position/interface/ITypes.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {MockStage, MockVenue} from "../mock/MockStage.t.sol";
import {MockERC20} from "../mock/MockERC20.t.sol";

contract AllocateTest is BasicSetup {
    Allocate allocation;
    Match matcher;
    Position position;
    UserRouter userRouter;
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
        matcher = new Match(dictator);
        allocation = new Allocate(
            dictator,
            Allocate.Config({masterHook: address(1), maxPuppetList: MAX_PUPPET_LIST, withdrawGasLimit: GAS_LIMIT})
        );

        dictator.registerContract(address(matcher));
        userRouter = new UserRouter(dictator, UserRouter.Config({allocation: allocation, matcher: matcher, position: position}));
        dictator.setPermission(matcher, matcher.recordThrottle.selector, address(allocation));
        dictator.setPermission(matcher, matcher.setFilter.selector, address(userRouter));
        dictator.setPermission(matcher, matcher.setPolicy.selector, address(userRouter));

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

        usdc.mint(owner, 10_000e6);
        usdc.mint(address(masterSubaccount), 1000e6);
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(masterSubaccount), type(uint).max);

        // Set default policies for puppets (100% allowance, no throttle, far future expiry)
        vm.prank(address(puppet1));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);
        vm.prank(address(puppet2));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);

        vm.startPrank(users.owner);
    }

    PositionParams emptyParams;

    function _createIntent(uint amount, uint nonce, uint deadline)
        internal
        view
        returns (CallIntent memory)
    {
        return CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: amount,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: deadline,
            nonce: nonce
        });
    }

    function _signIntent(CallIntent memory intent, uint privateKey) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                allocation.CALL_INTENT_TYPEHASH(),
                intent.account,
                intent.signer,
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
                keccak256("Puppet Allocate"),
                keccak256("1"),
                block.chainid,
                address(allocation)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _registerSubaccount(IERC7579Account sub, MockERC20 token) internal {
        allocation.registerMasterSubaccount(owner, sessionSigner, sub, IERC20(address(token)), SUBACCOUNT_NAME);
    }

    function _registerMasterSubaccount() internal {
        allocation.registerMasterSubaccount(owner, sessionSigner, masterSubaccount, usdc, SUBACCOUNT_NAME);
    }

    function testCreateMasterSubaccount_RegistersSubaccount() public {
        // masterSubaccount already seeded in setUp
        _registerMasterSubaccount();

        SubaccountInfo memory info = allocation.getSubaccountInfo(masterSubaccount);
        assertTrue(address(info.baseToken) != address(0), "Subaccount registered");
        // No initial shares - shares created at deposit time
        assertEq(allocation.totalSharesMap(masterSubaccount), 0, "No initial shares");
    }

    function testCreateMasterSubaccount_AssociatesSignerWithSubaccount() public {
        _registerMasterSubaccount();

        SubaccountInfo memory info = allocation.getSubaccountInfo(masterSubaccount);
        assertEq(info.signer, sessionSigner, "Signer mapped to subaccount");
    }

    function testExecuteAllocate_MasterDepositsAndReceivesShares() public {
        _registerMasterSubaccount();

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        // First deposit creates shares at 1:1 ratio
        CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        uint balanceBefore = usdc.balanceOf(address(masterSubaccount));
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        assertEq(allocation.shareBalanceMap(masterSubaccount, owner), 100e6, "Owner has shares from deposit");
        assertEq(usdc.balanceOf(address(masterSubaccount)), balanceBefore + 100e6, "Subaccount received deposit");
    }

    function testExecuteAllocate_PuppetsTransferAndReceiveShares() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = puppet1;
        puppets[1] = puppet2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 200e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Puppet1 has shares");
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet2)), 0, "Puppet2 has shares");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Subaccount received puppet funds");
    }

    function testExecuteAllocate_FailedPuppetTransfersSkipped() public {
        _registerMasterSubaccount();

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = emptyPuppet;
        puppets[1] = puppet1;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 100e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        assertEq(allocation.shareBalanceMap(masterSubaccount, address(emptyPuppet)), 0, "Empty puppet has no shares");
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Puppet1 still has shares");
    }

    function testExecuteAllocate_SkipsSelfAllocate() public {
        _registerMasterSubaccount();

        uint initialShares = allocation.shareBalanceMap(masterSubaccount, address(masterSubaccount));

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = masterSubaccount;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 100e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        assertEq(
            allocation.shareBalanceMap(masterSubaccount, address(masterSubaccount)), initialShares, "Self-allocation skipped"
        );
    }

    function testExecuteWithdraw_BurnsSharesAndTransfersTokens() public {
        // Create a fresh subaccount to avoid pre-existing balance issues
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // First deposit to create shares
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory depositIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory depositSig = _signIntent(depositIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(position, matcher, depositIntent, depositSig, emptyPuppets, emptyAmounts, emptyParams);

        uint initialShares = allocation.shareBalanceMap(sub, owner);
        uint initialBalance = usdc.balanceOf(owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 250e6,
            triggerNetValue: 0,
            acceptableNetValue: 0, // floor for withdraw
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(position, intent, sig, emptyParams);

        assertLt(allocation.shareBalanceMap(sub, owner), initialShares, "Shares burnt");
        assertGt(usdc.balanceOf(owner), initialBalance, "Owner received tokens");
    }

    function testExecuteWithdraw_AllowedWhenFrozen() public {
        // Create fresh subaccount to avoid pre-existing balance issues
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // Owner deposits to have shares
        usdc.mint(owner, 200e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory allocIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 200e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory allocSig = _signIntent(allocIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(position, matcher, allocIntent, allocSig, emptyPuppets, emptyAmounts, emptyParams);

        uint sharesBefore = allocation.shareBalanceMap(sub, owner);
        assertGt(sharesBefore, 0, "Owner has shares");

        // Freeze the subaccount
        vm.stopPrank();
        vm.prank(address(sub));
        sub.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        SubaccountInfo memory info = allocation.getSubaccountInfo(sub);
        assertTrue(info.disposed, "Subaccount frozen");

        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        // Withdraw while frozen - should succeed
        vm.startPrank(users.owner);
        uint ownerBalanceBefore = usdc.balanceOf(owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 100e6,
            triggerNetValue: 0,
            acceptableNetValue: 0, // floor for withdraw
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(position, intent, sig, emptyParams);

        assertGt(usdc.balanceOf(owner), ownerBalanceBefore, "Withdrawal succeeded while frozen");
    }

    function testVerifyIntent_AcceptsOwnerSignature() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testVerifyIntent_AcceptsSessionSignerSignatureForAllocate() public {
        _registerMasterSubaccount();

        // Session signer can sign allocate intents
        CallIntent memory intent = CallIntent({
            account: owner,
            signer: sessionSigner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: 0,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, signerPrivateKey);
        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testVerifyIntent_IncrementsNonce() public {
        _registerMasterSubaccount();

        assertEq(allocation.getSubaccountInfo(masterSubaccount).nonce, 0, "Initial nonce is 0");

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
        assertEq(allocation.getSubaccountInfo(masterSubaccount).nonce, 1, "Nonce incremented");

        intent.nonce = 1;
        sig = _signIntent(intent, ownerPrivateKey);
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
        assertEq(allocation.getSubaccountInfo(masterSubaccount).nonce, 2, "Nonce incremented again");
    }

    function testOnUninstall_FreezesSubaccount() public {
        _registerMasterSubaccount();

        assertFalse(allocation.getSubaccountInfo(masterSubaccount).disposed, "Not frozen initially");

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        assertTrue(allocation.getSubaccountInfo(masterSubaccount).disposed, "Frozen after uninstall");
    }

    function testShareAccounting_VirtualOffsetProtectsFirstDeposit() public {
        uint sharePrice = allocation.getSharePrice(masterSubaccount, 0);
        assertEq(sharePrice, 1e30, "Initial share price with offset");
    }

    function testShareAccounting_PriceIncludesPositionValue() public {
        // Use fresh subaccount to have clean state
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // First create some shares via deposit
        usdc.mint(owner, 1000e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
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
        allocation.executeAllocate(position, matcher, intent, sig, emptyPuppets, emptyAmounts, emptyParams);

        // Price with only cash: 1000 assets / 1000 shares
        uint priceWithoutPosition = allocation.getSharePrice(sub, 1000e6);

        // Add position value
        bytes32 posKey = keccak256(abi.encode(address(sub), "mock_position"));
        mockStage.setPositionValue(posKey, 500e6);

        // Price with cash + position: 1500 assets / 1000 shares
        uint priceWithPosition = allocation.getSharePrice(sub, 1500e6);

        assertGt(priceWithPosition, priceWithoutPosition, "Price higher with position value");
    }

    function testRevert_CreateMasterSubaccount_HookNotInstalled() public {
        TestSmartAccount noHook = new TestSmartAccount();
        noHook.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.expectRevert(Error.Allocate__MasterHookNotInstalled.selector);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(noHook)), usdc, SUBACCOUNT_NAME);
    }

    function testRevert_CreateMasterSubaccount_AlreadyRegistered() public {
        _registerMasterSubaccount();

        vm.expectRevert(Error.Allocate__AlreadyRegistered.selector);
        allocation.registerMasterSubaccount(owner, sessionSigner, masterSubaccount, usdc, SUBACCOUNT_NAME);
    }

    function testRevert_ExecuteAllocate_Frozen() public {
        _registerMasterSubaccount();

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);
        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(Error.Allocate__SubaccountFrozen.selector);
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testRevert_ExecuteAllocate_ArrayLengthMismatch() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        uint[] memory amounts = new uint[](1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__ArrayLengthMismatch.selector, 2, 1));
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testRevert_ExecuteAllocate_PuppetListTooLarge() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](MAX_PUPPET_LIST + 1);
        uint[] memory amounts = new uint[](MAX_PUPPET_LIST + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Error.Allocate__PuppetListTooLarge.selector, MAX_PUPPET_LIST + 1, MAX_PUPPET_LIST)
        );
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testRevert_ExecuteWithdraw_ZeroShares() public {
        _registerMasterSubaccount();

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: 0,
            triggerNetValue: 0,
            acceptableNetValue: 0, // floor for withdraw
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocate__ZeroShares.selector);
        allocation.executeWithdraw(position, intent, sig, emptyParams);
    }

    function testRevert_ExecuteWithdraw_InsufficientBalance() public {
        _registerMasterSubaccount();

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: 2000e6,
            triggerNetValue: 0,
            acceptableNetValue: 0, // floor for withdraw
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocate__InsufficientBalance.selector);
        allocation.executeWithdraw(position, intent, sig, emptyParams);
    }

    function testRevert_VerifyIntent_ExpiredDeadline() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp - 1);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(
            abi.encodeWithSelector(Error.Allocate__IntentExpired.selector, block.timestamp - 1, block.timestamp)
        );
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testRevert_VerifyIntent_InvalidNonce() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 5, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__InvalidNonce.selector, 0, 5));
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testRevert_VerifyIntent_InvalidSigner() public {
        _registerMasterSubaccount();

        uint randomKey = 0x9999;
        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, randomKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert();
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
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

        // Puppets approve Allocate
        vm.stopPrank();
        vm.prank(address(sub1));
        usdc.approve(address(allocation), type(uint).max);
        vm.prank(address(sub2));
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        allocation.registerMasterSubaccount(owner, sessionSigner, sub1, usdc, name1);
        allocation.registerMasterSubaccount(owner, sessionSigner, sub2, usdc, name2);

        // Nonces are per subaccount now, not per matchingKey
        assertEq(allocation.getSubaccountInfo(sub1).nonce, 0, "Nonce for sub1 is independent");
        assertEq(allocation.getSubaccountInfo(sub2).nonce, 0, "Nonce for sub2 is independent");

        assertTrue(address(allocation.getSubaccountInfo(sub1).baseToken) != address(0), "Sub1 registered");
        assertTrue(address(allocation.getSubaccountInfo(sub2).baseToken) != address(0), "Sub2 registered");
    }

    function testEdge_MixedPuppetSuccess() public {
        _registerMasterSubaccount();

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](3);
        puppets[0] = puppet1;
        puppets[1] = emptyPuppet;
        puppets[2] = puppet2;

        uint[] memory amounts = new uint[](3);
        amounts[0] = 100e6;
        amounts[1] = 100e6;
        amounts[2] = 200e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Puppet1 succeeded");
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(emptyPuppet)), 0, "Empty puppet failed");
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet2)), 0, "Puppet2 succeeded");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Only successful transfers counted");
    }

    function testEdge_PuppetWithBalanceButNoAllowance() public {
        _registerMasterSubaccount();

        // Create puppet with balance but NO allowance
        TestSmartAccount noAllowancePuppet = new TestSmartAccount();
        noAllowancePuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        usdc.mint(address(noAllowancePuppet), 500e6);
        // Note: deliberately NOT approving allocation

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = noAllowancePuppet;
        puppets[1] = puppet1;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6;
        amounts[1] = 100e6;

        uint noAllowanceBalanceBefore = usdc.balanceOf(address(noAllowancePuppet));

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        // No allowance puppet should be skipped (no shares, balance unchanged)
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(noAllowancePuppet)), 0, "No allowance puppet has no shares");
        assertEq(usdc.balanceOf(address(noAllowancePuppet)), noAllowanceBalanceBefore, "No allowance puppet balance unchanged");

        // Approved puppet should succeed
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Approved puppet has shares");
    }

    function testEdge_PuppetWithInsufficientAllowance() public {
        _registerMasterSubaccount();

        // Create puppet with balance but INSUFFICIENT allowance
        TestSmartAccount lowAllowancePuppet = new TestSmartAccount();
        lowAllowancePuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        usdc.mint(address(lowAllowancePuppet), 500e6);

        // Approve only 50e6, but we'll try to allocate 100e6
        vm.stopPrank();
        vm.prank(address(lowAllowancePuppet));
        usdc.approve(address(allocation), 50e6);
        vm.startPrank(users.owner);

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = lowAllowancePuppet;
        puppets[1] = puppet1;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100e6; // More than approved
        amounts[1] = 100e6;

        uint lowAllowanceBalanceBefore = usdc.balanceOf(address(lowAllowancePuppet));

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        // Insufficient allowance puppet should be skipped
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(lowAllowancePuppet)), 0, "Insufficient allowance puppet has no shares");
        assertEq(usdc.balanceOf(address(lowAllowancePuppet)), lowAllowanceBalanceBefore, "Insufficient allowance puppet balance unchanged");

        // Approved puppet should succeed
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Approved puppet has shares");
    }

    function testEdge_PuppetRevokesAllowance() public {
        _registerMasterSubaccount();

        // First allocation with puppet1 (has approval)
        CallIntent memory intent1 = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig1 = _signIntent(intent1, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 100e6;

        allocation.executeAllocate(position, matcher, intent1, sig1, puppets, amounts, emptyParams);
        uint sharesAfterFirst = allocation.shareBalanceMap(masterSubaccount, address(puppet1));
        assertGt(sharesAfterFirst, 0, "First allocation succeeded");

        // Puppet uninstalls executor - transfers will fail
        vm.stopPrank();
        vm.prank(address(puppet1));
        puppet1.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        vm.startPrank(users.owner);

        // Second allocation attempt should fail for puppet1
        CallIntent memory intent2 = _createIntent(0, 1, block.timestamp + 1 hours);
        bytes memory sig2 = _signIntent(intent2, ownerPrivateKey);

        uint puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        allocation.executeAllocate(position, matcher, intent2, sig2, puppets, amounts, emptyParams);

        // Puppet1 shares should be unchanged (second allocation skipped)
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), sharesAfterFirst, "Shares unchanged after revoke");
        assertEq(usdc.balanceOf(address(puppet1)), puppet1BalanceBefore, "Balance unchanged after revoke");
    }

    function testEdge_SharePriceAfterDeposits() public {
        // Use fresh subaccount to have clean state
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // First deposit to establish initial price
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory intent1 = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig1 = _signIntent(intent1, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(position, matcher, intent1, sig1, emptyPuppets, emptyAmounts, emptyParams);

        // Price after first deposit (500 assets / 500 shares = 1:1)
        uint priceInitial = allocation.getSharePrice(sub, 500e6);

        // Second deposit from puppet
        CallIntent memory intent2 = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 0,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory sig2 = _signIntent(intent2, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(position, matcher, intent2, sig2, puppets, amounts, emptyParams);

        // Price after second deposit (approximately 1:1, accounting for seed wei)
        uint priceAfter = allocation.getSharePrice(sub, 1000e6 + 1);

        assertApproxEqRel(priceInitial, priceAfter, 0.0001e18, "Share price stable after fair deposits");
    }

    function testEdge_ReplayAttackPrevented() public {
        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__InvalidNonce.selector, 1, 0));
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testEdge_FrozenBlocksAllocate() public {
        _registerMasterSubaccount();

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(Error.Allocate__SubaccountFrozen.selector);
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }

    function testEdge_NonBaseTokenReverts() public {
        // Each subaccount has a single baseToken set at registration
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        allocation.setTokenCap(weth, 100e18);

        // Register with USDC as baseToken
        _registerSubaccount(sub, usdc);

        weth.mint(owner, 10e18);
        vm.stopPrank();
        vm.prank(owner);
        weth.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        // Try to allocate WETH (not the baseToken) - should revert
        CallIntent memory wethIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: weth,
            amount: 5e18,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory wethSig = _signIntent(wethIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);

        vm.expectRevert(Error.Allocate__TokenMismatch.selector);
        allocation.executeAllocate(position, matcher, wethIntent, wethSig, emptyPuppets, emptyAmounts, emptyParams);
    }

    function testFairDistribution_ProportionalShares() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        uint ownerShares = allocation.shareBalanceMap(sub, owner);
        uint puppet1Shares = allocation.shareBalanceMap(sub, address(puppet1));

        assertEq(ownerShares, puppet1Shares, "Equal deposits = equal shares");
    }

    function testFairDistribution_ProfitSharing() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");

        _registerSubaccount(sub, usdc);

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        // Simulate profit: total value doubles
        usdc.mint(address(sub), 1000e6);

        uint ownerShares = allocation.shareBalanceMap(sub, owner);
        uint puppet1Shares = allocation.shareBalanceMap(sub, address(puppet1));

        uint totalValue = usdc.balanceOf(address(sub));
        uint totalShares = allocation.totalSharesMap(sub);

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

        _registerSubaccount(sub, usdc);

        // Owner deposits 500e6 first
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory ownerIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory ownerSig = _signIntent(ownerIntent, ownerPrivateKey);
        IERC7579Account[] memory emptyPuppets = new IERC7579Account[](0);
        uint[] memory emptyAmounts = new uint[](0);
        allocation.executeAllocate(position, matcher, ownerIntent, ownerSig, emptyPuppets, emptyAmounts, emptyParams);

        uint ownerSharesBefore = allocation.shareBalanceMap(sub, owner);

        // Profit occurs before puppet deposits
        usdc.mint(address(sub), 500e6);

        // Puppet1 deposits 500e6 after profit
        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
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
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        uint puppet1Shares = allocation.shareBalanceMap(sub, address(puppet1));

        assertLt(puppet1Shares, ownerSharesBefore, "Late depositor gets fewer shares");

        uint totalValue = usdc.balanceOf(address(sub));
        uint totalShares = allocation.totalSharesMap(sub);

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

        _registerSubaccount(sub, usdc);

        // Owner deposits 500e6
        usdc.mint(owner, 500e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory intent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: sub,
            token: usdc,
            amount: 500e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        // Puppet1 also deposits 500e6
        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = puppet1;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

        // Simulate loss: half the funds lost
        vm.stopPrank();
        vm.prank(address(sub));
        usdc.transfer(address(1), 500e6);
        vm.startPrank(users.owner);

        uint totalValue = usdc.balanceOf(address(sub));
        assertEq(totalValue, 500e6, "Half the value lost");

        uint ownerShares = allocation.shareBalanceMap(sub, owner);
        uint puppet1Shares = allocation.shareBalanceMap(sub, address(puppet1));
        uint totalShares = allocation.totalSharesMap(sub);

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

        // Owner approves Allocate
        usdc.mint(owner, 1000e6);
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);

        // Set default policies for puppets (100% allowance, no throttle, far future expiry)
        vm.prank(address(p1));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);
        vm.prank(address(p2));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);
        vm.prank(address(p3));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);
        vm.prank(address(p4));
        userRouter.setPolicy(address(0), 10000, 0, block.timestamp + 365 days);

        vm.startPrank(users.owner);

        _registerSubaccount(sub, usdc);

        uint nonce = 0;

        // Owner deposits 1000e6 + puppets deposit their amounts
        {
            CallIntent memory intent = CallIntent({
                account: owner,
                signer: owner,
                subaccount: sub,
                token: usdc,
                amount: 1000e6,
                triggerNetValue: 0,
                acceptableNetValue: type(uint).max,
                positionParamsHash: keccak256(abi.encode(emptyParams)),
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](3);
            puppets[0] = p1;
            puppets[1] = p2;
            puppets[2] = p3;

            uint[] memory amounts = new uint[](3);
            amounts[0] = 500e6;
            amounts[1] = 300e6;
            amounts[2] = 200e6;

            allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
        }

        assertEq(usdc.balanceOf(address(sub)), 2000e6, "Phase 1: Total 2000 USDC");
        assertEq(allocation.totalSharesMap(sub), 2000e6, "Phase 1: Total 2000 shares");

        uint ownerShares = allocation.shareBalanceMap(sub, owner);
        uint p1Shares = allocation.shareBalanceMap(sub, address(p1));
        uint p2Shares = allocation.shareBalanceMap(sub, address(p2));
        uint p3Shares = allocation.shareBalanceMap(sub, address(p3));

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
        uint sharePriceAfterProfit = allocation.getSharePrice(sub, 2400e6);
        assertGt(sharePriceAfterProfit, 1e30, "Phase 3: Share price increased");

        uint p4SharesBefore;
        {
            CallIntent memory intent = CallIntent({
                account: owner,
                signer: owner,
                subaccount: sub,
                token: usdc,
                amount: 0,
                triggerNetValue: 0,
                acceptableNetValue: type(uint).max,
                positionParamsHash: keccak256(abi.encode(emptyParams)),
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](1);
            puppets[0] = p4;
            uint[] memory amounts = new uint[](1);
            amounts[0] = 400e6;

            allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

            p4SharesBefore = allocation.shareBalanceMap(sub, address(p4));
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

            CallIntent memory intent = CallIntent({
                account: owner,
                signer: owner,
                subaccount: sub,
                token: usdc,
                amount: 0,
                triggerNetValue: 0,
                acceptableNetValue: type(uint).max,
                positionParamsHash: keccak256(abi.encode(emptyParams)),
                deadline: block.timestamp + 1 hours,
                nonce: nonce++
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](2);
            puppets[0] = p2;
            puppets[1] = p1;

            uint[] memory amounts = new uint[](2);
            amounts[0] = 100e6;
            amounts[1] = 100e6;

            uint p2SharesBefore = allocation.shareBalanceMap(sub, address(p2));

            allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);

            uint p2SharesAfter = allocation.shareBalanceMap(sub, address(p2));
            assertEq(p2SharesAfter, p2SharesBefore, "Phase 5: P2 shares unchanged (transfer failed)");

            uint p1SharesAfter = allocation.shareBalanceMap(sub, address(p1));
            assertGt(p1SharesAfter, p1Shares, "Phase 5: P1 shares increased");
        }

        // Phase 6: Freeze the subaccount
        vm.stopPrank();
        vm.prank(address(sub));
        sub.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        vm.startPrank(users.owner);

        assertTrue(allocation.getSubaccountInfo(sub).disposed, "Phase 7: Subaccount frozen");

        {
            CallIntent memory intent = CallIntent({
                account: owner,
                signer: owner,
                subaccount: sub,
                token: usdc,
                amount: 0,
                triggerNetValue: 0,
                acceptableNetValue: type(uint).max,
                positionParamsHash: keccak256(abi.encode(emptyParams)),
                deadline: block.timestamp + 1 hours,
                nonce: nonce
            });
            bytes memory sig = _signIntent(intent, ownerPrivateKey);

            IERC7579Account[] memory puppets = new IERC7579Account[](0);
            uint[] memory amounts = new uint[](0);

            vm.expectRevert(Error.Allocate__SubaccountFrozen.selector);
            allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
        }

        // Final balance check - no more position simulation needed, profit already reflected
        uint finalBalance = usdc.balanceOf(address(sub));
        uint finalTotalShares = allocation.totalSharesMap(sub);

        uint ownerFinalShares = allocation.shareBalanceMap(sub, owner);
        uint p1FinalShares = allocation.shareBalanceMap(sub, address(p1));
        uint p2FinalShares = allocation.shareBalanceMap(sub, address(p2));
        uint p3FinalShares = allocation.shareBalanceMap(sub, address(p3));
        uint p4FinalShares = allocation.shareBalanceMap(sub, address(p4));

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

        _registerMasterSubaccount();

        CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = puppet1;
        puppets[1] = puppet2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 150e6;
        amounts[1] = 150e6;

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__DepositExceedsCap.selector, 1300e6, 1200e6));
        allocation.executeAllocate(position, matcher, intent, sig, puppets, amounts, emptyParams);
    }
}
