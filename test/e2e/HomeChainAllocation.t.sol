// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/module-bases/utils/ERC7579Constants.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Withdraw} from "src/withdraw/Withdraw.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {TestSmartAccount} from "../mock/TestSmartAccount.t.sol";
import {MockAllocator} from "../mock/MockAllocator.t.sol";

contract HomeChainAllocationTest is BasicSetup {
    Allocate allocate;
    Match matcher;
    TokenRouter tokenRouter;
    Withdraw withdraw;
    MockAllocator mockAllocator;

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

    function setUp() public override {
        super.setUp();

        owner = vm.addr(ownerPrivateKey);
        signer = vm.addr(signerPrivateKey);

        mockAllocator = new MockAllocator(ATTESTOR_PRIVATE_KEY);

        matcher = new Match(dictator, Match.Config({minThrottlePeriod: 6 hours}));
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config({transferGasLimit: GAS_LIMIT}));

        allocate = new Allocate(
            dictator,
            Allocate.Config({
                attestor: mockAllocator.attestorAddress(),
                maxBlockStaleness: 240,
                maxTimestampAge: 60
            })
        );

        withdraw = new Withdraw(
            dictator,
            Withdraw.Config({
                attestor: mockAllocator.attestorAddress(),
                gasLimit: GAS_LIMIT
            })
        );

        dictator.registerContract(address(matcher));
        dictator.registerContract(address(tokenRouter));
        dictator.registerContract(address(allocate));
        dictator.registerContract(address(withdraw));

        dictator.setPermission(allocate, allocate.setCodeHash.selector, users.owner);
        dictator.setPermission(allocate, allocate.createMaster.selector, users.owner);
        dictator.setPermission(allocate, allocate.allocate.selector, users.owner);
        dictator.setPermission(allocate, allocate.setTokenCap.selector, users.owner);
        dictator.setPermission(allocate, allocate.disposeMaster.selector, users.owner);
        dictator.setPermission(matcher, matcher.recordMatchAmountList.selector, address(allocate));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocate));

        allocate.setCodeHash(keccak256(type(TestSmartAccount).runtimeCode), true);

        master = new TestSmartAccount();
        puppet1 = new TestSmartAccount();
        puppet2 = new TestSmartAccount();

        master.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        master.installModule(MODULE_TYPE_EXECUTOR, address(withdraw), "");
        puppet1.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");
        puppet2.installModule(MODULE_TYPE_EXECUTOR, address(allocate), "");

        allocate.setTokenCap(usdc, TOKEN_CAP);

        usdc.mint(address(puppet1), 1000e6);
        usdc.mint(address(puppet2), 1000e6);
        usdc.mint(owner, 1000e6);

        vm.stopPrank();

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
        allocate.createMaster(owner, signer, master, usdc, MASTER_NAME);
    }

    function testE2E_MasterOnlyAllocation() public {
        _registerMaster();

        address[] memory emptyPuppetList = new address[](0);
        uint256[] memory emptyAmountList = new uint256[](0);

        uint256 masterAmount = 500e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, masterAmount, emptyPuppetList, emptyAmountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, emptyPuppetList, emptyAmountList, attestation);

        assertEq(usdc.balanceOf(address(master)), masterAmount);
        assertEq(usdc.balanceOf(owner), 1000e6 - masterAmount);
    }

    function testE2E_PuppetOnlyAllocation() public {
        _registerMaster();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 200e6;
        amountList[1] = 300e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation);

        assertEq(usdc.balanceOf(address(master)), 500e6);
        assertEq(usdc.balanceOf(address(puppet1)), 800e6);
        assertEq(usdc.balanceOf(address(puppet2)), 700e6);
    }

    function testE2E_MixedAllocation() public {
        _registerMaster();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 200e6;
        amountList[1] = 300e6;

        uint256 masterAmount = 500e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, masterAmount, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation);

        assertEq(usdc.balanceOf(address(master)), 1000e6);
        assertEq(usdc.balanceOf(owner), 500e6);
        assertEq(usdc.balanceOf(address(puppet1)), 800e6);
        assertEq(usdc.balanceOf(address(puppet2)), 700e6);
    }

    function testE2E_MultipleAllocationRounds() public {
        _registerMaster();

        address[] memory puppetList1 = new address[](1);
        puppetList1[0] = address(puppet1);

        uint256[] memory amountList1 = new uint256[](1);
        amountList1[0] = 500e6;

        Allocate.AllocateAttestation memory attestation1 = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList1, amountList1, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList1, amountList1, attestation1);

        assertEq(usdc.balanceOf(address(master)), 500e6);

        usdc.mint(address(master), 500e6);

        vm.warp(block.timestamp + 25200);
        vm.roll(block.number + 100);

        address[] memory puppetList2 = new address[](1);
        puppetList2[0] = address(puppet2);

        uint256[] memory amountList2 = new uint256[](1);
        amountList2[0] = 500e6;

        uint256 newSharePrice = 2 * Precision.FLOAT_PRECISION;

        Allocate.AllocateAttestation memory attestation2 = _signAttestation(
            master, newSharePrice, 0, puppetList2, amountList2, 1
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList2, amountList2, attestation2);

        assertEq(usdc.balanceOf(address(master)), 1500e6);
    }

    function testE2E_MasterAllocatesAfterProfit() public {
        _registerMaster();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory attestation1 = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation1);

        usdc.mint(address(master), 500e6);

        vm.warp(block.timestamp + 25200);
        vm.roll(block.number + 100);

        address[] memory emptyPuppetList = new address[](0);
        uint256[] memory emptyAmountList = new uint256[](0);

        uint256 newSharePrice = 2 * Precision.FLOAT_PRECISION;
        uint256 masterAmount = 500e6;

        Allocate.AllocateAttestation memory attestation2 = _signAttestation(
            master, newSharePrice, masterAmount, emptyPuppetList, emptyAmountList, 1
        );

        allocate.allocate(tokenRouter, matcher, master, emptyPuppetList, emptyAmountList, attestation2);

        assertEq(usdc.balanceOf(address(master)), 1500e6);
        assertEq(usdc.balanceOf(owner), 500e6);
    }

    function _signAttestation(
        IERC7579Account _master,
        uint256 _sharePrice,
        uint256 _masterAmount,
        address[] memory _puppetList,
        uint256[] memory _amountList,
        uint256 _nonce
    ) internal view returns (Allocate.AllocateAttestation memory) {
        return _signAttestationWithBlock(
            _master, _sharePrice, _masterAmount, _puppetList, _amountList, _nonce,
            block.number, block.timestamp
        );
    }

    function _signAttestationWithBlock(
        IERC7579Account _master,
        uint256 _sharePrice,
        uint256 _masterAmount,
        address[] memory _puppetList,
        uint256[] memory _amountList,
        uint256 _nonce,
        uint256 _blockNumber,
        uint256 _blockTimestamp
    ) internal view returns (Allocate.AllocateAttestation memory) {
        bytes32 puppetListHash = keccak256(abi.encodePacked(_puppetList));
        bytes32 amountListHash = keccak256(abi.encodePacked(_amountList));

        uint256 deadline = _blockTimestamp + 3600;

        bytes32 structHash = keccak256(
            abi.encode(
                allocate.ALLOCATE_ATTESTATION_TYPEHASH(),
                _master,
                _sharePrice,
                _masterAmount,
                puppetListHash,
                amountListHash,
                _blockNumber,
                _blockTimestamp,
                _nonce,
                deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Allocate"),
                keccak256("1"),
                block.chainid,
                address(allocate)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ATTESTOR_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return Allocate.AllocateAttestation({
            master: _master,
            sharePrice: _sharePrice,
            masterAmount: _masterAmount,
            puppetListHash: puppetListHash,
            amountListHash: amountListHash,
            blockNumber: _blockNumber,
            blockTimestamp: _blockTimestamp,
            nonce: _nonce,
            deadline: deadline,
            signature: signature
        });
    }

    // ============ Withdrawal Tests ============

    function testE2E_PuppetWithdrawAfterAllocation() public {
        _registerMaster();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation);

        assertEq(usdc.balanceOf(address(master)), 500e6);
        assertEq(usdc.balanceOf(address(puppet1)), 500e6);

        uint256 sharesToWithdraw = 250e6;
        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 expectedAmount = Precision.applyFactor(sharePrice, sharesToWithdraw);

        (
            Withdraw.WithdrawIntent memory intent,
            Withdraw.WithdrawAttestation memory withdrawAttestation,
            bytes memory intentSig,
            bytes memory attestationSig
        ) = _signWithdrawIntent(address(puppet1), sharesToWithdraw, sharePrice, 0);

        uint256 puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        withdraw.withdraw(intent, withdrawAttestation, intentSig, attestationSig);

        assertEq(usdc.balanceOf(address(puppet1)), puppet1BalanceBefore + expectedAmount);
        assertEq(usdc.balanceOf(address(master)), 500e6 - expectedAmount);
    }

    function testE2E_MasterWithdrawAfterAllocation() public {
        _registerMaster();

        address[] memory emptyPuppetList = new address[](0);
        uint256[] memory emptyAmountList = new uint256[](0);

        uint256 masterAmount = 500e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, masterAmount, emptyPuppetList, emptyAmountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, emptyPuppetList, emptyAmountList, attestation);

        assertEq(usdc.balanceOf(address(master)), masterAmount);
        assertEq(usdc.balanceOf(owner), 500e6);

        uint256 sharesToWithdraw = 250e6;
        uint256 sharePrice = Precision.FLOAT_PRECISION;
        uint256 expectedAmount = Precision.applyFactor(sharePrice, sharesToWithdraw);

        (
            Withdraw.WithdrawIntent memory intent,
            Withdraw.WithdrawAttestation memory withdrawAttestation,
            bytes memory intentSig,
            bytes memory attestationSig
        ) = _signWithdrawIntent(owner, sharesToWithdraw, sharePrice, 0);

        uint256 ownerBalanceBefore = usdc.balanceOf(owner);

        withdraw.withdraw(intent, withdrawAttestation, intentSig, attestationSig);

        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + expectedAmount);
        assertEq(usdc.balanceOf(address(master)), masterAmount - expectedAmount);
    }

    function testE2E_WithdrawAfterProfit() public {
        _registerMaster();

        address[] memory puppetList = new address[](1);
        puppetList[0] = address(puppet1);

        uint256[] memory amountList = new uint256[](1);
        amountList[0] = 500e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation);

        usdc.mint(address(master), 500e6);

        uint256 sharesToWithdraw = 250e6;
        uint256 sharePrice = 2 * Precision.FLOAT_PRECISION;
        uint256 expectedAmount = Precision.applyFactor(sharePrice, sharesToWithdraw);

        (
            Withdraw.WithdrawIntent memory intent,
            Withdraw.WithdrawAttestation memory withdrawAttestation,
            bytes memory intentSig,
            bytes memory attestationSig
        ) = _signWithdrawIntent(address(puppet1), sharesToWithdraw, sharePrice, 0);

        uint256 puppet1BalanceBefore = usdc.balanceOf(address(puppet1));

        withdraw.withdraw(intent, withdrawAttestation, intentSig, attestationSig);

        assertEq(usdc.balanceOf(address(puppet1)), puppet1BalanceBefore + expectedAmount);
    }

    function testE2E_MultipleWithdrawals() public {
        _registerMaster();

        address[] memory puppetList = new address[](2);
        puppetList[0] = address(puppet1);
        puppetList[1] = address(puppet2);

        uint256[] memory amountList = new uint256[](2);
        amountList[0] = 300e6;
        amountList[1] = 200e6;

        Allocate.AllocateAttestation memory attestation = _signAttestation(
            master, Precision.FLOAT_PRECISION, 0, puppetList, amountList, 0
        );

        allocate.allocate(tokenRouter, matcher, master, puppetList, amountList, attestation);

        assertEq(usdc.balanceOf(address(master)), 500e6);

        uint256 sharePrice = Precision.FLOAT_PRECISION;

        (
            Withdraw.WithdrawIntent memory intent1,
            Withdraw.WithdrawAttestation memory attestation1,
            bytes memory intentSig1,
            bytes memory attestationSig1
        ) = _signWithdrawIntent(address(puppet1), 150e6, sharePrice, 0);

        withdraw.withdraw(intent1, attestation1, intentSig1, attestationSig1);

        assertEq(usdc.balanceOf(address(puppet1)), 700e6 + 150e6);
        assertEq(usdc.balanceOf(address(master)), 350e6);

        (
            Withdraw.WithdrawIntent memory intent2,
            Withdraw.WithdrawAttestation memory attestation2,
            bytes memory intentSig2,
            bytes memory attestationSig2
        ) = _signWithdrawIntent(address(puppet2), 100e6, sharePrice, 1);

        withdraw.withdraw(intent2, attestation2, intentSig2, attestationSig2);

        assertEq(usdc.balanceOf(address(puppet2)), 800e6 + 100e6);
        assertEq(usdc.balanceOf(address(master)), 250e6);
    }

    // ============ Withdrawal Helper Functions ============

    uint256 constant PUPPET1_PRIVATE_KEY = 0xABCD1;
    uint256 constant PUPPET2_PRIVATE_KEY = 0xABCD2;

    function _signWithdrawIntent(
        address _user,
        uint256 _shares,
        uint256 _sharePrice,
        uint256 _nonce
    ) internal view returns (
        Withdraw.WithdrawIntent memory intent,
        Withdraw.WithdrawAttestation memory attestation,
        bytes memory intentSig,
        bytes memory attestationSig
    ) {
        uint256 currentTimestamp;
        uint256 deadline;
        assembly {
            currentTimestamp := timestamp()
            deadline := add(currentTimestamp, 3600)
        }
        uint256 amount = Precision.applyFactor(_sharePrice, _shares);

        intent = Withdraw.WithdrawIntent({
            user: _user,
            master: address(master),
            token: address(usdc),
            shares: _shares,
            acceptableSharePrice: _sharePrice,
            minAmountOut: amount,
            nonce: _nonce,
            deadline: deadline
        });

        attestation = Withdraw.WithdrawAttestation({
            user: _user,
            master: address(master),
            token: address(usdc),
            shares: _shares,
            sharePrice: _sharePrice,
            nonce: _nonce,
            deadline: deadline
        });

        bytes32 intentDigest = _computeWithdrawIntentDigest(intent);
        bytes32 attestationDigest = _computeWithdrawAttestationDigest(attestation);

        uint256 userKey = _getUserPrivateKey(_user);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(userKey, intentDigest);
        intentSig = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(ATTESTOR_PRIVATE_KEY, attestationDigest);
        attestationSig = abi.encodePacked(r2, s2, v2);
    }

    function _getUserPrivateKey(address _user) internal view returns (uint256) {
        if (_user == address(puppet1)) return PUPPET1_PRIVATE_KEY;
        if (_user == address(puppet2)) return PUPPET2_PRIVATE_KEY;
        if (_user == owner) return ownerPrivateKey;
        revert("Unknown user");
    }

    function _computeWithdrawIntentDigest(Withdraw.WithdrawIntent memory intent) internal view returns (bytes32) {
        bytes32 typeHash = withdraw.INTENT_TYPEHASH();
        bytes32 structHash = keccak256(abi.encode(
            typeHash,
            intent.user,
            intent.master,
            intent.token,
            intent.shares,
            intent.acceptableSharePrice,
            intent.minAmountOut,
            intent.nonce,
            intent.deadline
        ));

        return keccak256(abi.encodePacked("\x19\x01", _withdrawDomainSeparator(), structHash));
    }

    function _computeWithdrawAttestationDigest(Withdraw.WithdrawAttestation memory attestation) internal view returns (bytes32) {
        bytes32 typeHash = withdraw.ATTESTATION_TYPEHASH();
        bytes32 structHash = keccak256(abi.encode(
            typeHash,
            attestation.user,
            attestation.master,
            attestation.token,
            attestation.shares,
            attestation.sharePrice,
            attestation.nonce,
            attestation.deadline
        ));

        return keccak256(abi.encodePacked("\x19\x01", _withdrawDomainSeparator(), structHash));
    }

    function _withdrawDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Withdraw"),
                keccak256("1"),
                block.chainid,
                address(withdraw)
            )
        );
    }
}
