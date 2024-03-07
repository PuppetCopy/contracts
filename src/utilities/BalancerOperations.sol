// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ==============================================================
//  _____                 _      _____ _                        |
// |  _  |_ _ ___ ___ ___| |_   |   __|_|___ ___ ___ ___ ___    |
// |   __| | | . | . | -_|  _|  |   __| |   | .'|   |  _| -_|   |
// |__|  |___|  _|  _|___|_|    |__|  |_|_|_|__,|_|_|___|___|   |
//           |_| |_|                                            |
// ==============================================================
// =================== BalancerOperations =======================
// ==============================================================

// Puppet Finance: https://github.com/GMX-Blueberry-Club/puppet-contracts

// Primary Author
// johnnyonline: https://github.com/johnnyonline

// Reviewers
// itburnz: https://github.com/nissoh

// ==============================================================

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault, IAsset} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/pool-weighted/WeightedPoolUserData.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/vault/IBasePool.sol";

import {IWETH} from "./interfaces/IWETH.sol";

interface IBasePoolErc20 is IBasePool, IERC20 {}

/// @title BalancerOperations
/// @author johnnyonline
/// @notice Utility functions for interacting Balancer AMM
library BalancerUtil {
    error InvalidArrayLength();
    error InvalidValue();

    using SafeERC20 for IERC20;

    /// @notice The address of Balancer vault.
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    /// @notice The address representing ETH.
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice The address of WETH.
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    /**
     * Restricted Functions *********************************
     */
    // function initPool(IBasePoolErc20 pool, IERC20[] memory tokens, uint[] memory amounts) internal returns (uint _assets) {
    //     bytes32 poolId = pool.getPoolId();
    //     IVault vault = IVault(BALANCER_VAULT);
    //     IAsset[] memory assets = new IAsset[](tokens.length);

    //     uint before = pool.balanceOf(msg.sender);

    //     for (uint _i = 0; _i < tokens.length; _i++) {
    //         tokens[_i].transfer(address(this), amounts[_i]);
    //         tokens[_i].approve(address(vault), amounts[_i]);

    //         // Cast each IERC20 token to IAsset and assign it to the assets array
    //         assets[_i] = IAsset(address(tokens[_i]));
    //     }

    //     // vault.joinPool(
    //     //     poolId,
    //     //     address(this), // sender
    //     //     address(this), // recipient
    //     //     IVault.JoinPoolRequest({
    //     //         assets: assets,
    //     //         maxAmountsIn: amounts,
    //     //         userData: abi.encode(
    //     //             WeightedPoolUserData.JoinKind.INIT,
    //     //             amounts // amountsIn
    //     //         ),
    //     //         fromInternalBalance: false
    //     //     })
    //     // );

    //     _assets = pool.balanceOf(msg.sender) - before;

    //     return _assets;
    // }

    // function addLiquidity(address _poolAddress, IERC20[] memory _tokens, uint[] memory _amounts) external returns (uint _bptAmount) {
    //     if (_tokens.length != _amounts.length) revert InvalidArrayLength();

    //     bytes32 _poolId = IBasePool(_poolAddress).getPoolId();
    //     IVault _vault = IVault(BALANCER_VAULT);
    //     IAsset[] memory assets = new IAsset[](_tokens.length);

    //     for (uint _i = 0; _i < _tokens.length; _i++) {
    //         _tokens[_i].transfer(address(this), _amounts[_i]);
    //         _tokens[_i].approve(address(_vault), _amounts[_i]);
    //         assets[_i] = IAsset(address(_tokens[_i]));
    //     }

    //     uint _before = IERC20(_poolAddress).balanceOf(address(this));
    //     _vault.joinPool(
    //         _poolId,
    //         address(this), // sender
    //         address(this), // recipient
    //         IVault.JoinPoolRequest({
    //             assets: assets,
    //             maxAmountsIn: _amounts,
    //             userData: abi.encode(
    //                 WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
    //                 _amounts, // amountsIn
    //                 0 // minimumBPT
    //             ),
    //             fromInternalBalance: false
    //         })
    //     );

    //     _bptAmount = IERC20(_poolAddress).balanceOf(address(this)) - _before;
    //     IERC20(_poolAddress).transfer(msg.sender, _bptAmount);
    // }

    // function addLiquidityOneToken(address _poolAddress, address _asset, uint256 _amount) external payable returns (uint256 _assets) {
    //     bytes32 _poolId = IBalancerPool(_poolAddress).getPoolId();
    //     IVault _vault = IVault(BALANCER_VAULT);

    //     (IERC20[] memory _tokens,,) = _vault.getPoolTokens(_poolId);

    //     uint256 _before = IERC20(_poolAddress).balanceOf(address(this));

    //     if (_asset == ETH) {
    //         _wrapETH(_amount);
    //         _asset = WETH;
    //     }

    //     IERC20(_asset).transferFrom(msg.sender, address(this), _amount);

    //     uint256[] memory _amounts = new uint256[](_tokens.length);
    //     for (uint256 _i = 0; _i < _tokens.length; _i++) {
    //         if (_tokens[_i] == _asset) {
    //             _amounts[_i] = _amount;

    //             uint256[] memory _noBptAmounts = _isComposablePool(_tokens, _poolAddress) ? _dropBptItem(_tokens, _amounts, _poolAddress) :
    // _amounts;

    //             _approve(_tokens[_i], address(_vault), _amount);
    //             _vault.joinPool(
    //                 _poolId,
    //                 address(this), // sender
    //                 address(this), // recipient
    //                 IVault.JoinPoolRequest({
    //                     assets: _tokens,
    //                     maxAmountsIn: _amounts,
    //                     userData: abi.encode(
    //                         WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
    //                         _noBptAmounts, // amountsIn
    //                         0 // minimumBPT
    //                     ),
    //                     fromInternalBalance: false
    //                 })
    //             );
    //             break;
    //         }
    //     }

    //     _assets = IERC20(_poolAddress).balanceOf(address(this)) - _before;
    //     IERC20(_poolAddress).safeTransfer(msg.sender, _assets);
    // }

    // function removeLiquidityOneToken(address _poolAddress, address _asset, uint256 _bptAmountIn) external returns (uint256 _underlyingAmount) {
    //     bytes32 _poolId = IBalancerPool(_poolAddress).getPoolId();
    //     IVault _vault = IVault(BALANCER_VAULT);

    //     (address[] memory _tokens,,) = _vault.getPoolTokens(_poolId);
    //     uint256 _before = IERC20(_asset).balanceOf(address(this));

    //     IERC20(_poolAddress).transferFrom(msg.sender, address(this), _bptAmountIn);

    //     uint256[] memory _amounts = new uint256[](_tokens.length);
    //     for (uint256 _i = 0; _i < _tokens.length; _i++) {
    //         if (_tokens[_i] == _asset) {
    //             _vault.exitPool(
    //                 _poolId,
    //                 address(this), // sender
    //                 payable(address(this)), // recipient
    //                 IVault.ExitPoolRequest({
    //                     assets: _tokens,
    //                     minAmountsOut: _amounts,
    //                     userData: abi.encode(
    //                         WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
    //                         _bptAmountIn, // bptAmountIn
    //                         _i // enterTokenIndex
    //                     ),
    //                     toInternalBalance: false
    //                 })
    //             );
    //             break;
    //         }
    //     }
    //     _underlyingAmount = IERC20(_asset).balanceOf(address(this)) - _before;
    //     IERC20(_asset).safeTransfer(msg.sender, _underlyingAmount);

    //     return _underlyingAmount;
    // }

    /**
     * Internal Functions *********************************
     */
    function _isComposablePool(address[] memory _tokens, address _poolAddress) internal pure returns (bool) {
        for (uint i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }

    function _dropBptItem(address[] memory _tokens, uint[] memory _amounts, address _poolAddress) internal pure returns (uint[] memory) {
        uint[] memory _noBPTAmounts = new uint[](_tokens.length - 1);
        uint _j = 0;
        for (uint _i = 0; _i < _tokens.length; _i++) {
            if (_tokens[_i] != _poolAddress) {
                _noBPTAmounts[_j] = _amounts[_i];
                _j++;
            }
        }
        return _noBPTAmounts;
    }

    function _wrapETH(uint _amount) internal {
        IWETH(WETH).deposit{value: _amount}();
    }
}
