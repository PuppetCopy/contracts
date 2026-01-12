// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Vm} from "forge-std/src/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Registry} from "src/account/Registry.sol";
import {Precision} from "src/utils/Precision.sol";

contract MockAllocator {
    uint256 public attestorPrivateKey;
    address public attestorAddress;

    uint256 public nonceCounter;

    mapping(IERC7579Account master => uint256) public totalSharesMap;
    mapping(IERC7579Account master => mapping(address user => uint256)) public sharesMap;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    constructor(uint256 _privateKey) {
        attestorPrivateKey = _privateKey;
        attestorAddress = vm.addr(_privateKey);
    }

    function getShares(IERC7579Account _master, address _user) external view returns (uint256) {
        return sharesMap[_master][_user];
    }

    function getTotalShares(IERC7579Account _master) external view returns (uint256) {
        return totalSharesMap[_master];
    }

    function calculateSharePrice(IERC7579Account _master, IERC20 _baseToken) public view returns (uint256) {
        uint256 _totalShares = totalSharesMap[_master];
        if (_totalShares == 0) return Precision.FLOAT_PRECISION;

        uint256 _balance = _baseToken.balanceOf(address(_master));
        return Precision.toFactor(_balance, _totalShares);
    }

    function allocate(
        Allocate _allocate,
        Registry _registry,
        TokenRouter _tokenRouter,
        Match _matcher,
        IERC7579Account _master,
        IERC20 _baseToken,
        uint256 _masterAmount,
        address[] memory _puppetList,
        uint256[] memory _amountList
    ) external returns (uint256 allocated) {
        uint256 _sharePrice = calculateSharePrice(_master, _baseToken);
        uint256 _nonce = nonceCounter++;

        Allocate.AllocateAttestation memory _attestation = _signAttestation(
            _allocate, _master, _sharePrice, _masterAmount, _puppetList, _amountList, _nonce
        );

        uint256 _balanceBefore = _baseToken.balanceOf(address(_master));

        _allocate.allocate(_registry, _tokenRouter, _matcher, _master, _puppetList, _amountList, _attestation);

        allocated = _baseToken.balanceOf(address(_master)) - _balanceBefore;

        _updateShares(_registry, _master, _baseToken, _masterAmount, _puppetList, _amountList, _sharePrice);
    }

    function allocateMasterOnly(
        Allocate _allocate,
        Registry _registry,
        TokenRouter _tokenRouter,
        Match _matcher,
        IERC7579Account _master,
        IERC20 _baseToken,
        uint256 _masterAmount
    ) external returns (uint256 allocated) {
        address[] memory _emptyPuppetList = new address[](0);
        uint256[] memory _emptyAmountList = new uint256[](0);

        uint256 _sharePrice = calculateSharePrice(_master, _baseToken);
        uint256 _nonce = nonceCounter++;

        Allocate.AllocateAttestation memory _attestation = _signAttestation(
            _allocate, _master, _sharePrice, _masterAmount, _emptyPuppetList, _emptyAmountList, _nonce
        );

        uint256 _balanceBefore = _baseToken.balanceOf(address(_master));

        _allocate.allocate(_registry, _tokenRouter, _matcher, _master, _emptyPuppetList, _emptyAmountList, _attestation);

        allocated = _baseToken.balanceOf(address(_master)) - _balanceBefore;

        if (_masterAmount > 0) {
            uint256 _masterShares = Precision.toFactor(_masterAmount, _sharePrice);
            address _user = _registry.getMasterInfo(_master).user;
            sharesMap[_master][_user] += _masterShares;
            totalSharesMap[_master] += _masterShares;
        }
    }

    function _updateShares(
        Registry _registry,
        IERC7579Account _master,
        IERC20 _baseToken,
        uint256 _masterAmount,
        address[] memory _puppetList,
        uint256[] memory _amountList,
        uint256 _sharePrice
    ) internal {
        if (_masterAmount > 0) {
            uint256 _masterShares = Precision.toFactor(_masterAmount, _sharePrice);
            address _user = _registry.getMasterInfo(_master).user;
            sharesMap[_master][_user] += _masterShares;
            totalSharesMap[_master] += _masterShares;
        }

        for (uint256 i; i < _puppetList.length; ++i) {
            if (_amountList[i] == 0) continue;

            uint256 _balance = _baseToken.balanceOf(_puppetList[i]);
            if (_balance < _amountList[i]) continue;

            uint256 _shares = Precision.toFactor(_amountList[i], _sharePrice);
            if (_shares == 0) continue;

            sharesMap[_master][_puppetList[i]] += _shares;
            totalSharesMap[_master] += _shares;
        }
    }

    function _signAttestation(
        Allocate _allocate,
        IERC7579Account _master,
        uint256 _sharePrice,
        uint256 _masterAmount,
        address[] memory _puppetList,
        uint256[] memory _amountList,
        uint256 _nonce
    ) internal view returns (Allocate.AllocateAttestation memory) {
        bytes32 _puppetListHash = keccak256(abi.encodePacked(_puppetList));
        bytes32 _amountListHash = keccak256(abi.encodePacked(_amountList));

        uint256 _currentBlock = block.number;
        uint256 _currentTimestamp = block.timestamp;
        uint256 _deadline = _currentTimestamp + 1 hours;

        bytes32 _structHash = keccak256(
            abi.encode(
                _allocate.ALLOCATE_ATTESTATION_TYPEHASH(),
                _master,
                _sharePrice,
                _masterAmount,
                _puppetListHash,
                _amountListHash,
                _currentBlock,
                _currentTimestamp,
                _nonce,
                _deadline
            )
        );

        bytes32 _domainSeparator = _computeDomainSeparator(address(_allocate));
        bytes32 _digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorPrivateKey, _digest);
        bytes memory _signature = abi.encodePacked(r, s, v);

        return Allocate.AllocateAttestation({
            master: _master,
            sharePrice: _sharePrice,
            masterAmount: _masterAmount,
            puppetListHash: _puppetListHash,
            amountListHash: _amountListHash,
            blockNumber: _currentBlock,
            blockTimestamp: _currentTimestamp,
            nonce: _nonce,
            deadline: _deadline,
            signature: _signature
        });
    }

    function _computeDomainSeparator(address _verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Puppet Allocate"),
                keccak256("1"),
                block.chainid,
                _verifyingContract
            )
        );
    }
}
