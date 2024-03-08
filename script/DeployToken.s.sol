// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PRBTest} from "@prb/test/src/PRBTest.sol";
import {IVault, IAsset} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/pool-weighted/WeightedPoolUserData.sol";
import {DeployerEnv} from "script/Env.s.sol";

import {Dictator} from "src/utilities/Dictator.sol";
import {WNT} from "src/utilities/common/WNT.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {IBasePoolErc20} from "src/utilities/BalancerOperations.sol";

contract DeployToken is PRBTest {
    address internal DEPLOYER_ADDRESS = vm.envAddress("GBC_DEPLOYER_ADDRESS");
    uint internal DEPLOYER_KEY = vm.envUint("GBC_DEPLOYER_PRIVATE_KEY");

    WNT wnt;
    Dictator dictator = Dictator(DeployerEnv.Dictator);
    PuppetToken puppetToken = PuppetToken(DeployerEnv.PuppetToken);
    IERC20 weth = IERC20(DeployerEnv.wnt);

    IVault vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWeightedPoolFactory poolFactory = IWeightedPoolFactory(0xc7E5ED1054A24Ef31D827E6F86caA58B3Bc168d7);
    IBasePoolErc20 pool = IBasePoolErc20(DeployerEnv.BasePool);
    // IBasePoolErc20 pool = IBasePoolErc20(
    //     poolFactory.create("PUPPET-WETH", "PUPPET-WETH", tokens, normalizedWeights, rateProviders, 0.01e18, dictator.owner(), bytes32(0))
    // );

    function run() public {
        vm.startBroadcast(DEPLOYER_KEY);
        _deployContracts();
        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(address(puppetToken));
        tokens[1] = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

        uint[] memory normalizedWeights = new uint[](2);
        normalizedWeights[0] = 0.8e18;
        normalizedWeights[1] = 0.2e18;

        address[] memory rateProviders = new address[](2);
        rateProviders[0] = address(0);
        rateProviders[1] = address(0);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 100_000e18 / 10;
        amounts[1] = 0.1e18;

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
