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

contract ExecuteDecreasePositionLogic is CoreContract {
    struct Config {
        address gmxOrderReciever;
        uint performanceFeeRate;
        uint traderPerformanceFeeShare;
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
    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        ContributeStore _contributeStore,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("ExecuteDecreasePositionLogic", "1", _authority, _eventEmitter) {
        contributeStore = _contributeStore;
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function execute(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) external auth {
        MirrorPositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        if (request.positionKey == bytes32(0)) {
            revert Error.ExecuteDecreasePositionLogic__RequestDoesNotExist();
        }

        MirrorPositionStore.AllocationMatch memory allocation = positionStore.getAllocationMatchMap(request.allocationKey);
        MirrorPositionStore.Position memory position = positionStore.getPosition(request.positionKey);

        CallParams memory callParams = CallParams({
            recordedAmountIn: puppetStore.recordedTransferIn(allocation.collateralToken),
            performanceFee: 0,
            traderPerformanceFee: 0,
            profit: 0
        });

        if (position.traderSize == 0) {
            revert Error.ExecuteDecreasePositionLogic__InvalidRequest(request.positionKey, requestKey);
        }

        if (callParams.recordedAmountIn > position.puppetCollateral) {
            callParams.profit = callParams.recordedAmountIn - position.puppetCollateral;
        }

        position.traderSize -= request.puppetSizeDelta;
        position.traderCollateral -= request.puppetCollateralDelta;
        position.cumulativeTransactionCost += request.transactionCost;

        uint puppetListLength = allocation.puppetList.length;

        uint[] memory collateralList = new uint[](puppetListLength);
        uint[] memory contributionList = new uint[](puppetListLength);

        for (uint i = 0; i < puppetListLength; i++) {
            if (allocation.collateralList[i] == 0) continue;

            (uint performanceFee, uint traderCutoff, uint amountOutAfterFee) = getDistribution(
                allocation.collateralList[i] * callParams.profit / position.puppetCollateral,
                config.performanceFeeRate,
                config.traderPerformanceFeeShare
            );

            callParams.performanceFee += performanceFee;
            callParams.traderPerformanceFee += traderCutoff;

            collateralList[i] += amountOutAfterFee;
            contributionList[i] = performanceFee;
        }

        puppetStore.increaseBalanceList(allocation.collateralToken, allocation.puppetList, collateralList);

        if (callParams.profit > 0) {
            contributeStore.contributeMany(
                allocation.collateralToken, puppetStore, allocation.puppetList, contributionList
            );

            contributeStore.contribute(
                allocation.collateralToken, puppetStore, allocation.trader, callParams.traderPerformanceFee
            );
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (request.traderSizeDelta >= position.traderSize) {
            positionStore.removePosition(request.positionKey);
        } else {
            positionStore.setPosition(request.positionKey, position);
        }

        positionStore.removeRequestDecrease(requestKey);

        logEvent(
            "execute",
            abi.encode(
                requestKey,
                request.positionKey,
                position.traderSize,
                position.traderCollateral,
                position.puppetSize,
                position.puppetCollateral,
                position.cumulativeTransactionCost,
                callParams.recordedAmountIn,
                callParams.profit,
                callParams.performanceFee,
                callParams.traderPerformanceFee
            )
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

        logEvent("setConfig", abi.encode(_config));
    }
}
