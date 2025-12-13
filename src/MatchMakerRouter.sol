// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Account} from "./position/Account.sol";
import {Mirror} from "./position/Mirror.sol";
import {Settle} from "./position/Settle.sol";
import {Subscribe} from "./position/Subscribe.sol";
import {FeeMarketplace} from "./shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "./shared/FeeMarketplaceStore.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract MatchmakerRouter is CoreContract {
    struct Config {
        address feeReceiver;
        uint matchBaseGasLimit;
        uint matchPerPuppetGasLimit;
        uint adjustBaseGasLimit;
        uint adjustPerPuppetGasLimit;
        uint settleBaseGasLimit;
        uint settlePerPuppetGasLimit;
        uint gasPriceBufferBasisPoints;
        uint maxEthPriceAge;
        uint maxIndexPriceAge;
        uint maxFiatPriceAge;
        uint maxGasAge;
        uint stalledCheckInterval;
        uint stalledPositionThreshold;
        uint minMatchTraderCollateral;
        uint minAllocationUsd;
        uint minAdjustUsd;
    }

    Subscribe public immutable subscribe;
    Mirror public immutable mirror;
    Settle public immutable settle;
    Account public immutable account;
    FeeMarketplace public immutable feeMarketplace;
    FeeMarketplaceStore public immutable feeMarketplaceStore;

    Config config;

    constructor(
        IAuthority _authority,
        Account _account,
        Subscribe _subscribe,
        Mirror _mirror,
        Settle _settle,
        FeeMarketplace _feeMarketplace,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        if (address(_account) == address(0)) revert("Account not set correctly");
        if (address(_subscribe) == address(0)) revert("Subscribe contract not set correctly");
        if (address(_mirror) == address(0)) revert("Mirror not set correctly");
        if (address(_settle) == address(0)) revert("Settle not set correctly");
        if (address(_feeMarketplace) == address(0)) revert("FeeMarketplace not set correctly");

        mirror = _mirror;
        subscribe = _subscribe;
        settle = _settle;
        account = _account;
        feeMarketplace = _feeMarketplace;
        feeMarketplaceStore = _feeMarketplace.store();
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function matchmake(
        Mirror.CallPosition calldata _callMatch,
        address[] calldata _puppetList
    ) external payable returns (address _allocationAddress, bytes32 _requestKey) {
        return mirror.matchmake{value: msg.value}(account, subscribe, _callMatch, _puppetList, config.feeReceiver);
    }

    function adjust(
        Mirror.CallPosition calldata _callPosition,
        address[] calldata _puppetList
    ) external payable returns (bytes32 _requestKey) {
        return mirror.adjust{value: msg.value}(account, _callPosition, _puppetList, config.feeReceiver);
    }

    function close(
        Mirror.CallPosition calldata _callPosition,
        address[] calldata _puppetList,
        uint8 _reason
    ) external payable returns (bytes32 _requestKey) {
        return mirror.close{value: msg.value}(account, _callPosition, _puppetList, _reason, config.feeReceiver);
    }

    function settleAllocation(
        Settle.CallSettle calldata _settleParams,
        address[] calldata _puppetList
    ) external returns (uint distributionAmount, uint platformFeeAmount) {
        return settle.settle(account, mirror, _settleParams, _puppetList);
    }

    function collectAllocationAccountDust(
        address _allocationAccount,
        IERC20 _dustToken,
        address _receiver,
        uint _amount
    ) external auth returns (uint) {
        return settle.collectAllocationAccountDust(account, _allocationAccount, _dustToken, _receiver, _amount);
    }

    function collectAndDepositPlatformFees(IERC20 _token, uint _amount) external {
        settle.collectPlatformFees(account, _token, address(feeMarketplaceStore), _amount);
        feeMarketplace.recordTransferIn(_token);
    }

    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.feeReceiver == address(0)) revert("Invalid fee receiver");
        if (_config.matchBaseGasLimit == 0) revert("Invalid match base gas limit");
        if (_config.matchPerPuppetGasLimit == 0) revert("Invalid match per-puppet gas limit");
        if (_config.adjustBaseGasLimit == 0) revert("Invalid adjust base gas limit");
        if (_config.adjustPerPuppetGasLimit == 0) revert("Invalid adjust per-puppet gas limit");
        if (_config.gasPriceBufferBasisPoints < 10000) revert("Gas buffer must be >= 100%");

        config = _config;
    }
}
