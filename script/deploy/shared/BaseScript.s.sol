// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/src/Script.sol";
import {stdToml} from "forge-std/src/StdToml.sol";

/// @notice Interface for ImmutableCreate2Factory (deployed on most EVM chains)
interface ImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes calldata initializationCode)
        external
        payable
        returns (address deploymentAddress);

    function findCreate2Address(bytes32 salt, bytes calldata initializationCode)
        external
        view
        returns (address deploymentAddress);
}

/// @title BaseScript
/// @notice Base contract for deployment scripts
abstract contract BaseScript is Script {
    using stdToml for string;

    // ImmutableCreate2Factory - deployed at same address on most EVM chains
    ImmutableCreate2Factory constant FACTORY = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    string constant DEPLOYMENTS_PATH = "./deployments.toml";
    string constant CONST_PATH = "./const.toml";

    uint256 internal immutable DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address internal immutable DEPLOYER_ADDRESS = vm.addr(DEPLOYER_PRIVATE_KEY);
    address internal immutable ATTESTOR_ADDRESS = vm.envOr("ATTESTOR_ADDRESS", DEPLOYER_ADDRESS);

    string internal _deployments = vm.readFile(DEPLOYMENTS_PATH);
    string internal _const = vm.readFile(CONST_PATH);

    // Protocol constants
    function _dao() internal view returns (address) { return _const.readAddress(".protocol.dao"); }
    function _theCompact() internal view returns (address) { return _const.readAddress(".protocol.theCompact"); }
    function _referralCode() internal view returns (bytes32) { return _const.readBytes32(".protocol.referralCode"); }

    // GMX constants
    function _gmxExchangeRouter() internal view returns (address) { return _const.readAddress(".gmx.exchangeRouter"); }
    function _gmxOrderVault() internal view returns (address) { return _const.readAddress(".gmx.orderVault"); }
    function _gmxDataStore() internal view returns (address) { return _const.readAddress(".gmx.dataStore"); }

    function _getChainToken(string memory symbol) internal view returns (IERC20) {
        address addr = _const.readAddress(string.concat(".", _chainKey(), ".token.", symbol));
        require(addr != address(0), string.concat("Chain token not found: ", symbol));
        require(addr.code.length > 0, string.concat("Chain token not deployed: ", symbol));
        return IERC20(addr);
    }

    function _getUniversalAddress(string memory name) internal view returns (address addr) {
        addr = _deployments.readAddress(string.concat(".universal.address.", name));
        require(addr != address(0), string.concat("Universal address not found: ", name));
        require(addr.code.length > 0, string.concat("Universal contract not deployed: ", name));
    }

    function _getChainAddress(string memory name) internal view returns (address addr) {
        addr = _deployments.readAddress(string.concat(".", _chainKey(), ".address.", name));
        require(addr != address(0), string.concat("Chain address not found: ", name));
        require(addr.code.length > 0, string.concat("Chain contract not deployed: ", name));
    }
    function _setUniversalAddress(string memory name, address addr) internal {
        vm.writeToml(vm.toString(addr), DEPLOYMENTS_PATH, string.concat(".universal.address.", name));
    }

    function _setChainAddress(string memory name, address addr) internal {
        vm.writeToml(vm.toString(addr), DEPLOYMENTS_PATH, string.concat(".", _chainKey(), ".address.", name));
    }

    function _chainKey() internal view returns (string memory) {
        if (block.chainid == 42161) return "arbitrum";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 1) return "mainnet";
        if (block.chainid == 11155111) return "sepolia";
        return vm.toString(block.chainid);
    }
}
