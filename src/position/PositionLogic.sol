// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "../utilities/Router.sol";

import {PositionStore} from "./store/PositionStore.sol";

contract PositionLogic is Auth {
    struct AdjustPositionParams {
        address account;
        address receiver;
        address market;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
    }

    struct EnvParams {
        PositionStore store;
        Router router;
        IERC20 depositCollateralToken;
        uint puppetListLimit;
        uint adjustmentFeeFactor;
        uint minExecutionFee;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function requestOpenPosition(EnvParams calldata envParams, AdjustPositionParams calldata adjustmentParams, address[] calldata puppetList)
        external
        requiresAuth
    {
        PositionStore.MirrorPosition memory mp = envParams.store.getMirrorPosition(adjustmentParams.account);

        uint totalAssets = envParams.depositCollateralToken.balanceOf(address(this));

        envParams.router.pluginTransfer(envParams.depositCollateralToken, adjustmentParams.account, address(this), totalAssets);

        // adjustment.depositCollateralToken.safeTransferFrom(msg.sender, address(this), _swapParams.amount);

        if (puppetList.length > envParams.puppetListLimit) {
            if (mp.deposit > 0) revert PositionLogic__PuppetListLimitExceeded();
        }
    }

    function requestIncreasePosition(PositionStore store) external requiresAuth {
        PositionStore.MirrorPosition memory mp = store.getMirrorPosition(msg.sender);

        if (store.getMirrorPosition(msg.sender).deposit > 0) revert PositionLogic__PositionAlreadyExists();
    }

    error PositionLogic__PositionAlreadyExists();
    error PositionLogic__PuppetListLimitExceeded();
}
