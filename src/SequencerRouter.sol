// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Account} from "./position/Account.sol";
import {Mirror} from "./position/Mirror.sol";
import {Rule} from "./position/Rule.sol";
import {Settle} from "./position/Settle.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

/**
 * @title SequencerRouter
 * @notice Routes sequencer operations to the appropriate contracts
 * @dev Simplified design without callbacks - sequencer is source of truth for position state
 */
contract SequencerRouter is CoreContract {
    struct Config {
        uint openBaseGasLimit;
        uint openPerPuppetGasLimit;
        uint adjustBaseGasLimit;
        uint adjustPerPuppetGasLimit;
        uint settleBaseGasLimit;
        uint settlePerPuppetGasLimit;
        uint gasPriceBufferBasisPoints; // e.g. 12000 = 120% (20% buffer)
    }

    Rule public immutable ruleContract;
    Mirror public immutable mirror;
    Settle public immutable settle;
    Account public immutable account;

    Config config;

    constructor(
        IAuthority _authority,
        Account _account,
        Rule _ruleContract,
        Mirror _mirror,
        Settle _settle,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        if (address(_account) == address(0)) revert("Account not set correctly");
        if (address(_ruleContract) == address(0)) revert("Rule contract not set correctly");
        if (address(_mirror) == address(0)) revert("Mirror not set correctly");
        if (address(_settle) == address(0)) revert("Settle not set correctly");

        mirror = _mirror;
        ruleContract = _ruleContract;
        settle = _settle;
        account = _account;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function requestOpen(
        Mirror.CallParams calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (address _allocationAddress, bytes32 _requestKey) {
        return mirror.requestOpen{value: msg.value}(account, ruleContract, _callParams, _puppetList);
    }

    function requestAdjust(
        Mirror.CallParams calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32 _requestKey) {
        return mirror.requestAdjust{value: msg.value}(account, _callParams, _puppetList);
    }

    function requestClose(
        Mirror.CallParams calldata _callParams,
        address[] calldata _puppetList,
        uint8 _reason
    ) external payable auth returns (bytes32 _requestKey) {
        return mirror.requestClose{value: msg.value}(account, _callParams, _puppetList, _reason);
    }

    /**
     * @notice Settles an allocation by distributing funds back to puppets
     */
    function settleAllocation(
        Settle.CallSettle calldata _settleParams,
        address[] calldata _puppetList
    ) external auth returns (uint distributionAmount, uint platformFeeAmount) {
        return settle.settle(account, mirror, _settleParams, _puppetList);
    }

    /**
     * @notice Collects dust tokens from an allocation account
     */
    function collectAllocationAccountDust(
        address _allocationAccount,
        IERC20 _dustToken,
        address _receiver,
        uint _amount
    ) external auth returns (uint) {
        return settle.collectAllocationAccountDust(account, _allocationAccount, _dustToken, _receiver, _amount);
    }

    /**
     * @notice Recovers unaccounted tokens sent to AccountStore outside normal flows
     */
    function recoverUnaccountedTokens(
        IERC20 _token,
        address _receiver,
        uint _amount
    ) external auth {
        account.recoverUnaccountedTokens(_token, _receiver, _amount);
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.openBaseGasLimit == 0) revert("Invalid open base gas limit");
        if (_config.openPerPuppetGasLimit == 0) revert("Invalid open per-puppet gas limit");
        if (_config.adjustBaseGasLimit == 0) revert("Invalid adjust base gas limit");
        if (_config.adjustPerPuppetGasLimit == 0) revert("Invalid adjust per-puppet gas limit");
        if (_config.gasPriceBufferBasisPoints < 10000) revert("Gas buffer must be >= 100%");

        config = _config;
    }
}
