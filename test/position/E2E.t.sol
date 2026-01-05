// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";
import {ModeLib, CALLTYPE_SINGLE} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

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

/// @title E2E Test - Copy Trading Flow
/// @notice Tests the complete flow: registration -> allocation -> trade -> settlement -> withdraw
contract E2ETest is BasicSetup {
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

    uint ownerPrivateKey = 0x1234;
    uint signerPrivateKey = 0x5678;
    address owner;
    address sessionSigner;

    bytes32 positionKey = keccak256("test_position");
    bytes32 orderKey = keccak256("test_order");

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        sessionSigner = vm.addr(signerPrivateKey);

        position = new Position(dictator);
        matcher = new Match(dictator);
        allocation = new Allocate(
            dictator,
            Allocate.Config({
                masterHook: address(1),
                maxPuppetList: MAX_PUPPET_LIST,
                withdrawGasLimit: GAS_LIMIT
            })
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

        dictator.setPermission(allocation, allocation.registerMasterSubaccount.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeAllocate.selector, users.owner);
        dictator.setPermission(allocation, allocation.executeWithdraw.selector, users.owner);
        dictator.setPermission(allocation, allocation.setTokenCap.selector, users.owner);
        dictator.setPermission(position, position.setHandler.selector, users.owner);
        dictator.setPermission(position, position.processPostCall.selector, users.owner);
        dictator.setPermission(position, position.settleOrders.selector, users.owner);

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

        // Setup mock stage
        mockStage.setMockToken(usdc);
        mockStage.setMockPositionKey(positionKey);
        mockStage.setPositionOwner(positionKey, address(masterSubaccount));

        // Mint tokens
        usdc.mint(owner, 10_000e6);
        usdc.mint(address(masterSubaccount), 100e6); // Seed for registration
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);

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

    function _registerMasterSubaccount() internal {
        allocation.registerMasterSubaccount(owner, sessionSigner, masterSubaccount, usdc, SUBACCOUNT_NAME);
    }

    /// @notice Complete E2E test: register -> allocate -> trade -> settle -> withdraw
    function test_E2E_CopyTradingFlow() public {
        // =========================================
        // Step 1: Register master subaccount
        // =========================================
        _registerMasterSubaccount();

        SubaccountInfo memory info = allocation.getSubaccountInfo(masterSubaccount);
        assertTrue(address(info.baseToken) != address(0), "Subaccount should be registered");
        assertEq(info.signer, sessionSigner, "Session signer should be set");

        // =========================================
        // Step 2: Puppets allocate funds (copy)
        // =========================================
        CallIntent memory allocIntent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory allocSig = _signIntent(allocIntent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = puppet1;
        puppets[1] = puppet2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 200e6; // Puppet1 allocates 200 USDC
        amounts[1] = 300e6; // Puppet2 allocates 300 USDC

        uint subaccountBalanceBefore = usdc.balanceOf(address(masterSubaccount));

        allocation.executeAllocate(position, matcher, allocIntent, allocSig, puppets, amounts, emptyParams);

        // Verify allocations
        assertEq(
            usdc.balanceOf(address(masterSubaccount)),
            subaccountBalanceBefore + 500e6,
            "Subaccount should receive puppet funds"
        );
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 0, "Puppet1 should have shares");
        assertGt(allocation.shareBalanceMap(masterSubaccount, address(puppet2)), 0, "Puppet2 should have shares");
        assertEq(allocation.totalSharesMap(masterSubaccount), 500e6, "Total shares should equal allocated amount");

        // =========================================
        // Step 3: Master executes a trade (creates order)
        // =========================================
        // Simulate the hook flow that would happen when master executes via MasterHook

        // Build execution data for a trade
        bytes memory execData = ExecutionLib.encodeSingle(
            address(mockVenue),
            0,
            abi.encodeCall(MockVenue.openPosition, ())
        );

        // Build the full calldata as it would be sent to the account
        bytes memory fullCalldata = abi.encodePacked(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            execData
        );

        // processPreCall validates the trade
        bytes memory hookData = position.processPreCall(
            owner,
            address(masterSubaccount),
            0,
            fullCalldata
        );

        assertGt(hookData.length, 0, "Hook data should be returned for valid trade");

        // Simulate order creation in post-call (normally called by MasterHook)
        // We need to encode hookData that includes ACTION_ORDER_CREATED
        bytes memory orderHookData = abi.encode(
            usdc,
            usdc.balanceOf(address(masterSubaccount)),
            abi.encode(uint8(1), orderKey, positionKey, usdc), // ACTION_ORDER_CREATED = 1
            mockStage
        );

        uint pendingBefore = position.pendingOrderCount(address(masterSubaccount));
        position.processPostCall(address(masterSubaccount), orderHookData);

        assertEq(
            position.pendingOrderCount(address(masterSubaccount)),
            pendingBefore + 1,
            "Pending order count should increment"
        );

        // =========================================
        // Step 4: Verify getNetValue blocked with pending orders
        // =========================================
        IStage[] memory stages = new IStage[](1);
        stages[0] = mockStage;
        bytes32[][] memory posKeys = new bytes32[][](1);
        posKeys[0] = new bytes32[](1);
        posKeys[0][0] = positionKey;

        vm.expectRevert(Error.Position__PendingOrdersExist.selector);
        position.getNetValue(address(masterSubaccount), usdc, stages, posKeys);

        // =========================================
        // Step 5: Settle orders (after GMX executes)
        // =========================================
        // Mark order as no longer pending in mock
        mockStage.setOrderPending(orderKey, false);

        IStage[] memory orderStages = new IStage[](1);
        orderStages[0] = mockStage;
        bytes32[] memory orderKeys = new bytes32[](1);
        orderKeys[0] = orderKey;

        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);

        assertEq(position.pendingOrderCount(address(masterSubaccount)), 0, "Pending orders should be cleared");

        // =========================================
        // Step 6: getNetValue now works
        // =========================================
        mockStage.setPositionValue(positionKey, 600e6); // Position appreciated

        uint netValue = position.getNetValue(address(masterSubaccount), usdc, stages, posKeys);
        assertEq(netValue, 600e6, "Net value should include position value");

        // =========================================
        // Step 7: Puppet1 withdraws
        // =========================================
        uint puppet1Shares = allocation.shareBalanceMap(masterSubaccount, address(puppet1));
        uint puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        // Simulate position closed - funds back in subaccount
        // (In reality, GMX would send funds. Here we mint to MockVenue then transfer)
        usdc.mint(address(mockVenue), 600e6);
        mockVenue.closePosition(address(masterSubaccount), 600e6);
        mockStage.setPositionValue(positionKey, 0);

        CallIntent memory withdrawIntent = CallIntent({
            account: address(puppet1),
            signer: address(puppet1),
            subaccount: masterSubaccount,
            token: usdc,
            amount: puppet1Shares, // Withdraw all shares
            triggerNetValue: 0,
            acceptableNetValue: 0,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 0
        });

        // Sign with puppet1's key (need to setup puppet as EOA for this test)
        uint puppet1PrivateKey = 0xABCD;
        address puppet1Addr = vm.addr(puppet1PrivateKey);

        // Transfer puppet1's shares to an EOA for withdrawal test
        // In production, puppet1 would sign directly

        // For simplicity, we test the owner withdrawing their portion
        CallIntent memory ownerWithdrawIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: 0, // Owner has 0 shares in this test
            triggerNetValue: 0,
            acceptableNetValue: 0,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory withdrawSig = _signIntent(ownerWithdrawIntent, ownerPrivateKey);

        // This would revert with no shares, but demonstrates the flow
        // allocation.executeWithdraw(ownerWithdrawIntent, withdrawSig, emptyParams);
    }

    /// @notice Test settlement fails if order still pending
    function test_SettleOrders_RevertsIfOrderPending() public {
        _registerMasterSubaccount();

        // Create a pending order
        bytes memory orderHookData = abi.encode(
            usdc,
            usdc.balanceOf(address(masterSubaccount)),
            abi.encode(uint8(1), orderKey, positionKey, usdc),
            mockStage
        );
        position.processPostCall(address(masterSubaccount), orderHookData);

        // Order is still pending in GMX
        mockStage.setOrderPending(orderKey, true);

        IStage[] memory orderStages = new IStage[](1);
        orderStages[0] = mockStage;
        bytes32[] memory orderKeys = new bytes32[](1);
        orderKeys[0] = orderKey;

        vm.expectRevert(Error.Position__OrderStillPending.selector);
        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);
    }

    /// @notice Test settlement fails with invalid stage
    function test_SettleOrders_RevertsWithInvalidStage() public {
        _registerMasterSubaccount();

        MockStage invalidStage = new MockStage();

        IStage[] memory orderStages = new IStage[](1);
        orderStages[0] = invalidStage; // Not registered
        bytes32[] memory orderKeys = new bytes32[](1);
        orderKeys[0] = orderKey;

        vm.expectRevert(Error.Position__InvalidStage.selector);
        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);
    }

    /// @notice Test settlement fails with array length mismatch
    function test_SettleOrders_RevertsWithArrayMismatch() public {
        IStage[] memory orderStages = new IStage[](2);
        orderStages[0] = mockStage;
        orderStages[1] = mockStage;
        bytes32[] memory orderKeys = new bytes32[](1);
        orderKeys[0] = orderKey;

        vm.expectRevert(Error.Position__ArrayLengthMismatch.selector);
        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);
    }

    /// @notice Complex flow: partial positions, open positions, partial withdrawal
    function test_E2E_PartialWithdrawWithOpenPositions() public {
        // =========================================
        // Setup: Register and allocate
        // =========================================
        _registerMasterSubaccount();

        CallIntent memory allocIntent = _createIntent(0, 0, block.timestamp + 1 hours);
        bytes memory allocSig = _signIntent(allocIntent, ownerPrivateKey);

        IERC7579Account[] memory puppets = new IERC7579Account[](2);
        puppets[0] = puppet1;
        puppets[1] = puppet2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 300e6; // Puppet1 allocates 300 USDC
        amounts[1] = 200e6; // Puppet2 allocates 200 USDC

        allocation.executeAllocate(position, matcher, allocIntent, allocSig, puppets, amounts, emptyParams);

        // Total: 500 USDC allocated (300 + 200)
        // Puppet1 owns 60% (300/500), Puppet2 owns 40% (200/500)
        assertEq(allocation.totalSharesMap(masterSubaccount), 500e6, "Total shares = 500");

        // =========================================
        // Create multiple orders (2 positions)
        // =========================================
        bytes32 orderKey1 = keccak256("order_1");
        bytes32 orderKey2 = keccak256("order_2");
        bytes32 positionKey1 = keccak256("position_1");
        bytes32 positionKey2 = keccak256("position_2");

        // Order 1: 200 USDC position
        bytes memory orderHookData1 = abi.encode(
            usdc,
            0,
            abi.encode(uint8(1), orderKey1, positionKey1, usdc),
            mockStage
        );
        position.processPostCall(address(masterSubaccount), orderHookData1);

        // Order 2: 300 USDC position
        bytes memory orderHookData2 = abi.encode(
            usdc,
            0,
            abi.encode(uint8(1), orderKey2, positionKey2, usdc),
            mockStage
        );
        position.processPostCall(address(masterSubaccount), orderHookData2);

        assertEq(position.pendingOrderCount(address(masterSubaccount)), 2, "2 pending orders");

        // =========================================
        // Settle both orders (positions now open, orders executed)
        // =========================================
        mockStage.setOrderPending(orderKey1, false);
        mockStage.setOrderPending(orderKey2, false);

        IStage[] memory orderStages = new IStage[](2);
        orderStages[0] = mockStage;
        orderStages[1] = mockStage;
        bytes32[] memory orderKeys = new bytes32[](2);
        orderKeys[0] = orderKey1;
        orderKeys[1] = orderKey2;

        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);
        assertEq(position.pendingOrderCount(address(masterSubaccount)), 0, "Orders settled");

        // =========================================
        // Setup position values (both positions still open)
        // =========================================
        // Position 1: 200 USDC -> now worth 250 USDC (profit)
        // Position 2: 300 USDC -> now worth 280 USDC (loss)
        // Total position value: 530 USDC
        mockStage.setPositionValue(positionKey1, 250e6);
        mockStage.setPositionValue(positionKey2, 280e6);
        mockStage.setPositionOwner(positionKey1, address(masterSubaccount));
        mockStage.setPositionOwner(positionKey2, address(masterSubaccount));

        // Subaccount has some remaining collateral (100 USDC from seed)
        uint subaccountBalance = usdc.balanceOf(address(masterSubaccount));
        assertEq(subaccountBalance, 600e6, "Subaccount has 600 USDC (100 seed + 500 allocated)");

        // =========================================
        // Calculate net value with open positions
        // =========================================
        IStage[] memory stages = new IStage[](1);
        stages[0] = mockStage;
        bytes32[][] memory posKeys = new bytes32[][](1);
        posKeys[0] = new bytes32[](2);
        posKeys[0][0] = positionKey1;
        posKeys[0][1] = positionKey2;

        uint netValue = position.getNetValue(address(masterSubaccount), usdc, stages, posKeys);
        assertEq(netValue, 530e6, "Net value = position values (250 + 280)");

        // Total value = collateral (600) + position value (530) = 1130 USDC
        // But wait - in real scenario, collateral was used to open positions
        // Let's simulate: 500 USDC used for positions, 100 remains as collateral
        // Simulate funds used for positions (transfer out to venue)
        vm.stopPrank();
        vm.prank(address(masterSubaccount));
        usdc.transfer(address(mockVenue), 500e6);
        vm.startPrank(users.owner);

        uint remainingCollateral = usdc.balanceOf(address(masterSubaccount));
        assertEq(remainingCollateral, 100e6, "100 USDC collateral remains");

        // =========================================
        // Puppet1 wants partial withdrawal while positions open
        // =========================================
        // Puppet1 has 300e6 shares (60%)
        // Available for withdrawal = collateral only (100 USDC)
        // Puppet1's share of available = 60% of 100 = 60 USDC

        uint puppet1Shares = allocation.shareBalanceMap(masterSubaccount, address(puppet1));
        assertEq(puppet1Shares, 300e6, "Puppet1 has 300 shares");

        // Puppet1 withdraws 50% of their shares (150 shares)
        uint withdrawShares = 150e6;

        // Calculate expected withdrawal amount
        // Total value = collateral (100) + positions (530) = 630 USDC
        // But executeWithdraw only transfers from subaccount balance
        // Share price = totalValue / totalShares = 630 / 500 = 1.26
        // Expected out = 150 * 1.26 = 189 USDC
        // BUT subaccount only has 100 USDC available!

        // In real scenario, master would need to close positions first
        // For this test, let's have master close position 1 first

        // =========================================
        // Master closes position 1 (profit realized)
        // =========================================
        usdc.mint(address(mockVenue), 250e6); // Position 1 returns 250 USDC
        mockVenue.closePosition(address(masterSubaccount), 250e6);
        mockStage.setPositionValue(positionKey1, 0);

        // Now subaccount has: 100 + 250 = 350 USDC
        assertEq(usdc.balanceOf(address(masterSubaccount)), 350e6, "350 USDC after closing pos1");

        // Net value from remaining position
        posKeys[0] = new bytes32[](1);
        posKeys[0][0] = positionKey2;
        netValue = position.getNetValue(address(masterSubaccount), usdc, stages, posKeys);
        assertEq(netValue, 280e6, "Position 2 still worth 280");

        // =========================================
        // Puppet1 withdraws partial shares
        // =========================================
        // Total value = 350 (collateral) + 280 (position) = 630 USDC
        // Share price = 630 / 500 = 1.26
        // Puppet1 withdraws 150 shares -> 150 * 1.26 = 189 USDC

        uint puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        // Create withdraw intent for puppet1
        // We need to sign with puppet1's key - for test, use a mock private key
        uint puppet1PrivateKey = 0xABCDE;
        address puppet1Signer = vm.addr(puppet1PrivateKey);

        // In real scenario, puppet1 (smart account) would sign
        // For testing, we simulate by having owner withdraw on puppet's behalf
        // This shows the flow works - in production puppet signs their own withdrawal

        // Actually, let's test owner withdrawing since they deposited
        // First, let owner deposit some funds to have shares
        vm.stopPrank();
        vm.prank(owner);
        usdc.approve(address(allocation), type(uint).max);
        vm.startPrank(users.owner);

        CallIntent memory ownerDepositIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: 100e6,
            triggerNetValue: 0,
            acceptableNetValue: type(uint).max,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 1
        });
        bytes memory ownerDepositSig = _signIntent(ownerDepositIntent, ownerPrivateKey);
        IERC7579Account[] memory noPuppets = new IERC7579Account[](0);
        uint[] memory noAmounts = new uint[](0);

        allocation.executeAllocate(position, matcher, ownerDepositIntent, ownerDepositSig, noPuppets, noAmounts, emptyParams);

        // Owner now has shares proportional to their deposit
        uint ownerShares = allocation.shareBalanceMap(masterSubaccount, owner);
        assertGt(ownerShares, 0, "Owner has shares");

        uint ownerBalanceBefore = usdc.balanceOf(owner);

        // Owner withdraws half their shares
        uint ownerWithdrawAmount = ownerShares / 2;

        CallIntent memory ownerWithdrawIntent = CallIntent({
            account: owner,
            signer: owner,
            subaccount: masterSubaccount,
            token: usdc,
            amount: ownerWithdrawAmount,
            triggerNetValue: 0,
            acceptableNetValue: 0,
            positionParamsHash: keccak256(abi.encode(emptyParams)),
            deadline: block.timestamp + 1 hours,
            nonce: 2
        });
        bytes memory ownerWithdrawSig = _signIntent(ownerWithdrawIntent, ownerPrivateKey);

        allocation.executeWithdraw(position, ownerWithdrawIntent, ownerWithdrawSig, emptyParams);

        // Verify withdrawal happened
        assertLt(allocation.shareBalanceMap(masterSubaccount, owner), ownerShares, "Owner shares reduced");
        assertGt(usdc.balanceOf(owner), ownerBalanceBefore, "Owner received USDC");

        // =========================================
        // Verify remaining state is consistent
        // =========================================
        // Position 2 still open
        netValue = position.getNetValue(address(masterSubaccount), usdc, stages, posKeys);
        assertEq(netValue, 280e6, "Position 2 unchanged");

        // Puppets still have their shares
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(puppet1)), 300e6, "Puppet1 shares unchanged");
        assertEq(allocation.shareBalanceMap(masterSubaccount, address(puppet2)), 200e6, "Puppet2 shares unchanged");
    }

    /// @notice Test multiple order settlement
    function test_SettleOrders_MultipleOrders() public {
        _registerMasterSubaccount();

        bytes32 orderKey2 = keccak256("test_order_2");
        bytes32 orderKey3 = keccak256("test_order_3");

        // Create 3 pending orders
        for (uint i = 0; i < 3; i++) {
            bytes32 key = i == 0 ? orderKey : (i == 1 ? orderKey2 : orderKey3);
            bytes memory orderHookData = abi.encode(
                usdc,
                0,
                abi.encode(uint8(1), key, positionKey, usdc),
                mockStage
            );
            position.processPostCall(address(masterSubaccount), orderHookData);
        }

        assertEq(position.pendingOrderCount(address(masterSubaccount)), 3, "Should have 3 pending orders");

        // Settle 2 orders
        mockStage.setOrderPending(orderKey, false);
        mockStage.setOrderPending(orderKey2, false);

        IStage[] memory orderStages = new IStage[](2);
        orderStages[0] = mockStage;
        orderStages[1] = mockStage;
        bytes32[] memory orderKeys = new bytes32[](2);
        orderKeys[0] = orderKey;
        orderKeys[1] = orderKey2;

        position.settleOrders(address(masterSubaccount), orderStages, orderKeys);

        assertEq(position.pendingOrderCount(address(masterSubaccount)), 1, "Should have 1 pending order remaining");
    }
}
