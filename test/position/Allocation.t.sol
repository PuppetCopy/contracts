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

contract AllocationTest is BasicSetup {
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
        dictator.setPermission(venueRegistry, venueRegistry.updatePosition.selector, address(allocation));
        dictator.setPermission(venueRegistry, venueRegistry.updatePosition.selector, users.owner);

        dictator.registerContract(address(allocation));
        dictator.registerContract(address(venueRegistry));

        masterSubaccount = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        masterSubaccount.installModule(MODULE_TYPE_HOOK, address(1), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        allocation.setTokenCap(usdc, TOKEN_CAP);

        address[] memory entrypoints = new address[](1);
        entrypoints[0] = address(mockVenue);
        venueRegistry.setVenue(venueKey, venueValidator, entrypoints);

        matchingKey = keccak256(abi.encode(address(usdc), address(masterSubaccount)));

        usdc.mint(owner, 10_000e6);
        usdc.mint(address(masterSubaccount), 1000e6);
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(masterSubaccount), type(uint).max);
        vm.startPrank(users.owner);
    }

    function _createIntent(
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (Allocation.CallIntent memory) {
        return Allocation.CallIntent({
            account: owner,
            subaccount: IERC7579Account(address(masterSubaccount)),
            
            token: usdc,
            amount: amount,
            deadline: deadline,
            nonce: nonce
        });
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

    function testCreateMasterSubaccount_RegistersWithInitialShares() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        assertEq(allocation.totalSharesMap(matchingKey), 1000e6, "Initial shares equal balance");
        assertEq(allocation.shareBalanceMap(matchingKey, owner), 1000e6, "Owner has all shares");
        assertEq(address(allocation.masterSubaccountMap(matchingKey)), address(masterSubaccount), "Subaccount registered");
        assertEq(allocation.sessionSignerMap(matchingKey), sessionSigner, "Session signer set");
    }

    function testCreateMasterSubaccount_AssociatesSignerWithMatchingKey() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        bytes32 key = keccak256(abi.encode(address(usdc), address(masterSubaccount)));
        assertEq(allocation.sessionSignerMap(key), sessionSigner, "Signer mapped to key");
    }

    function testExecuteAllocate_MasterDepositsAndReceivesShares() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertGt(allocation.shareBalanceMap(matchingKey, owner), 1000e6, "Owner shares increased");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1100e6, "Subaccount received deposit");
    }

    function testExecuteAllocate_PuppetsTransferAndReceiveShares() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(puppet2));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 200e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 has shares");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet2)), 0, "Puppet2 has shares");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Subaccount received puppet funds");
    }

    function testExecuteAllocate_FailedPuppetTransfersSkipped() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(emptyPuppet));
        puppets[1] = IERC7579Account(address(puppet1));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertEq(allocation.shareBalanceMap(matchingKey, address(emptyPuppet)), 0, "Empty puppet has no shares");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 still has shares");
    }

    function testExecuteAllocate_SkipsSelfAllocation() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        uint256 initialShares = allocation.shareBalanceMap(matchingKey, address(masterSubaccount));

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(masterSubaccount));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertEq(
            allocation.shareBalanceMap(matchingKey, address(masterSubaccount)),
            initialShares,
            "Self-allocation skipped"
        );
    }

    function testExecuteWithdraw_BurnsSharesAndTransfersTokens() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        uint256 initialShares = allocation.shareBalanceMap(matchingKey, owner);
        uint256 initialBalance = usdc.balanceOf(owner);

        Allocation.CallIntent memory intent = _createIntent(500e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(intent, sig);

        assertLt(allocation.shareBalanceMap(matchingKey, owner), initialShares, "Shares burnt");
        assertGt(usdc.balanceOf(owner), initialBalance, "Owner received tokens");
    }

    function testExecuteWithdraw_AllowedWhenFrozen() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc));

        assertTrue(allocation.disposedMap(matchingKey), "Subaccount frozen");

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);
        Allocation.CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(intent, sig);

        assertGt(usdc.balanceOf(owner), 0, "Withdrawal succeeded while frozen");
    }

    function testVerifyIntent_AcceptsOwnerSignature() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_AcceptsSessionSignerSignature() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, signerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_IncrementsNonce() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        assertEq(allocation.nonceMap(matchingKey), 0, "Initial nonce is 0");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
        assertEq(allocation.nonceMap(matchingKey), 1, "Nonce incremented");

        intent.nonce = 1;
        sig = _signIntent(intent, ownerPrivateKey);
        allocation.executeAllocate(intent, sig, puppets, amounts);
        assertEq(allocation.nonceMap(matchingKey), 2, "Nonce incremented again");
    }

    function testOnUninstall_FreezesSubaccount() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        assertFalse(allocation.disposedMap(matchingKey), "Not frozen initially");

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc));

        assertTrue(allocation.disposedMap(matchingKey), "Frozen after uninstall");
    }

    function testShareAccounting_VirtualOffsetProtectsFirstDeposit() public {
        uint256 sharePrice = allocation.getSharePrice(matchingKey, 0);
        assertEq(sharePrice, 1e30, "Initial share price with offset");
    }

    function testShareAccounting_PriceIncludesPositionValue() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        uint256 priceWithoutPosition = allocation.getSharePrice(matchingKey, 1000e6);

        bytes32 posKey = keccak256(abi.encode(address(masterSubaccount), "mock_position"));
        venueValidator.setPositionValue(posKey, 500e6);

        uint256 priceWithPosition = allocation.getSharePrice(matchingKey, 1500e6);

        assertGt(priceWithPosition, priceWithoutPosition, "Price higher with position value");
    }

    function testRevert_CreateMasterSubaccount_HookNotInstalled() public {
        TestSmartAccount noHook = new TestSmartAccount();
        noHook.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        usdc.mint(address(noHook), 100e6);

        vm.expectRevert(Error.Allocation__MasterHookNotInstalled.selector);
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(noHook)),
            usdc
        );
    }

    function testRevert_CreateMasterSubaccount_TokenNotWhitelisted() public {
        MockERC20 unknownToken = new MockERC20("Unknown", "UNK", 18);
        unknownToken.mint(address(masterSubaccount), 100e18);

        vm.expectRevert(Error.Allocation__TokenNotAllowed.selector);
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            unknownToken
        );
    }

    function testRevert_CreateMasterSubaccount_ZeroBalance() public {
        TestSmartAccount emptyAccount = new TestSmartAccount();
        emptyAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        emptyAccount.installModule(MODULE_TYPE_HOOK, address(1), "");

        vm.expectRevert(Error.Allocation__ZeroAmount.selector);
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(emptyAccount)),
            usdc
        );
    }

    function testRevert_CreateMasterSubaccount_ExceedsCap() public {
        allocation.setTokenCap(usdc, 100e6);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__DepositExceedsCap.selector, 1000e6, 100e6));
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );
    }

    function testRevert_CreateMasterSubaccount_AlreadyRegistered() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        vm.expectRevert(Error.Allocation__AlreadyRegistered.selector);
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );
    }

    function testRevert_ExecuteAllocate_Frozen() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc));

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);
        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteAllocate_ArrayLengthMismatch() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        uint256[] memory amounts = new uint256[](1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ArrayLengthMismatch.selector, 2, 1));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteAllocate_PuppetListTooLarge() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](MAX_PUPPET_LIST + 1);
        uint256[] memory amounts = new uint256[](MAX_PUPPET_LIST + 1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, MAX_PUPPET_LIST + 1, MAX_PUPPET_LIST));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteWithdraw_ZeroShares() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__ZeroShares.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_ExecuteWithdraw_InsufficientBalance() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(2000e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__InsufficientBalance.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_VerifyIntent_ExpiredDeadline() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp - 1);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__IntentExpired.selector, block.timestamp - 1, block.timestamp));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidNonce() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 5, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InvalidNonce.selector, 0, 5));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidSigner() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        uint256 randomKey = 0x9999;
        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, randomKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

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

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub1)), usdc);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub2)), usdc);

        bytes32 key1 = keccak256(abi.encode(address(usdc), address(sub1)));
        bytes32 key2 = keccak256(abi.encode(address(usdc), address(sub2)));

        assertEq(allocation.shareBalanceMap(key1, owner), 500e6, "Shares for sub1");
        assertEq(allocation.shareBalanceMap(key2, owner), 500e6, "Shares for sub2");
        assertEq(allocation.nonceMap(key1), 0, "Nonce for sub1 is independent");
        assertEq(allocation.nonceMap(key2), 0, "Nonce for sub2 is independent");
    }

    function testEdge_MixedPuppetSuccess() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](3);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(emptyPuppet));
        puppets[2] = IERC7579Account(address(puppet2));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e6;
        amounts[1] = 100e6;
        amounts[2] = 200e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet1)), 0, "Puppet1 succeeded");
        assertEq(allocation.shareBalanceMap(matchingKey, address(emptyPuppet)), 0, "Empty puppet failed");
        assertGt(allocation.shareBalanceMap(matchingKey, address(puppet2)), 0, "Puppet2 succeeded");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 1300e6, "Only successful transfers counted");
    }

    function testEdge_SharePriceAfterDeposits() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        uint256 priceInitial = allocation.getSharePrice(matchingKey, 1000e6);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](1);
        puppets[0] = IERC7579Account(address(puppet1));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint256 priceAfter = allocation.getSharePrice(matchingKey, 1500e6);

        assertEq(priceInitial, priceAfter, "Share price stable after fair deposits");
    }

    function testEdge_ReplayAttackPrevented() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InvalidNonce.selector, 1, 0));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testEdge_FrozenBlocksAllocate() public {
        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc));
        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testEdge_DifferentTokensSameSubaccount() public {
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        allocation.setTokenCap(weth, 100e18);

        weth.mint(address(masterSubaccount), 10e18);

        bytes32 usdcName = bytes32("usdc_account");
        bytes32 wethName = bytes32("weth_account");

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), usdc);
        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(masterSubaccount)), weth);

        bytes32 usdcKey = keccak256(abi.encode(address(usdc), address(masterSubaccount)));
        bytes32 wethKey = keccak256(abi.encode(address(weth), address(masterSubaccount)));

        assertEq(allocation.shareBalanceMap(usdcKey, owner), 1000e6, "USDC shares");
        assertEq(allocation.shareBalanceMap(wethKey, owner), 10e18, "WETH shares");
    }

    function testFairDistribution_ProportionalShares() public {
        usdc.mint(address(masterSubaccount), 500e6);

        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 500e6);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

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
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint256 ownerShares = allocation.shareBalanceMap(key, owner);
        uint256 puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        assertEq(ownerShares, puppet1Shares, "Equal deposits = equal shares");
    }

    function testFairDistribution_ProfitSharing() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 500e6);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

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
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        usdc.mint(address(sub), 1000e6);

        uint256 ownerShares = allocation.shareBalanceMap(key, owner);
        uint256 puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        uint256 totalValue = usdc.balanceOf(address(sub));
        uint256 totalShares = allocation.totalSharesMap(key);

        uint256 ownerValue = (totalValue * ownerShares) / totalShares;
        uint256 puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertEq(ownerShares, puppet1Shares, "Equal shares");
        assertEq(ownerValue, puppet1Value, "Equal profit distribution");
        assertApproxEqRel(ownerValue, 1000e6, 0.01e18, "Each gets ~1000e6 (500 + 500 profit)");
    }

    function testFairDistribution_LateDepositorNoFreeRide() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 500e6);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        usdc.mint(address(sub), 500e6);

        uint256 ownerSharesBefore = allocation.shareBalanceMap(key, owner);

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
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        uint256 puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));

        assertLt(puppet1Shares, ownerSharesBefore, "Late depositor gets fewer shares");

        uint256 totalValue = usdc.balanceOf(address(sub));
        uint256 totalShares = allocation.totalSharesMap(key);

        uint256 ownerValue = (totalValue * ownerSharesBefore) / totalShares;
        uint256 puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertGt(ownerValue, puppet1Value, "Early depositor has more value");
        assertApproxEqRel(ownerValue, 1000e6, 0.02e18, "Owner ~1000 (initial 500 + 500 profit)");
        assertApproxEqRel(puppet1Value, 500e6, 0.02e18, "Puppet1 ~500 (only deposit, no profit)");
    }

    function testFairDistribution_LossSharing() public {
        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 500e6);

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), usdc);

        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

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
        amounts[0] = 500e6;

        allocation.executeAllocate(intent, sig, puppets, amounts);

        vm.stopPrank();
        vm.prank(address(sub));
        usdc.transfer(address(1), 500e6);
        vm.startPrank(users.owner);

        uint256 totalValue = usdc.balanceOf(address(sub));
        assertEq(totalValue, 500e6, "Half the value lost");

        uint256 ownerShares = allocation.shareBalanceMap(key, owner);
        uint256 puppet1Shares = allocation.shareBalanceMap(key, address(puppet1));
        uint256 totalShares = allocation.totalSharesMap(key);

        uint256 ownerValue = (totalValue * ownerShares) / totalShares;
        uint256 puppet1Value = (totalValue * puppet1Shares) / totalShares;

        assertEq(ownerShares, puppet1Shares, "Equal shares");
        assertApproxEqRel(ownerValue, 250e6, 0.01e18, "Owner lost 50%");
        assertApproxEqRel(puppet1Value, 250e6, 0.01e18, "Puppet1 lost 50%");
    }

    function testComplex_TradingLifecycleWithMixedOutcomes() public {
        allocation.setTokenCap(usdc, 10_000e6);

        TestSmartAccount sub = new TestSmartAccount();
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        sub.installModule(MODULE_TYPE_HOOK, address(1), "");
        usdc.mint(address(sub), 1000e6);

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

        bytes32 name = bytes32("lifecycle_test");
        bytes32 key = keccak256(abi.encode(address(usdc), address(sub)));

        allocation.registerMasterSubaccount(owner, sessionSigner, IERC7579Account(address(sub)), usdc);

        uint256 nonce = 0;

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

            IERC7579Account[] memory puppets = new IERC7579Account[](3);
            puppets[0] = IERC7579Account(address(p1));
            puppets[1] = IERC7579Account(address(p2));
            puppets[2] = IERC7579Account(address(p3));

            uint256[] memory amounts = new uint256[](3);
            amounts[0] = 500e6;
            amounts[1] = 300e6;
            amounts[2] = 200e6;

            allocation.executeAllocate(intent, sig, puppets, amounts);
        }

        assertEq(usdc.balanceOf(address(sub)), 2000e6, "Phase 1: Total 2000 USDC");
        assertEq(allocation.totalSharesMap(key), 2000e6, "Phase 1: Total 2000 shares");

        uint256 ownerShares = allocation.shareBalanceMap(key, owner);
        uint256 p1Shares = allocation.shareBalanceMap(key, address(p1));
        uint256 p2Shares = allocation.shareBalanceMap(key, address(p2));
        uint256 p3Shares = allocation.shareBalanceMap(key, address(p3));

        assertEq(ownerShares, 1000e6, "Owner: 1000 shares");
        assertEq(p1Shares, 500e6, "P1: 500 shares");
        assertEq(p2Shares, 300e6, "P2: 300 shares");
        assertEq(p3Shares, 200e6, "P3: 200 shares");

        // Simulate opening a position: transfer funds to venue and track position value
        // (In production, this happens via MasterHook → VenueRegistry → Validator flow)
        bytes32 posKey = keccak256(abi.encode(address(sub), "mock_position"));

        vm.stopPrank();
        vm.prank(address(sub));
        usdc.transfer(address(mockVenue), 800e6);
        vm.startPrank(users.owner);

        // Register position in VenueRegistry and set its value
        VenueRegistry.Venue memory venue = VenueRegistry.Venue({venueKey: venueKey, validator: venueValidator});
        venueRegistry.updatePosition(key, posKey, venue, 800e6);
        venueValidator.setPositionValue(posKey, 800e6);

        assertEq(usdc.balanceOf(address(sub)), 1200e6, "Phase 2: 1200 liquid after order");
        assertEq(usdc.balanceOf(address(mockVenue)), 800e6, "Phase 2: Venue has 800");

        // Simulate position profit: 800 spent -> 1200 value (50% profit)
        venueValidator.setPositionValue(posKey, 1200e6);

        uint256 sharePriceAfterProfit = allocation.getSharePrice(key, 1200e6 + 1200e6);
        assertGt(sharePriceAfterProfit, 1e30, "Phase 3: Share price increased");

        uint256 p4SharesBefore;
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
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 400e6;

            allocation.executeAllocate(intent, sig, puppets, amounts);

            p4SharesBefore = allocation.shareBalanceMap(key, address(p4));
        }

        assertLt(p4SharesBefore, 400e6, "Phase 4: P4 gets fewer shares (paid premium)");
        assertEq(usdc.balanceOf(address(sub)), 1600e6, "Phase 4: 1600 liquid now");

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

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 100e6;
            amounts[1] = 100e6;

            uint256 p2SharesBefore = allocation.shareBalanceMap(key, address(p2));

            allocation.executeAllocate(intent, sig, puppets, amounts);

            uint256 p2SharesAfter = allocation.shareBalanceMap(key, address(p2));
            assertEq(p2SharesAfter, p2SharesBefore, "Phase 5: P2 shares unchanged (transfer failed)");

            uint256 p1SharesAfter = allocation.shareBalanceMap(key, address(p1));
            assertGt(p1SharesAfter, p1Shares, "Phase 5: P1 shares increased");
        }

        // Phase 6: Freeze the subaccount
        vm.stopPrank();
        vm.prank(address(sub));
        sub.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc));
        sub.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        vm.startPrank(users.owner);

        assertTrue(allocation.disposedMap(key), "Phase 7: Subaccount frozen");

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
            uint256[] memory amounts = new uint256[](0);

            vm.expectRevert(Error.Allocation__SubaccountFrozen.selector);
            allocation.executeAllocate(intent, sig, puppets, amounts);
        }

        // Simulate closing profitable position - venue returns principal + profit
        venueValidator.setPositionValue(posKey, 0);
        usdc.mint(address(mockVenue), 400e6);  // Mint the 400 USDC profit (800 -> 1200)

        vm.stopPrank();
        vm.prank(address(mockVenue));
        usdc.transfer(address(sub), 1200e6);
        vm.startPrank(users.owner);

        uint256 finalBalance = usdc.balanceOf(address(sub));
        uint256 finalTotalShares = allocation.totalSharesMap(key);

        uint256 ownerFinalShares = allocation.shareBalanceMap(key, owner);
        uint256 p1FinalShares = allocation.shareBalanceMap(key, address(p1));
        uint256 p2FinalShares = allocation.shareBalanceMap(key, address(p2));
        uint256 p3FinalShares = allocation.shareBalanceMap(key, address(p3));
        uint256 p4FinalShares = allocation.shareBalanceMap(key, address(p4));

        uint256 ownerExpectedValue = (finalBalance * ownerFinalShares) / finalTotalShares;
        uint256 p1ExpectedValue = (finalBalance * p1FinalShares) / finalTotalShares;
        uint256 p2ExpectedValue = (finalBalance * p2FinalShares) / finalTotalShares;
        uint256 p3ExpectedValue = (finalBalance * p3FinalShares) / finalTotalShares;
        uint256 p4ExpectedValue = (finalBalance * p4FinalShares) / finalTotalShares;

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

        allocation.registerMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = IERC7579Account(address(puppet1));
        puppets[1] = IERC7579Account(address(puppet2));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 150e6;
        amounts[1] = 150e6;

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__DepositExceedsCap.selector, 1300e6, 1200e6));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }
}
