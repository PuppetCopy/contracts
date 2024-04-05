// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PositionUtils} from "./../../position/util/PositionUtils.sol";
import {VeRevenueDistributor} from "./../../tokenomics/VeRevenueDistributor.sol";

import {CugarStore} from "./../store/CugarStore.sol";

import {Oracle} from "./../../Oracle.sol";

library CugarLogic {
    event CugarLogic__Claim(IERC20 token, address user, uint revenueInToken, uint tokenPrice, uint claimableAmount);

    struct CallClaim {
        CugarStore store;
        Oracle oracle;
        VeRevenueDistributor revenueDistributor;
    }

    function increase(CugarStore store, IERC20 token, address account, uint amountInToken) internal {
        store.increaseCugar(
            PositionUtils.getCugarKey(token, msg.sender, account), //
            amountInToken
        );
    }

    function claim(CallClaim memory callClaimConfig, IERC20 token, address revenueSource, address user, uint maxAcceptableTokenPriceInUsdc)
        internal
        returns (uint)
    {
        uint tokenPrice = callClaimConfig.oracle.getMaxPriceInToken(token);
        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert CugarLogic__UnacceptableTokenPrice(tokenPrice, maxAcceptableTokenPriceInUsdc);
        if (tokenPrice == 0) revert CugarLogic__InvalidClaimPrice();

        bytes32 contributionKey = PositionUtils.getCugarKey(token, revenueSource, user);
        uint revenueInToken = callClaimConfig.store.getCugar(contributionKey);

        if (revenueInToken == 0) return 0;

        depositRevenue(callClaimConfig.revenueDistributor, revenueSource, token, revenueInToken);

        callClaimConfig.store.resetCugar(contributionKey);

        uint claimableAmount = revenueInToken * 1e30 / tokenPrice;

        emit CugarLogic__Claim(token, user, revenueInToken, tokenPrice, claimableAmount);

        return claimableAmount;
    }

    function claimList(CugarStore store, VeRevenueDistributor revenueDistributor, address revenueSource, bytes32[] calldata keyList) internal {
        uint[] memory balanceList = store.getCugarList(keyList);

        for (uint i = 0; i < keyList.length; i++) {
            if (balanceList[i] == 0) continue;

            depositRevenue(revenueDistributor, revenueSource, IERC20(address(store)), balanceList[i]);
            store.resetCugar(keyList[i]);
        }
    }

    function increaseList(CugarStore store, bytes32[] memory keyList, uint[] calldata amountList) internal {
        store.increaseList(keyList, amountList);
    }

    function resetCugarList(CugarStore ugrStore, bytes32[] calldata contributionKeyList) internal {
        ugrStore.resetCugarList(contributionKeyList);
    }

    function depositRevenue(VeRevenueDistributor revenueDistributor, address revenueSource, IERC20 token, uint amount) internal {
        revenueDistributor.checkpointToken(token);
        SafeERC20.safeTransferFrom(token, revenueSource, address(revenueDistributor), amount);
        revenueDistributor.checkpointToken(token);
    }

    error CugarLogic__InvalidInputLength();
    error CugarLogic__NothingToClaim();
    error CugarLogic__InvalidClaimPrice();
    error CugarLogic__UnacceptableTokenPrice(uint curentPrice, uint acceptablePrice);
}
