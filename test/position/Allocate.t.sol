// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Attest} from "src/attest/Attest.sol";
import {Compact} from "src/compact/Compact.sol";
import {Match} from "src/position/Match.sol";
import {UserRouter} from "src/UserRouter.sol";
import {Position} from "src/position/Position.sol";
import {MasterInfo} from "src/position/interface/ITypes.sol";
import {Error} from "src/utils/Error.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {AttestorMock} from "../mock/AttestorMock.t.sol";
import {MockERC20} from "../mock/MockERC20.t.sol";

contract AllocateTest is BasicSetup {
    Allocate allocate;
    Attest attest;
    Compact compact;
    Match matcher;
    Position position;
    UserRouter userRouter;
    AttestorMock attestorMock;

    TestSmartAccount master;
    TestSmartAccount puppet1;
    TestSmartAccount puppet2;

    uint256 constant TOKEN_CAP = 1_000_000e6;
    uint256 constant GAS_LIMIT = 500_000;
    uint256 constant ATTESTOR_PRIVATE_KEY = 0xA77E5707;

    bytes32 constant MASTER_NAME = bytes32("main");

    address owner;
    address signer;
    uint256 ownerPrivateKey = 0x1234;
    uint256 signerPrivateKey = 0x5678;

    uint256 globalNonce;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        signer = vm.addr(signerPrivateKey);

        // Create attestor mock
        attestorMock = new AttestorMock(ATTESTOR_PRIVATE_KEY);

        // Deploy core contracts
        attest = new Attest(dictator, Attest.Config({attestor: attestorMock.attestorAddress()}));
        compact = new Compact(dictator, Compact.Config({attestor: attestorMock.attestorAddress()}));
        position = new Position(dictator);
        matcher = new Match(dictator, Match.Config({minThrottlePeriod: 6 hours}));

        allocate = new Allocate(
            dictator,
            Allocate.Config({
                attest: attest,
                masterHook: address(1), // Mock hook
                compact: compact,
                allocateGasLimit: GAS_LIMIT,
                withdrawGasLimit: GAS_LIMIT
            })
        );

        // Register contracts with dictator
        dictator.registerContract(address(attest));
        dictator.registerContract(address(compact));
        dictator.registerContract(address(matcher));
        dictator.registerContract(address(allocate));
        dictator.registerContract(address(position));

        // Setup UserRouter
        userRouter = new UserRouter(
            dictator,
            UserRouter.Config({allocation: allocate, matcher: matcher, position: position})
        );
        dictator.setPermission(matcher, matcher.setFilter.selector, address(userRouter));
        dictator.setPermission(matcher, matcher.setPolicy.selector, address(userRouter));

        // Set permissions
        dictator.setPermission(allocate, allocate.setCodeHash.selector, users.owner);
        dictator.setPermission(allocate, allocate.createMaster.selector, users.owner);
        dictator.setPermission(allocate, allocate.allocate.selector, users.owner);
        dictator.setPermission(allocate, allocate.withdraw.selector, users.owner);
        dictator.setPermission(allocate, allocate.setTokenCap.selector, users.owner);
        dictator.setPermission(allocate, allocate.disposeMaster.selector, users.owner);
        dictator.setPermission(attest, attest.verify.selector, address(allocate));
        dictator.setPermission(compact, compact.mint.selector, address(allocate));
        dictator.setPermission(compact, compact.burn.selector, address(allocate));
        dictator.setPermission(compact, compact.mintMany.selector, address(allocate));
        dictator.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));

        // Whitelist TestSmartAccount code hash
        allocate.setCodeHash(keccak256(type(TestSmartAccount).runtimeCode), true);

        // Create test accounts
        master = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        // Install modules
        master.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        master.installModule(MODULE_TYPE_HOOK, address(1), ""); // Mock hook
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");

        // Set token cap
        allocate.setTokenCap(usdc, TOKEN_CAP);

        // Fund puppets
        usdc.mint(address(puppet1), 500e6);
        usdc.mint(address(puppet2), 500e6);

        vm.stopPrank();

        // Set default policies for puppets
        vm.prank(address(puppet1));
        userRouter.setPolicy(address(0), 10000, 6 hours, block.timestamp + 365 days);
        vm.prank(address(puppet2));
        userRouter.setPolicy(address(0), 10000, 6 hours, block.timestamp + 365 days);

        vm.startPrank(users.owner);
    }

    // ============ Helper Functions ============

    function _registerMasterAccount() internal {
        allocate.createMaster(owner, signer, master, usdc, MASTER_NAME);
    }

    function _createAllocateAttestation(
        IERC7579Account _master,
        uint256 _sharePrice,
        address[] memory _puppetList,
        uint256[] memory _amountList
    ) internal returns (Allocate.AllocateAttestation memory) {
        return attestorMock.signAllocateAttestation(
            allocate,
            _master,
            _sharePrice,
            _puppetList,
            _amountList,
            globalNonce++,
            block.timestamp + 1 hours
        );
    }

    function _createWithdrawAttestation(
        address _user,
        IERC7579Account _master,
        uint256 _amount,
        uint256 _sharePrice
    ) internal returns (Allocate.WithdrawAttestation memory) {
        return attestorMock.signWithdrawAttestation(
            allocate,
            _user,
            _master,
            _amount,
            _sharePrice,
            globalNonce++,
            block.timestamp + 1 hours
        );
    }

    function _computeTokenId(address _master, address _baseToken) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_master, _baseToken)));
    }

    // ============ Registration Tests ============

    function testCreateMasterAccount_Registers() public {
        _registerMasterAccount();

        MasterInfo memory info = allocate.getMasterInfo(master);
        assertEq(info.user, owner);
        assertEq(info.signer, signer);
        assertEq(address(info.baseToken), address(usdc));
        assertEq(info.name, MASTER_NAME);
        assertFalse(info.disposed);
    }

    function testCreateMasterAccount_WithInitialBalance() public {
        usdc.mint(address(master), 100e6);
        _registerMasterAccount();

        // No shares minted at registration (attestor provides share price at allocation time)
        uint256 tokenId = _computeTokenId(address(master), address(usdc));
        // New puppets have 0 balance before allocation
        assertEq(compact.balanceOf(address(puppet1), tokenId), 0);
    }

    function testRevert_CreateMasterAccount_AlreadyRegistered() public {
        _registerMasterAccount();

        vm.expectRevert(Error.Allocate__AlreadyRegistered.selector);
        allocate.createMaster(owner, signer, master, usdc, MASTER_NAME);
    }

    function testRevert_CreateMasterAccount_TokenNotAllowed() public {
        MockERC20 randomToken = new MockERC20("Random", "RND", 18);

        vm.expectRevert(Error.Allocate__TokenNotAllowed.selector);
        allocate.createMaster(owner, signer, master, IERC20(address(randomToken)), MASTER_NAME);
    }

    // ============ Allocation Tests ============

    function testExecuteAllocate_TransfersPuppetFunds() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 100e6;
        amountList[1] = 200e6;

        // Share price = 1e30 (1:1 ratio)
        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        uint256 masterBalanceBefore = usdc.balanceOf(address(master));

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        assertEq(usdc.balanceOf(address(master)), masterBalanceBefore + 300e6);
    }

    function testExecuteAllocate_MintsSharesToPuppets() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 100e6;
        amountList[1] = 200e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));

        // At 1:1 share price, shares = amount
        assertEq(compact.balanceOf(address(puppet1), tokenId), 100e6);
        assertEq(compact.balanceOf(address(puppet2), tokenId), 200e6);
    }

    function testExecuteAllocate_SharesProportionalToSharePrice() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        // Share price = 2e30 (2:1 ratio, each share worth 2 tokens)
        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 2e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));

        // 100 tokens at 2:1 price = 50 shares
        assertEq(compact.balanceOf(address(puppet1), tokenId), 50e6);
    }

    function testExecuteAllocate_SkipsFailedTransfers() public {
        _registerMasterAccount();

        TestSmartAccount emptyPuppet = new TestSmartAccount();
        emptyPuppet.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        vm.stopPrank();
        vm.prank(address(emptyPuppet));
        userRouter.setPolicy(address(0), 10000, 6 hours, block.timestamp + 365 days);
        vm.startPrank(users.owner);

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(emptyPuppet); // No balance
        puppetList[1] = address(puppet1);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 100e6;
        amountList[1] = 100e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));

        // Empty puppet skipped, only puppet1 transferred
        assertEq(compact.balanceOf(address(emptyPuppet), tokenId), 0);
        assertEq(compact.balanceOf(address(puppet1), tokenId), 100e6);
        assertEq(usdc.balanceOf(address(master)), 100e6);
    }

    function testRevert_ExecuteAllocate_UnregisteredMasterAccount() public {
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        vm.expectRevert(Error.Allocate__UnregisteredMaster.selector);
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    function testRevert_ExecuteAllocate_ArrayLengthMismatch() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](2);
        uint256[] memory amountList = new uint256[](1);

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__ArrayLengthMismatch.selector, 2, 1));
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    function testRevert_ExecuteAllocate_ExpiredAttestation() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        // Create attestation with past deadline
        Allocate.AllocateAttestation memory attestation = attestorMock.signAllocateAttestation(
            allocate,
            master,
            1e30,
            puppetList,
            amountList,
            globalNonce++,
            block.timestamp - 1 // Expired
        );

        vm.expectRevert(
            abi.encodeWithSelector(Error.Allocate__AttestationExpired.selector, block.timestamp - 1, block.timestamp)
        );
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    function testRevert_ExecuteAllocate_ReplayAttack() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        // Try to replay - nonce already consumed
        vm.expectRevert();
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    function testRevert_ExecuteAllocate_DepositExceedsCap() public {
        allocate.setTokenCap(usdc, 200e6);
        _registerMasterAccount();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 150e6;
        amountList[1] = 150e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        vm.expectRevert(abi.encodeWithSelector(Error.Allocate__DepositExceedsCap.selector, 300e6, 200e6));
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    // ============ Withdrawal Tests ============

    function testExecuteWithdraw_TransfersTokens() public {
        _registerMasterAccount();

        // First allocate some funds
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory allocAttestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, allocAttestation);

        // Now withdraw
        uint256 userBalanceBefore = usdc.balanceOf(address(puppet1));

        Allocate.WithdrawAttestation memory withdrawAttestation =
            _createWithdrawAttestation(address(puppet1), master, 250e6, 1e30);

        allocate.withdraw(withdrawAttestation);

        assertEq(usdc.balanceOf(address(puppet1)), userBalanceBefore + 250e6);
    }

    function testExecuteWithdraw_BurnsShares() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory allocAttestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, allocAttestation);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));
        uint256 sharesBefore = compact.balanceOf(address(puppet1), tokenId);

        Allocate.WithdrawAttestation memory withdrawAttestation =
            _createWithdrawAttestation(address(puppet1), master, 250e6, 1e30);

        allocate.withdraw(withdrawAttestation);

        uint256 sharesAfter = compact.balanceOf(address(puppet1), tokenId);
        assertEq(sharesBefore - sharesAfter, 250e6); // At 1:1, 250 tokens = 250 shares burned
    }

    function testExecuteWithdraw_ProfitableSharePrice() public {
        _registerMasterAccount();

        // Allocate at 1:1
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory allocAttestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, allocAttestation);

        // Simulate profit: master account gains 500e6
        usdc.mint(address(master), 500e6);

        // Withdraw at new share price (2:1 - each share worth 2 tokens now)
        // User has 500 shares, worth 1000 tokens total
        // Withdraw 500 tokens = burn 250 shares
        uint256 userBalanceBefore = usdc.balanceOf(address(puppet1));

        Allocate.WithdrawAttestation memory withdrawAttestation =
            _createWithdrawAttestation(address(puppet1), master, 500e6, 2e30);

        allocate.withdraw(withdrawAttestation);

        assertEq(usdc.balanceOf(address(puppet1)), userBalanceBefore + 500e6);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));
        assertEq(compact.balanceOf(address(puppet1), tokenId), 250e6); // 500 - 250 burned
    }

    function testRevert_ExecuteWithdraw_InsufficientBalance() public {
        _registerMasterAccount();

        // Allocate small amount
        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        Allocate.AllocateAttestation memory allocAttestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, allocAttestation);

        // Try to withdraw more shares than owned
        Allocate.WithdrawAttestation memory withdrawAttestation =
            _createWithdrawAttestation(address(puppet1), master, 200e6, 1e30);

        vm.expectRevert(Error.Allocate__InsufficientBalance.selector);
        allocate.withdraw(withdrawAttestation);
    }

    function testRevert_ExecuteWithdraw_InsufficientLiquidity() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory allocAttestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, allocAttestation);

        // Simulate loss: drain master account
        vm.stopPrank();
        vm.prank(address(master));
        usdc.transfer(address(1), 400e6);
        vm.startPrank(users.owner);

        // Try to withdraw more than available liquidity
        Allocate.WithdrawAttestation memory withdrawAttestation =
            _createWithdrawAttestation(address(puppet1), master, 200e6, 1e30);

        vm.expectRevert(Error.Allocate__InsufficientLiquidity.selector);
        allocate.withdraw(withdrawAttestation);
    }

    // ============ Dispose Tests ============

    function testDisposeMasterAccount() public {
        _registerMasterAccount();

        allocate.disposeMaster(master);

        MasterInfo memory info = allocate.getMasterInfo(master);
        assertTrue(info.disposed);
    }

    function testRevert_ExecuteAllocate_DisposedMasterAccount() public {
        _registerMasterAccount();
        allocate.disposeMaster(master);

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 100e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        vm.expectRevert(Error.Allocate__MasterDisposed.selector);
        allocate.allocate(matcher, master, puppetList, amountList, attestation);
    }

    // ============ Fair Distribution Tests ============

    function testFairDistribution_ProportionalShares() public {
        _registerMasterAccount();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 300e6;
        amountList[1] = 300e6;

        Allocate.AllocateAttestation memory attestation =
            _createAllocateAttestation(master, 1e30, puppetList, amountList);

        allocate.allocate(matcher, master, puppetList, amountList, attestation);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));

        assertEq(compact.balanceOf(address(puppet1), tokenId), compact.balanceOf(address(puppet2), tokenId));
    }

    function testFairDistribution_LateDepositorPaysHigherPrice() public {
        _registerMasterAccount();

        // First allocation at 1:1
        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = address(puppet1);

        uint256[] memory amountList1 = new uint256[](1);
        amountList1[0] = 500e6;

        Allocate.AllocateAttestation memory attestation1 =
            _createAllocateAttestation(master, 1e30, puppetList1, amountList1);

        allocate.allocate(matcher, master, puppetList1, amountList1, attestation1);

        // Simulate profit
        usdc.mint(address(master), 500e6);

        // Skip throttle period
        vm.warp(block.timestamp + 7 hours);

        // Second allocation at higher price (2:1)
        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = address(puppet2);

        uint256[] memory amountList2 = new uint256[](1);
        amountList2[0] = 500e6;

        Allocate.AllocateAttestation memory attestation2 =
            _createAllocateAttestation(master, 2e30, puppetList2, amountList2);

        allocate.allocate(matcher, master, puppetList2, amountList2, attestation2);

        uint256 tokenId = _computeTokenId(address(master), address(usdc));

        // Puppet1 deposited 500 at 1:1 = 500 shares
        // Puppet2 deposited 500 at 2:1 = 250 shares
        assertEq(compact.balanceOf(address(puppet1), tokenId), 500e6);
        assertEq(compact.balanceOf(address(puppet2), tokenId), 250e6);
    }
}
