// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "forge-std/interfaces/IERC165.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {CoreContract} from "../../utils/CoreContract.sol";
import {IAuthority} from "../../utils/interfaces/IAuthority.sol";
import {Precision} from "../../utils/Precision.sol";

/**
 * @title SubscriptionPolicy
 * @notice Aggregated policy for puppet subscriptions with flexible key-based matching
 * @dev All rules are checked internally (no external calls) for gas efficiency.
 *      Keys are opaque bytes32 - derivation is handled off-chain or by inheriting contracts.
 *      Override `deriveMatchingKeys` to customize key matching logic.
 *      Version is configurable via setConfig for key derivation upgrades.
 */
contract SubscriptionPolicy is ERC7579ActionPolicy, CoreContract {
    struct Config {
        uint8 version;
    }

    struct Subscription {
        uint16 allowanceRate;
        uint32 throttlePeriod;
        uint64 expiry;
    }

    Config public config;

    mapping(ConfigId => mapping(address => mapping(address => mapping(bytes32 => Subscription)))) internal subscriptionMap;
    mapping(ConfigId => mapping(address => mapping(address => mapping(bytes32 => uint64)))) internal lastActivityMap;

    constructor(IAuthority _authority, bytes memory _config) CoreContract(_authority, _config) {}

    function _setConfig(bytes memory _data) internal override {
        config = abi.decode(_data, (Config));
    }

    // =========================================================================
    // ERC7579 Module Interface
    // =========================================================================

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == TYPE_POLICY;
    }

    function isInitialized(address) external pure override returns (bool) {
        return false;
    }

    function isInitialized(address, ConfigId) external pure override returns (bool) {
        return false;
    }

    function isInitialized(address, address, ConfigId) external pure override returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) public pure override(CoreContract, IERC165) returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId
            || interfaceId == type(CoreContract).interfaceId
            || interfaceId == 0x01ffc9a7;
    }

    // =========================================================================
    // Subscription Management
    // =========================================================================

    /**
     * @notice Subscribe a puppet to a key with specified rules
     * @dev Called via Smart Sessions multiplexer during policy initialization.
     *      Key is opaque - derivation handled off-chain.
     * @param account The puppet account subscribing
     * @param configId The session configuration ID
     * @param initData Encoded (bytes32 key, uint16 allowanceRate, uint32 throttlePeriod, uint64 expiry)
     */
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external override(ERC7579PolicyBase, IPolicy) {
        (bytes32 key, uint16 allowanceRate, uint32 throttlePeriod, uint64 expiry) =
            abi.decode(initData, (bytes32, uint16, uint32, uint64));

        require(allowanceRate <= 10000, "Invalid allowance rate");

        subscriptionMap[configId][msg.sender][account][key] = Subscription({
            allowanceRate: allowanceRate,
            throttlePeriod: throttlePeriod,
            expiry: expiry
        });

        _logEvent("Subscribe", abi.encode(configId, account, key, allowanceRate, throttlePeriod, expiry));
    }

    /**
     * @notice Unsubscribe a puppet from a subscription
     * @param configId The session configuration ID
     * @param key The subscription key to remove
     */
    function unsubscribe(ConfigId configId, bytes32 key) external {
        delete subscriptionMap[configId][msg.sender][msg.sender][key];
        delete lastActivityMap[configId][msg.sender][msg.sender][key];

        _logEvent("Unsubscribe", abi.encode(configId, msg.sender, key));
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /**
     * @notice Get subscription details
     */
    function getSubscription(
        ConfigId configId,
        address multiplexer,
        address puppet,
        bytes32 key
    ) external view returns (Subscription memory) {
        return subscriptionMap[configId][multiplexer][puppet][key];
    }

    /**
     * @notice Get last activity timestamp for a subscription
     */
    function getLastActivity(
        ConfigId configId,
        address multiplexer,
        address puppet,
        bytes32 key
    ) external view returns (uint64) {
        return lastActivityMap[configId][multiplexer][puppet][key];
    }

    // =========================================================================
    // Key Derivation (Override to customize matching logic)
    // =========================================================================

    function deriveSpecificKey(address token, address master) public view returns (bytes32) {
        return keccak256(abi.encode(config.version, token, master));
    }

    function deriveWildcardKey(address token) public view returns (bytes32) {
        return keccak256(abi.encode(config.version, token, address(0)));
    }

    // =========================================================================
    // Policy Check
    // =========================================================================

    /**
     * @notice Check if an action is allowed by this policy
     * @dev All rules are checked internally for gas efficiency:
     *      1. Validate transfer selector
     *      2. Check specific master key, fallback to wildcard
     *      3. Check subscription exists and not expired
     *      4. Check allowance rate against puppet balance
     *      5. Check throttle period
     * @param id The session configuration ID
     * @param puppet The puppet account performing the action
     * @param token The token being transferred (target)
     * @param value Must be 0 (no ETH transfers)
     * @param data The transfer calldata
     * @return VALIDATION_SUCCESS or VALIDATION_FAILED
     */
    function checkAction(
        ConfigId id,
        address puppet,
        address token,
        uint256 value,
        bytes calldata data
    ) external override returns (uint256) {
        // Rule 1: No ETH transfers
        if (value != 0) return VALIDATION_FAILED;

        // Rule 2: Must be ERC20 transfer
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        // Extract master from transfer calldata
        address master = address(bytes20(data[16:36]));

        // Try specific key first
        bytes32 specificKey = deriveSpecificKey(token, master);
        Subscription memory sub = subscriptionMap[id][msg.sender][puppet][specificKey];
        bytes32 matchedKey = specificKey;

        // Fallback to wildcard if no specific subscription
        if (sub.allowanceRate == 0) {
            bytes32 wildcardKey = deriveWildcardKey(token);
            sub = subscriptionMap[id][msg.sender][puppet][wildcardKey];
            matchedKey = wildcardKey;
        }

        // Rule 3: Subscription must exist
        if (sub.allowanceRate == 0) return VALIDATION_FAILED;

        // Rule 4: Check expiry
        if (block.timestamp > sub.expiry) return VALIDATION_FAILED;

        // Rule 5: Check throttle (if enabled)
        if (sub.throttlePeriod > 0) {
            uint64 lastActivity = lastActivityMap[id][msg.sender][puppet][matchedKey];
            if (block.timestamp < lastActivity + sub.throttlePeriod) return VALIDATION_FAILED;
        }

        // Rule 6: Check allowance rate
        uint256 amount = uint256(bytes32(data[36:68]));
        uint256 puppetBalance = IERC20(token).balanceOf(puppet);
        uint256 maxAllowed = Precision.applyBasisPoints(sub.allowanceRate, puppetBalance);
        if (amount > maxAllowed) return VALIDATION_FAILED;

        // Update throttle timestamp (state change)
        lastActivityMap[id][msg.sender][puppet][matchedKey] = uint64(block.timestamp);

        return VALIDATION_SUCCESS;
    }
}
