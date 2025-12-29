// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocation} from "src/position/Allocation.sol";
import {Position} from "src/position/Position.sol";
import {Error} from "src/utils/Error.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {MockVenueValidator, MockVenue} from "../mock/MockVenueValidator.t.sol";
import {MockERC20} from "../mock/MockERC20.t.sol";

contract AllocationTest is BasicSetup {
    Allocation allocation;
    Position position;
    MockVenueValidator venueValidator;
    MockVenue mockVenue;

    TestSmartAccount masterSubaccount;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;

    uint constant TOKEN_CAP = 1_000_000e6;
    uint constant MAX_PUPPET_LIST = 10;
    uint constant GAS_LIMIT = 500_000;
    uint constant VIRTUAL_SHARE_OFFSET = 1e6;

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

        position = new Position(dictator);
        allocation = new Allocation(
            dictator,
            Allocation.Config({
                position: position,
                maxPuppetList: MAX_PUPPET_LIST,
                gasLimit: GAS_LIMIT,
                virtualShareOffset: VIRTUAL_SHARE_OFFSET
            })
        );

        venueValidator = new MockVenueValidator();
        mockVenue = new MockVenue();
        mockVenue.setToken(usdc);

        venueKey = keccak256("mock_venue");

        dictator.setPermission(allocation, allocation.createMasterSubaccount.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeAllocate.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeWithdraw.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeOrder.selector, users.owner);
        dictator.setPermission(allocation, allocation.setTokenCap.selector, users.owner);
        dictator.setPermission(position, position.setVenue.selector, users.owner);
        dictator.setPermission(position, position.updatePosition.selector, address(allocation));

        dictator.registerContract(address(allocation));
        dictator.registerContract(address(position));

        masterSubaccount = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        allocation.setTokenCap(usdc, TOKEN_CAP);

        address[] memory entrypoints = new address[](1);
        entrypoints[0] = address(mockVenue);
        position.setVenue(venueKey, venueValidator, entrypoints);

        matchingKey = keccak256(abi.encode(address(usdc), address(masterSubaccount), SUBACCOUNT_NAME));

        usdc.mint(owner, 10_000e6);
        usdc.mint(address(masterSubaccount), 1000e6);
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(masterSubaccount), type(uint).max);
        vm.startPrank(users.owner);
    }

    function _startTest() internal {
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
            subaccountName: SUBACCOUNT_NAME,
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
            intent.subaccountName,
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        assertEq(allocation.totalSharesMap(matchingKey), 1000e6, "Initial shares equal balance");
        assertEq(allocation.shareBalanceMap(matchingKey, owner), 1000e6, "Owner has all shares");
        assertEq(address(allocation.masterSubaccountMap(matchingKey)), address(masterSubaccount), "Subaccount registered");
        assertEq(allocation.sessionSignerMap(matchingKey), sessionSigner, "Session signer set");
    }

    function testCreateMasterSubaccount_AssociatesSignerWithMatchingKey() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        bytes32 key = keccak256(abi.encode(address(usdc), address(masterSubaccount), SUBACCOUNT_NAME));
        assertEq(allocation.sessionSignerMap(key), sessionSigner, "Signer mapped to key");
    }

    function testExecuteAllocate_MasterDepositsAndReceivesShares() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(masterSubaccount), type(uint).max);
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc, SUBACCOUNT_NAME));

        assertTrue(allocation.frozenMap(matchingKey), "Subaccount frozen");

        masterSubaccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.startPrank(users.owner);
        Allocation.CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeWithdraw(intent, sig);

        assertGt(usdc.balanceOf(owner), 0, "Withdrawal succeeded while frozen");
    }

    function testExecuteOrder_ExecutesCallOnVenue() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        mockVenue.setAmountToTake(100e6);

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        usdc.approve(address(mockVenue), 100e6);
        vm.startPrank(users.owner);

        Allocation.CallIntent memory intent = _createIntent(100e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        allocation.executeOrder(intent, sig, address(mockVenue), abi.encodeCall(MockVenue.openPosition, ()));

        assertEq(usdc.balanceOf(address(mockVenue)), 100e6, "Venue received tokens");
        assertEq(usdc.balanceOf(address(masterSubaccount)), 900e6, "Subaccount spent tokens");
    }

    function testExecuteOrder_FailedOrderReturnsEarly() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        mockVenue.setShouldRevert(true);

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        uint256 balanceBefore = usdc.balanceOf(address(masterSubaccount));
        allocation.executeOrder(intent, sig, address(mockVenue), abi.encodeCall(MockVenue.openPosition, ()));
        uint256 balanceAfter = usdc.balanceOf(address(masterSubaccount));

        assertEq(balanceBefore, balanceAfter, "Balance unchanged on failed order");
    }

    function testVerifyIntent_AcceptsOwnerSignature() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_AcceptsSessionSignerSignature() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, signerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testVerifyIntent_IncrementsNonce() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        assertFalse(allocation.frozenMap(matchingKey), "Not frozen initially");

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc, SUBACCOUNT_NAME));

        assertTrue(allocation.frozenMap(matchingKey), "Frozen after uninstall");
    }

    function testShareAccounting_VirtualOffsetProtectsFirstDeposit() public {
        uint256 sharePrice = allocation.getSharePrice(matchingKey, 0);
        assertEq(sharePrice, 1e30, "Initial share price with offset");
    }

    function testShareAccounting_PriceIncludesPositionValue() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        uint256 priceWithoutPosition = allocation.getSharePrice(matchingKey, 1000e6);

        bytes32 posKey = keccak256(abi.encode(address(masterSubaccount), "mock_position"));
        venueValidator.setPositionValue(posKey, 500e6);

        uint256 priceWithPosition = allocation.getSharePrice(matchingKey, 1500e6);

        assertGt(priceWithPosition, priceWithoutPosition, "Price higher with position value");
    }

    function testRevert_CreateMasterSubaccount_ModuleNotInstalled() public {
        TestSmartAccount unregistered = new TestSmartAccount();
        usdc.mint(address(unregistered), 100e6);

        vm.expectRevert(Error.Allocation__UnregisteredSubaccount.selector);
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(unregistered)),
            usdc,
            SUBACCOUNT_NAME
        );
    }

    function testRevert_CreateMasterSubaccount_TokenNotWhitelisted() public {
        MockERC20 unknownToken = new MockERC20("Unknown", "UNK", 18);
        unknownToken.mint(address(masterSubaccount), 100e18);

        vm.expectRevert(Error.Allocation__TokenNotAllowed.selector);
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            unknownToken,
            SUBACCOUNT_NAME
        );
    }

    function testRevert_CreateMasterSubaccount_ZeroBalance() public {
        TestSmartAccount emptyAccount = new TestSmartAccount();
        emptyAccount.installModule(MODULE_TYPE_EXECUTOR, address(allocation), "");

        vm.expectRevert(Error.Allocation__ZeroAmount.selector);
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(emptyAccount)),
            usdc,
            SUBACCOUNT_NAME
        );
    }

    function testRevert_CreateMasterSubaccount_ExceedsCap() public {
        allocation.setTokenCap(usdc, 100e6);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__DepositExceedsCap.selector, 1000e6, 100e6));
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );
    }

    function testRevert_CreateMasterSubaccount_AlreadyRegistered() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        vm.expectRevert(Error.Allocation__AlreadyRegistered.selector);
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );
    }

    function testRevert_ExecuteAllocate_Frozen() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        masterSubaccount.uninstallModule(MODULE_TYPE_EXECUTOR, address(allocation), abi.encode(usdc, SUBACCOUNT_NAME));

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
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        uint256[] memory amounts = new uint256[](1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__ArrayLengthMismatch.selector, 2, 1));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteAllocate_PuppetListTooLarge() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](MAX_PUPPET_LIST + 1);
        uint256[] memory amounts = new uint256[](MAX_PUPPET_LIST + 1);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__PuppetListTooLarge.selector, MAX_PUPPET_LIST + 1, MAX_PUPPET_LIST));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_ExecuteWithdraw_ZeroShares() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__ZeroShares.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_ExecuteWithdraw_InsufficientBalance() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(2000e6, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        vm.expectRevert(Error.Allocation__InsufficientBalance.selector);
        allocation.executeWithdraw(intent, sig);
    }

    function testRevert_VerifyIntent_ExpiredDeadline() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp - 1);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__IntentExpired.selector, block.timestamp - 1, block.timestamp));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidNonce() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        Allocation.CallIntent memory intent = _createIntent(0, 5, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocation__InvalidNonce.selector, 0, 5));
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }

    function testRevert_VerifyIntent_InvalidSigner() public {
        allocation.createMasterSubaccount(
            owner,
            sessionSigner,
            IERC7579Account(address(masterSubaccount)),
            usdc,
            SUBACCOUNT_NAME
        );

        uint256 randomKey = 0x9999;
        Allocation.CallIntent memory intent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory sig = _signIntent(intent, randomKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert();
        allocation.executeAllocate(intent, sig, puppets, amounts);
    }
}
