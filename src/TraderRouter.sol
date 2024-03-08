// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {MulticallRouter} from "./utilities/MulticallRouter.sol";
import {WNT} from "./utilities/common/WNT.sol";
import {Router} from "./utilities/Router.sol";
import {Dictator} from "./utilities/Dictator.sol";

import {PuppetToken} from "./tokenomics/PuppetToken.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";

contract TraderRouter is MulticallRouter {

    struct RewardRouterParams {
        Dictator dictator;
        PuppetToken puppetToken;
        WNT wnt;
        Router router;
    }

    struct PositionRouterConfigParams {
        address dao;
    }

    RewardRouterParams params;
    PositionRouterConfigParams config;

    constructor(Dictator dictator, WNT wnt, Router router, PositionRouterConfigParams memory _config, RewardRouterParams memory _params)
        MulticallRouter(dictator, wnt, router, _config.dao)
    {
        params = _params;
        config = _config;
    }

    // governance

    // function setRewardLogic(RewardLogic rewardLogic) external requiresAuth {
    //     config.rewardLogic = rewardLogic;
    // }
}
