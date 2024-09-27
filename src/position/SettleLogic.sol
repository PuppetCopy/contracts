// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract SettleLogic is CoreContract {
    struct Config {
        uint performanceContributionRate;
        uint traderPerformanceContributionShare;
    }

    struct CallParams {
        uint recordedAmountIn;
        uint profit;
        uint performanceFee;
        uint traderPerformanceFee;
    }

    MirrorPositionStore positionStore;
    PuppetStore puppetStore;
    ContributeStore contributeStore;
    Config public config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        ContributeStore _contributeStore,
        PuppetStore _puppetStore
    ) CoreContract("ExecuteDecreasePositionLogic", "1", _authority, _eventEmitter) {
        contributeStore = _contributeStore;
        puppetStore = _puppetStore;
    }

    function settle(bytes32 routeKey, uint fromIndex, uint toIndex) external auth {
        PuppetStore.AllocationMatch memory allocation = puppetStore.getAllocationMatch(routeKey);
        PuppetStore.Settlement memory settlement = puppetStore.getSettlement(routeKey);

        if (settlement.profit == 0) {
            puppetStore.settleList(allocation.token, routeKey, fromIndex, toIndex, settlement.amountIn);

            address[] memory emptyContributionList = new address[](0);
            uint[] memory emptyContributionAmountList = new uint[](0);

            logEvent(
                "Settle", abi.encode(routeKey, fromIndex, toIndex, emptyContributionList, emptyContributionAmountList)
            );

            return;
        }

        uint puppetContribution = Precision.applyFactor(config.performanceContributionRate, settlement.profit);
        uint traderPerformanceContribution =
            Precision.applyFactor(config.traderPerformanceContributionShare, settlement.profit);
        uint totalContribution = puppetContribution + traderPerformanceContribution;
        uint settlementAmountInAfterFee = settlement.amountIn - totalContribution;

        (address[] memory puppetContributionList, uint[] memory puppetContributionAmountList) =
            puppetStore.settleList(allocation.token, routeKey, fromIndex, toIndex, settlementAmountInAfterFee);

        contributeStore.contributeMany(
            allocation.token, puppetStore, puppetContributionList, puppetContributionAmountList
        );

        address account = positionStore.getSubaccount(routeKey).account();

        contributeStore.contribute(allocation.token, positionStore, account, traderPerformanceContribution);

        logEvent(
            "Settle", abi.encode(routeKey, fromIndex, toIndex, puppetContributionList, puppetContributionAmountList)
        );
    }

    function getDistribution(
        uint profit,
        uint performanceFeeRate,
        uint traderPerformanceFeeShare
    ) internal pure returns (uint performanceFee, uint traderPerformanceFee, uint amountOutAfterFee) {
        if (profit == 0) return (0, 0, 0);

        performanceFee = Precision.applyFactor(performanceFeeRate, profit);
        amountOutAfterFee = profit - performanceFee;

        traderPerformanceFee = Precision.applyFactor(traderPerformanceFeeShare, performanceFee);

        performanceFee -= traderPerformanceFee;

        return (performanceFee, traderPerformanceFee, amountOutAfterFee);
    }

    // governance

    function setConfig(Config memory _config) external auth {
        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
