// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IERC20 as IBERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IAsset, IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {IWNT} from "src/utils/interfaces/IWNT.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "script/Const.sol";

contract ManagePeriphery is BaseScript {
    IWNT wnt;
    Dictator dictator = Dictator(getDeployedAddress("Dictator"));
    PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
    IERC20 weth = IERC20(Address.wnt);

    IVault vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWeightedPoolFactory poolFactory = IWeightedPoolFactory(0xc7E5ED1054A24Ef31D827E6F86caA58B3Bc168d7);

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        // initPool();
        // exitPool();
        vm.stopBroadcast();
    }

    function initPool() public {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(Address.wnt);
        tokens[1] = puppetToken;

        uint[] memory normalizedWeights = new uint[](2);
        normalizedWeights[0] = 0.2e18;
        normalizedWeights[1] = 0.8e18;

        address[] memory rateProviders = new address[](2);
        rateProviders[0] = address(0);
        rateProviders[1] = address(0);

        IBasePoolErc20 pool = IBasePoolErc20(
            poolFactory.create(
                "PUPPET-WETH", "PUPPET-WETH", tokens, normalizedWeights, rateProviders, 0.01e18, Address.dao, bytes32(0)
            )
        );

        uint[] memory amounts = new uint[](2);
        amounts[0] = 0.1e18;
        amounts[1] = 10_000e18;

        IAsset[] memory assets = new IAsset[](tokens.length);

        for (uint _i = 0; _i < tokens.length; _i++) {
            SafeERC20.forceApprove(tokens[_i], address(vault), amounts[_i]);
            // Cast each IERC20 token to IAsset and assign it to the assets array
            assets[_i] = IAsset(address(tokens[_i]));
        }

        bytes32 poolId = pool.getPoolId();

        vault.joinPool(
            poolId,
            DEPLOYER_ADDRESS, // sender
            DEPLOYER_ADDRESS, // recipient
            IVault.JoinPoolRequest({
                assets: assets,
                maxAmountsIn: amounts,
                userData: abi.encode(
                    WeightedPoolUserData.JoinKind.INIT,
                    amounts // amountsIn
                ),
                fromInternalBalance: false
            })
        );
    }

    function exitPool() public {
        IBasePoolErc20 pool = IBasePoolErc20(Address.BasePool);
        bytes32 poolId = pool.getPoolId();

        (IBERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        IAsset[] memory assets = new IAsset[](tokens.length);

        for (uint _i = 0; _i < tokens.length; _i++) {
            assets[_i] = IAsset(address(tokens[_i]));
        }

        vault.getPoolTokens(poolId);
        uint bptBalance = pool.balanceOf(DEPLOYER_ADDRESS);

        uint[] memory _amounts = new uint[](tokens.length);

        vault.exitPool(
            poolId,
            DEPLOYER_ADDRESS, // sender
            payable(DEPLOYER_ADDRESS), // recipient
            IVault.ExitPoolRequest({
                assets: assets,
                minAmountsOut: _amounts,
                userData: abi.encode(WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, bptBalance),
                toInternalBalance: false
            })
        );
    }
}

interface IWeightedPoolFactory {
    /**
     * @dev Deploys a new `WeightedPool`.
     * @param name Name of the pool.
     * @param symbol Symbol of the pool.
     * @param tokens Array of ERC20 tokens to be added to the pool.
     * @param weights Array of weights for the tokens.
     * @param assetManagers Array of addresses for the asset managers of the tokens.
     * @param swapFeePercentage Fee percentage for swaps.
     * @param owner Address of the owner of the pool.
     * @return The address of the newly created `WeightedPool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint[] memory weights,
        address[] memory assetManagers,
        uint swapFeePercentage,
        address owner,
        bytes32 salt
    ) external returns (address);
}

interface IBasePoolErc20 is IBasePool, IERC20 {}
