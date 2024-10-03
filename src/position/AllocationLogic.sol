// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
import {PositionUtils} from "./utils/PositionUtils.sol";

contract AllocationLogic is CoreContract {
    struct Config {
        uint limitAllocationListLength;
        uint performanceContributionRate;
        uint traderPerformanceContributionShare;
    }

    struct AllocateParams {
        IERC20 collateralToken;
        address market;
        address trader;
        address[] puppetList;
    }

    MirrorPositionStore immutable positionStore;
    PuppetStore immutable puppetStore;
    ContributeStore immutable contributeStore;

    Config public config;

    function getValidPuppetIndex(
        address[] calldata puppetList,
        PuppetStore.Allocation memory allocation
    ) public pure returns (uint) {
        uint validMatchListIntegrityLength = allocation.matchHashList.length;

        if (validMatchListIntegrityLength == 0) {
            return 0;
        }

        for (uint i = 0; i < validMatchListIntegrityLength; i++) {
            if (allocation.matchHashList[i] == keccak256(abi.encode(puppetList))) {
                return i;
            }
        }

        return 0;
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        ContributeStore _contributeStore,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("AllocationLogic", "1", _authority, _eventEmitter) {
        positionStore = _positionStore;
        puppetStore = _puppetStore;
        contributeStore = _contributeStore;
    }

    function allocate(AllocateParams calldata params) external auth {
        uint startGas = gasleft();
        uint puppetListLength = params.puppetList.length;

        if (puppetListLength > config.limitAllocationListLength) {
            revert Error.AllocationLogic__PuppetListLimit();
        }

        bytes32 matchKey = PositionUtils.getMatchKey(params.collateralToken, params.market, params.trader);

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(matchKey);

        if (allocation.allocated == 0) {
            allocation.collateralToken = params.collateralToken;
        }

        (uint[] memory rateList, uint[] memory activityThrottleList, uint[] memory balanceToAllocationList) =
            puppetStore.getBalanceAndActivityThrottleList(params.collateralToken, matchKey, params.puppetList);

        for (uint i = 0; i < puppetListLength; i++) {
            // Thorttle user allocation if the activityThrottle is within range
            if (block.timestamp > activityThrottleList[i]) {
                balanceToAllocationList[i] = Precision.applyBasisPoints(rateList[i], balanceToAllocationList[i]);
            } else {
                balanceToAllocationList[i] = 0;
            }
        }

        uint allocated =
            puppetStore.allocatePuppetList(params.collateralToken, matchKey, params.puppetList, balanceToAllocationList);

        allocation.allocated += allocated;
        puppetStore.setAllocation(matchKey, allocation);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        logEvent(
            "Allocate",
            abi.encode(
                params.collateralToken,
                matchKey,
                transactionCost,
                params.puppetList,
                balanceToAllocationList,
                allocation.allocated,
                allocated
            )
        );
    }

    function settleList(bytes32 settlementKey, address[] calldata puppetList) external auth {
        uint startGas = gasleft();

        PuppetStore.Settlement memory settlement = puppetStore.getSettlement(settlementKey);
        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(settlement.matchKey);

        uint validPuppetListIndex = getValidPuppetIndex(puppetList, allocation);

        if (validPuppetListIndex == 0) {
            revert Error.AllocationLogic__InvalidPuppetListIntegrity();
        }

        allocation.matchHashList[validPuppetListIndex] = 0;

        uint profit = settlement.settled > allocation.allocated ? settlement.settled - allocation.allocated : 0;
        uint puppetContribution = Precision.applyFactor(config.performanceContributionRate, profit);
        uint traderPerformanceContribution = Precision.applyFactor(config.traderPerformanceContributionShare, profit);

        uint[] memory allocationToSettledAmountList = puppetStore.getAllocationList(settlement.matchKey, puppetList);
        uint[] memory contributionAmountList = new uint[](puppetList.length);

        for (uint i = 0; i < allocationToSettledAmountList.length; i++) {
            uint puppetAllocation = allocationToSettledAmountList[i];

            if (puppetAllocation <= 1) continue;

            uint contributionAmount = puppetAllocation * puppetContribution / allocation.allocated;
            contributionAmountList[i] = contributionAmount;
            allocationToSettledAmountList[i] = puppetAllocation - contributionAmount;
        }

        puppetStore.settleList(allocation.collateralToken, puppetList, allocationToSettledAmountList);
        contributeStore.contributeMany(allocation.collateralToken, puppetStore, puppetList, contributionAmountList);

        if (traderPerformanceContribution > 0) {
            contributeStore.contribute(
                allocation.collateralToken,
                positionStore,
                positionStore.getSubaccount(settlement.matchKey).account(),
                traderPerformanceContribution
            );
        }

        puppetStore.removeSettlement(settlement.matchKey);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        logEvent(
            "SettleList",
            abi.encode(
                settlementKey,
                transactionCost,
                puppetList,
                puppetContribution,
                traderPerformanceContribution,
                allocationToSettledAmountList,
                contributionAmountList
            )
        );
    }

    // governance

    function setConfig(Config memory _config) external auth {
        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
