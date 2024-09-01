// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "../RewardRouter.sol";
import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {RewardLogic} from "../tokenomics/RewardLogic.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {RewardStore} from "../tokenomics/store/RewardStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

contract Reader is CoreContract {
    struct Config {
        RewardStore rewardStore;
        PuppetToken puppetToken;
        RewardRouter rewardRouter;
        ContributeStore contributeStore;
        RewardLogic rewardLogic;
    }

    Config public config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        _setConfig(_config);
    }

    function calculateAPR() public view returns (uint apr) {
        uint balance = config.contributeStore.getTokenBalance(config.puppetToken);

        if (balance == 0) return 0;

        (uint distributionTimeframe,) = config.rewardLogic.config();

        uint totalRewardRate = balance * Precision.BASIS_POINT_DIVISOR / distributionTimeframe;
        uint distributionTimeframeInYears = distributionTimeframe / (365 days);
        apr = totalRewardRate / distributionTimeframeInYears;
    }

    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }
}
