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

    struct CallAllocateParams {
        IERC20 collateralToken;
        bytes32 originRequestKey;
        bytes32 matchKey;
        address market;
        address trader;
        address[] puppetList;
    }

    struct CallSettleParams {
        bytes32 allocationKey;
        address[] puppetList;
    }

    struct AllocationData {
        uint[] rateList;
        uint[] activityThrottleList;
        uint[] balanceToAllocationList;
        bytes32 puppetListHash;
    }

    MirrorPositionStore immutable positionStore;
    PuppetStore immutable puppetStore;
    ContributeStore immutable contributeStore;

    Config public config;

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

    function allocate(CallAllocateParams calldata params) external auth returns (bytes32 allocationKey) {
        uint startGas = gasleft();
        uint puppetListLength = params.puppetList.length;

        if (puppetListLength > config.limitAllocationListLength) {
            revert Error.AllocationLogic__PuppetListLimit();
        }

        allocationKey = PositionUtils.getAllocationKey(params.matchKey, puppetStore.getRequestId());

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(allocationKey);

        if (allocation.matchKey == bytes32(0)) {
            allocation.matchKey = params.matchKey;
            allocation.collateralToken = params.collateralToken;
            allocationKey = PositionUtils.getAllocationKey(params.matchKey, puppetStore.incrementRequestId());
        }

        AllocationData memory allocationData = getAllocationData(params);

        for (uint i = 0; i < puppetListLength; i++) {
            // Thorttle user allocation if the activityThrottle is within range
            if (block.timestamp > allocationData.activityThrottleList[i]) {
                allocationData.balanceToAllocationList[i] =
                    Precision.applyBasisPoints(allocationData.rateList[i], allocationData.balanceToAllocationList[i]);
            } else {
                allocationData.balanceToAllocationList[i] = 0;
            }
        }

        puppetStore.setSettledAllocationHash(allocationData.puppetListHash, allocationKey);

        allocation.allocated += puppetStore.allocatePuppetList(
            params.collateralToken, allocationKey, params.puppetList, allocationData.balanceToAllocationList
        );
        puppetStore.setAllocation(allocationKey, allocation);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        logEvent(
            "Allocate",
            abi.encode(
                params.collateralToken,
                params.originRequestKey,
                params.matchKey,
                allocationKey,
                allocationData.puppetListHash,
                params.puppetList,
                allocationData.balanceToAllocationList,
                allocation.allocated,
                transactionCost
            )
        );
    }

    function getAllocationData(CallAllocateParams calldata params) internal view returns (AllocationData memory data) {
        uint puppetListLength = params.puppetList.length;

        data.rateList = new uint[](puppetListLength);
        data.activityThrottleList = new uint[](puppetListLength);
        data.balanceToAllocationList = new uint[](puppetListLength);
        data.puppetListHash = keccak256(abi.encode(params.puppetList));

        for (uint i = 0; i < puppetListLength; i++) {
            (data.rateList[i], data.activityThrottleList[i], data.balanceToAllocationList[i]) =
                puppetStore.getBalanceAndActivityThrottle(params.collateralToken, params.matchKey, params.puppetList[i]);
        }
    }

    function settle(CallSettleParams calldata params) external auth {
        uint startGas = gasleft();

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(params.allocationKey);

        if (allocation.matchKey == bytes32(0)) {
            revert Error.AllocationLogic__AllocationDoesNotExist();
        }

        if (allocation.collateral > 0) {
            revert Error.AllocationLogic__AllocationStillUtilized();
        }

        bytes32 listHash = keccak256(abi.encode(params.puppetList));

        if (puppetStore.getSettledAllocationHash(listHash) != params.allocationKey) {
            revert Error.AllocationLogic__InvalidPuppetListIntegrity();
        } else {
            puppetStore.setSettledAllocationHash(listHash, params.allocationKey);
        }

        uint profit = allocation.settled > allocation.allocated ? allocation.settled - allocation.allocated : 0;
        uint puppetContribution = Precision.applyFactor(config.performanceContributionRate, profit);
        uint traderPerformanceContribution = Precision.applyFactor(config.traderPerformanceContributionShare, profit);

        uint[] memory allocationToSettledAmountList =
            puppetStore.getUserAllocationList(params.allocationKey, params.puppetList);
        uint[] memory contributionAmountList = new uint[](params.puppetList.length);

        for (uint i = 0; i < allocationToSettledAmountList.length; i++) {
            uint puppetAllocation = allocationToSettledAmountList[i];

            if (puppetAllocation == 0) continue;

            uint contributionAmount = puppetAllocation * puppetContribution / allocation.allocated;
            contributionAmountList[i] = contributionAmount;
            allocationToSettledAmountList[i] = puppetAllocation - contributionAmount;
        }

        puppetStore.settleList(allocation.collateralToken, params.puppetList, allocationToSettledAmountList);
        contributeStore.contributeMany(
            allocation.collateralToken, puppetStore, params.puppetList, contributionAmountList
        );

        if (traderPerformanceContribution > 0) {
            contributeStore.contribute(
                allocation.collateralToken,
                positionStore,
                positionStore.getSubaccount(allocation.matchKey).account(),
                traderPerformanceContribution
            );
        }

        puppetStore.removeAllocation(params.allocationKey);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        logEvent(
            "Settle",
            abi.encode(
                allocation.matchKey,
                params.allocationKey,
                listHash,
                params.puppetList,
                allocationToSettledAmountList,
                profit,
                puppetContribution,
                traderPerformanceContribution,
                contributionAmountList,
                transactionCost
            )
        );
    }

    // governance

    function setConfig(Config memory _config) external auth {
        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
