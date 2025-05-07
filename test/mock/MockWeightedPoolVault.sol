// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {
    IAsset,
    IAuthorizer,
    IERC20,
    IFlashLoanRecipient,
    IProtocolFeesCollector,
    IVault,
    IWETH
} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

contract MockWeightedPoolVault is IVault {
    IERC20[] _tokens = new IERC20[](3);
    uint[] _balances = new uint[](3);
    uint _lastChangeBlock;

    function getDomainSeparator() external view override returns (bytes32) {}

    function getNextNonce(
        address user
    ) external view override returns (uint) {}

    function getPausedState()
        external
        view
        override
        returns (bool paused, uint pauseWindowEndTime, uint bufferPeriodEndTime)
    {}

    function getActionId(
        bytes4 selector
    ) external view override returns (bytes32) {}

    function getAuthorizer() external view override returns (IAuthorizer) {}

    function setAuthorizer(
        IAuthorizer newAuthorizer
    ) external override {}

    function hasApprovedRelayer(address user, address relayer) external view override returns (bool) {}

    function setRelayerApproval(address sender, address relayer, bool approved) external override {}

    function getInternalBalance(address user, IERC20[] memory tokens) external view override returns (uint[] memory) {}

    function manageUserBalance(
        UserBalanceOp[] memory ops
    ) external payable override {}

    function registerPool(
        PoolSpecialization specialization
    ) external override returns (bytes32) {}

    function getPool(
        bytes32 poolId
    ) external view override returns (address, PoolSpecialization) {}

    function registerTokens(bytes32 poolId, IERC20[] memory tokens, address[] memory assetManagers) external override {}

    function deregisterTokens(bytes32 poolId, IERC20[] memory tokens) external override {}

    function getPoolTokenInfo(
        bytes32 poolId,
        IERC20 token
    ) external view override returns (uint cash, uint managed, uint lastChangeBlock, address assetManager) {}

    function getPoolTokens(
        bytes32 /*poolId*/
    ) external view override returns (IERC20[] memory tokens, uint[] memory balances, uint lastChangeBlock) {
        return (_tokens, _balances, _lastChangeBlock);
    }

    function initPool(address token0, address token1, uint balances0, uint balance1) public {
        _tokens[0] = IERC20(token0);
        _tokens[1] = IERC20(token1);

        setPoolBalances(balances0, balance1);
    }

    function setPoolBalances(uint balances0, uint balance1) public {
        _balances[0] = balances0;
        _balances[1] = balance1;
    }

    function setToken0Balance(
        uint blance0
    ) external {
        _balances[0] = blance0;
    }

    function setToken1Balance(
        uint blance0
    ) external {
        _balances[1] = blance0;
    }

    function setToken2Balance(
        uint blance0
    ) external {
        _balances[2] = blance0;
    }

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable override {}

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external override {}

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint limit,
        uint deadline
    ) external payable override returns (uint) {}

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int[] memory limits,
        uint deadline
    ) external payable override returns (int[] memory) {}

    function queryBatchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds
    ) external override returns (int[] memory assetDeltas) {}

    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint[] memory amounts,
        bytes memory userData
    ) external override {}

    function managePoolBalance(
        PoolBalanceOp[] memory ops
    ) external override {}

    function getProtocolFeesCollector() external view override returns (IProtocolFeesCollector) {}

    function setPaused(
        bool paused
    ) external override {}

    function WETH() external view override returns (IWETH) {}
}
