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
        require(address(_account) != address(0), "Account not set correctly");
        require(address(_ruleContract) != address(0), "Rule contract not set correctly");
        require(address(_mirror) != address(0), "Mirror not set correctly");
        require(address(_settle) != address(0), "Settle not set correctly");

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

        require(_config.openBaseGasLimit > 0, "Invalid mirror base gas limit");
        require(_config.openPerPuppetGasLimit > 0, "Invalid mirror per-puppet gas limit");
        require(_config.adjustBaseGasLimit > 0, "Invalid adjust base gas limit");
        require(_config.adjustPerPuppetGasLimit > 0, "Invalid adjust per-puppet gas limit");

        config = _config;
    }

    /**
     * @notice GMX callback handler for successful order execution
     * @dev Called by GMX when an order is successfully executed
     * @param key The request key for the executed order
     * @param order Order details from GMX
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external auth {
        if (
            GmxPositionUtils.isIncreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
                || GmxPositionUtils.isDecreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
        ) {
            // Call Mirror.execute for successful order execution
            mirror.execute(key);
        } else if (GmxPositionUtils.isLiquidateOrder(GmxPositionUtils.OrderType(order.numbers.orderType))) {
            // Handle liquidation by calling Mirror.liquidate
            mirror.liquidate(order.addresses.account);
        }
        // Note: Invalid order types are silently ignored to avoid reverting GMX callbacks
    }

    /**
     * @notice GMX callback handler for order cancellation
     * @dev Called by GMX when an order is cancelled
     */
    function afterOrderCancellation(
        bytes32, /* key */
        GmxPositionUtils.Props calldata, /* order */
        GmxPositionUtils.EventLogData calldata /* eventData */
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
        GmxPositionUtils.Props calldata, /* order */
        GmxPositionUtils.EventLogData calldata /* eventData */
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
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external payable auth {
        require(msg.value > 0, "No execution fee to refund");

        // Refund the execution fee to the configured receiver
        (bool success,) = config.fallbackRefundExecutionFeeReceiver.call{value: msg.value}("");
        require(success, Error.SequencerRouter__FailedRefundExecutionFee());

        _logEvent("RefundExecutionFee", abi.encode(key, msg.value));
    }
}
