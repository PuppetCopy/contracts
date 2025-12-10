// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Account} from "./position/Account.sol";
import {Mirror} from "./position/Mirror.sol";
import {Rule} from "./position/Rule.sol";
import {Settle} from "./position/Settle.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {Error} from "./utils/Error.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

/**
 * @notice Handles sequencer-specific operations for the copy trading system
 * @dev Separates sequencer operations from user operations for better security and access control
 */
contract SequencerRouter is CoreContract, IGmxOrderCallbackReceiver {
    struct Config {
        uint openBaseGasLimit;
        uint openPerPuppetGasLimit;
        uint adjustBaseGasLimit;
        uint adjustPerPuppetGasLimit;
        uint settleBaseGasLimit;
        uint settlePerPuppetGasLimit;
        address fallbackRefundExecutionFeeReceiver;
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

    /**
     * @notice Get gas configuration for sequencer operations
     * @return Current gas configuration
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Orchestrates mirror position creation by coordinating Allocation and Mirror
     * @param _callParams Position parameters for the trader's position
     * @param _puppetList List of puppet addresses to mirror the position
     * @return _allocationAddress The allocation address created for the position
     * @return _requestKey The GMX request key for the submitted position
     */
    function requestOpen(
        Mirror.CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (address _allocationAddress, bytes32 _requestKey) {
        return mirror.requestOpen{value: msg.value}(account, ruleContract, address(this), _callParams, _puppetList);
    }

    /**
     * @notice Orchestrates position adjustment by coordinating Allocation and Mirror
     * @param _callParams Position parameters for the trader's adjustment and allocation
     * @param _puppetList List of puppet addresses involved in the position
     * @return _requestKey The GMX request key for the submitted adjustment
     */
    function requestAdjust(
        Mirror.CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32 _requestKey) {
        return mirror.requestAdjust{value: msg.value}(account, address(this), _callParams, _puppetList);
    }

    /**
     * @notice Closes a stalled position where the trader has exited but puppet position remains
     * @param _params Position parameters for the stalled position
     * @param _puppetList The list of puppet addresses in the allocation
     * @return _requestKey The GMX request key for the close order
     */
    function requestCloseStalled(
        Mirror.StalledPositionParams calldata _params,
        address[] calldata _puppetList
    ) external payable auth returns (bytes32) {
        return mirror.requestCloseStalled{value: msg.value}(account, _params, _puppetList, address(this));
    }

    /**
     * @notice Settles an allocation by distributing funds back to puppets
     * @param _settleParams Settlement parameters
     * @param _puppetList List of puppet addresses involved
     * @return distributionAmount Amount distributed to puppets
     * @return platformFeeAmount Platform fee collected
     */
    function settleAllocation(
        Settle.CallSettle calldata _settleParams,
        address[] calldata _puppetList
    ) external auth returns (uint distributionAmount, uint platformFeeAmount) {
        return settle.settle(account, mirror, _settleParams, _puppetList);
    }

    /**
     * @notice Collects dust tokens from an allocation account
     * @param _allocationAccount The allocation account to collect dust from
     * @param _dustToken The token to collect
     * @param _receiver The address to receive the dust
     * @param _amount The amount of dust to collect
     * @return The amount of dust collected
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
     * @notice Recovers unaccounted tokens that were sent to AccountStore outside normal flows
     * @param _token The token to recover
     * @param _receiver The address to receive recovered tokens
     * @param _amount The amount to recover
     */
    function recoverUnaccountedTokens(
        IERC20 _token,
        address _receiver,
        uint _amount
    ) external auth {
        account.recoverUnaccountedTokens(_token, _receiver, _amount);
    }

    /**
     * @notice Internal function to set gas configuration
     * @param _data Encoded configuration data containing the Config struct
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.openBaseGasLimit == 0) revert("Invalid mirror base gas limit");
        if (_config.openPerPuppetGasLimit == 0) revert("Invalid mirror per-puppet gas limit");
        if (_config.adjustBaseGasLimit == 0) revert("Invalid adjust base gas limit");
        if (_config.adjustPerPuppetGasLimit == 0) revert("Invalid adjust per-puppet gas limit");

        config = _config;
    }

    /**
     * @notice GMX callback handler for successful order execution
     * @dev Called by GMX when an order is successfully executed
     * @param key The request key for the executed order
     * @param orderData Order data encoded as EventLogData
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.EventLogData memory orderData,
        GmxPositionUtils.EventLogData memory /* eventData */
    ) external auth {
        uint orderType = _getOrderType(orderData);
        if (
            GmxPositionUtils.isIncreaseOrder(GmxPositionUtils.OrderType(orderType))
                || GmxPositionUtils.isDecreaseOrder(GmxPositionUtils.OrderType(orderType))
        ) {
            // Call Mirror.execute for successful order execution
            mirror.execute(key);
        } else if (GmxPositionUtils.isLiquidateOrder(GmxPositionUtils.OrderType(orderType))) {
            // Handle liquidation by calling Mirror.liquidate
            address orderAccount = _getOrderAccount(orderData);
            mirror.liquidate(orderAccount);
        }
        // Note: Invalid order types are silently ignored to avoid reverting GMX callbacks
    }

    /**
     * @notice GMX callback handler for order cancellation
     * @dev Called by GMX when an order is cancelled
     */
    function afterOrderCancellation(
        bytes32, /* key */
        GmxPositionUtils.EventLogData memory, /* orderData */
        GmxPositionUtils.EventLogData memory /* eventData */
    ) external auth {
        // For now, cancellations are handled silently
        // Future implementation could add retry logic or cleanup
    }

    /**
     * @notice GMX callback handler for frozen orders
     * @dev Called by GMX when an order is frozen
     */
    function afterOrderFrozen(
        bytes32, /* key */
        GmxPositionUtils.EventLogData memory, /* orderData */
        GmxPositionUtils.EventLogData memory /* eventData */
    ) external auth {
        // For now, frozen orders are handled silently
        // Future implementation could add retry logic or cleanup
    }

    /**
     * @notice GMX callback handler for execution fee refunds
     * @dev Called by GMX when execution fees need to be refunded
     * @param key The request key for the refunded order
     */
    function refundExecutionFee(
        bytes32 key,
        GmxPositionUtils.EventLogData memory /* eventData */
    ) external payable auth {
        if (msg.value == 0) revert("No execution fee to refund");

        // Refund the execution fee to the configured receiver
        (bool success,) = config.fallbackRefundExecutionFeeReceiver.call{value: msg.value}("");
        if (!success) revert Error.SequencerRouter__FailedRefundExecutionFee();

        _logEvent("RefundExecutionFee", abi.encode(key, msg.value));
    }

    /**
     * @notice Extract order type from EventLogData
     */
    function _getOrderType(
        GmxPositionUtils.EventLogData memory orderData
    ) internal pure returns (uint) {
        GmxPositionUtils.UintItems memory uintItems = orderData.uintItems;
        for (uint i = 0; i < uintItems.items.length; i++) {
            if (_compareStrings(uintItems.items[i].key, "orderType")) {
                return uintItems.items[i].value;
            }
        }
        return 0;
    }

    /**
     * @notice Extract account address from EventLogData
     */
    function _getOrderAccount(
        GmxPositionUtils.EventLogData memory orderData
    ) internal pure returns (address) {
        GmxPositionUtils.AddressItems memory addressItems = orderData.addressItems;
        for (uint i = 0; i < addressItems.items.length; i++) {
            if (_compareStrings(addressItems.items[i].key, "account")) {
                return addressItems.items[i].value;
            }
        }
        return address(0);
    }

    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
