// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {IGmxEventUtils} from "./interface/IGmxEventUtils.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteDecreasePositionLogic is CoreContract {
    struct Config {
        address gmxOrderReciever;
        uint performanceFeeRate;
        uint traderPerformanceFeeShare;
    }

    struct CallParams {
        uint totalAmountIn;
        uint recordedAmountIn;
        uint profit;
        uint totalPerformanceFee;
        uint traderPerformanceCutoffFee;
    }

    PositionStore positionStore;
    PuppetStore puppetStore;
    ContributeStore contributeStore;
    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        ContributeStore _contributeStore,
        PuppetStore _puppetStore,
        PositionStore _positionStore,
        Config memory _config
    ) CoreContract("ExecuteDecreasePositionLogic", "1", _authority, _eventEmitter) {
        contributeStore = _contributeStore;
        puppetStore = _puppetStore;
        positionStore = _positionStore;

        _setConfig(_config);
    }

    function execute(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecuteDecreasePositionLogic__UnexpectedEventData();
        }

        PositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = positionStore.getMirrorPosition(request.positionKey);
        CallParams memory callParams = CallParams({
            totalAmountIn: eventLogData.uintItems.items[0].value,
            recordedAmountIn: positionStore.recordedTransferIn(IERC20(eventLogData.addressItems.items[0].value)),
            totalPerformanceFee: 0,
            traderPerformanceCutoffFee: 0,
            profit: 0
        });

        if (mirrorPosition.traderSize == 0) {
            revert ExecuteDecreasePositionLogic__InvalidRequest(request.positionKey, requestKey);
        }

        if (callParams.totalAmountIn > order.numbers.initialCollateralDeltaAmount) {
            callParams.profit = callParams.totalAmountIn - order.numbers.initialCollateralDeltaAmount;
        }

        mirrorPosition.traderSize -= request.puppetSizeDelta;
        mirrorPosition.traderCollateral -= request.puppetCollateralDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        uint puppetListLength = mirrorPosition.puppetList.length;

        uint[] memory outputAmountList = new uint[](puppetListLength);
        uint[] memory contributionList = new uint[](puppetListLength);

        for (uint i = 0; i < puppetListLength; i++) {
            if (mirrorPosition.collateralList[i] == 0) continue;

            (uint performanceFee, uint traderCutoff, uint amountOutAfterFee) = getDistribution(
                config.performanceFeeRate,
                config.traderPerformanceFeeShare,
                mirrorPosition.collateralList[i] * callParams.profit / mirrorPosition.puppetCollateral
            );

            callParams.totalPerformanceFee += performanceFee;
            callParams.traderPerformanceCutoffFee += traderCutoff;

            contributionList[i] = performanceFee;
            outputAmountList[i] += amountOutAfterFee;
        }

        IERC20 outputToken = IERC20(eventLogData.addressItems.items[0].value);

        puppetStore.increaseBalanceList(outputToken, address(this), mirrorPosition.puppetList, outputAmountList);

        if (callParams.profit > 0) {
            contributeStore.contributeMany(outputToken, address(this), mirrorPosition.puppetList, contributionList);

            contributeStore.contribute(
                outputToken, address(this), mirrorPosition.trader, callParams.traderPerformanceCutoffFee
            );
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (mirrorPosition.traderSize == order.numbers.sizeDeltaUsd) {
            positionStore.removeMirrorPosition(request.positionKey);
        } else {
            positionStore.setMirrorPosition(request.positionKey, mirrorPosition);
        }

        positionStore.removeRequestDecrease(requestKey);

        logEvent(
            "execute",
            abi.encode(
                mirrorPosition.traderSize,
                mirrorPosition.traderCollateral,
                mirrorPosition.puppetSize,
                mirrorPosition.puppetCollateral,
                mirrorPosition.cumulativeTransactionCost,
                callParams.totalAmountIn,
                callParams.profit,
                callParams.totalPerformanceFee,
                callParams.traderPerformanceCutoffFee
            )
        );
    }

    function getDistribution(
        uint performanceFeeRate,
        uint traderPerformanceFeeShare,
        uint profit
    ) internal pure returns (uint performanceFee, uint traderPerformanceCutoffFee, uint amountOutAfterFee) {
        performanceFee = Precision.applyFactor(performanceFeeRate, profit);
        amountOutAfterFee = profit - performanceFee;

        traderPerformanceCutoffFee = Precision.applyFactor(traderPerformanceFeeShare, performanceFee);

        performanceFee -= traderPerformanceCutoffFee;

        return (performanceFee, traderPerformanceCutoffFee, amountOutAfterFee);
    }

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;

        logEvent("setConfig", abi.encode(_config));
    }

    error ExecuteDecreasePositionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecuteDecreasePositionLogic__UnexpectedEventData();
}
