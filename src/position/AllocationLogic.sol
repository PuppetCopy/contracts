// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

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

    function allocate(
        IERC20 collateralToken,
        bytes32 originRequestKey,
        bytes32 matchKey,
        address[] calldata puppetList
    ) external auth returns (bytes32 allocationKey) {
        uint startGas = gasleft();

        allocationKey = PositionUtils.getAllocationKey(matchKey, puppetStore.getRequestId());

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(allocationKey);

        if (allocation.matchKey == bytes32(0)) {
            allocation.matchKey = matchKey;
            allocation.collateralToken = collateralToken;
            allocationKey = PositionUtils.getAllocationKey(matchKey, puppetStore.incrementRequestId());
        }

        uint puppetListLength = puppetList.length;

        if (puppetListLength > config.limitAllocationListLength) {
            revert Error.AllocationLogic__PuppetListLimit();
        }

        bytes32 puppetListHash = keccak256(abi.encode(puppetList));

        (
            PuppetStore.MatchRule[] memory ruleList,
            uint[] memory activityThrottleList,
            uint[] memory balanceToAllocationList
        ) = puppetStore.getBalanceAndActivityThrottleList(collateralToken, matchKey, puppetList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.MatchRule memory rule = ruleList[i];
            // Thorttle user allocation if the activityThrottle is within range
            if (rule.expiry > block.timestamp && block.timestamp > activityThrottleList[i]) {
                balanceToAllocationList[i] = Precision.applyBasisPoints(rule.allowanceRate, balanceToAllocationList[i]);
            } else {
                balanceToAllocationList[i] = 0;
            }
        }

        puppetStore.setSettledAllocationHash(puppetListHash, allocationKey);

        allocation.allocated +=
            puppetStore.allocatePuppetList(collateralToken, allocationKey, puppetList, balanceToAllocationList);
        puppetStore.setAllocation(allocationKey, allocation);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        logEvent(
            "Allocate",
            abi.encode(
                collateralToken,
                originRequestKey,
                matchKey,
                allocationKey,
                puppetListHash,
                puppetList,
                balanceToAllocationList,
                allocation.allocated,
                transactionCost
            )
        );
    }

    function settle(bytes32 allocationKey, address[] calldata puppetList) external auth {
        uint startGas = gasleft();

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(allocationKey);
        if (allocation.matchKey == bytes32(0)) {
            revert Error.AllocationLogic__AllocationDoesNotExist();
        }
        if (allocation.collateral > 0) {
            revert Error.AllocationLogic__AllocationStillUtilized();
        }

        bytes32 listHash = keccak256(abi.encode(puppetList));
        if (puppetStore.getSettledAllocationHash(listHash) != allocationKey) {
            revert Error.AllocationLogic__InvalidPuppetListIntegrity();
        }
        puppetStore.setSettledAllocationHash(listHash, allocationKey);

        uint[] memory allocationToSettledAmountList = puppetStore.getUserAllocationList(allocationKey, puppetList);
        uint[] memory contributionAmountList = new uint[](puppetList.length);
        uint totalContribution;
        int profit = int(allocation.settled) - int(allocation.allocated);

        if (profit > 0) {
            totalContribution = Precision.applyFactor(config.performanceContributionRate, uint(profit));
            uint traderContribution = Precision.applyFactor(config.traderPerformanceContributionShare, uint(profit));

            for (uint i = 0; i < allocationToSettledAmountList.length; i++) {
                uint puppetAllocation = allocationToSettledAmountList[i];
                if (puppetAllocation > 0) {
                    contributionAmountList[i] = puppetAllocation * totalContribution / allocation.allocated;
                    allocationToSettledAmountList[i] -= contributionAmountList[i];
                }
            }

            if (traderContribution > 0) {
                contributeStore.contribute(
                    allocation.collateralToken,
                    positionStore,
                    positionStore.getSubaccount(allocation.matchKey).account(),
                    traderContribution
                );
            }
        } else if (allocation.settled > 0) {
            for (uint i = 0; i < allocationToSettledAmountList.length; i++) {
                uint puppetAllocation = allocationToSettledAmountList[i];
                if (puppetAllocation > 0) {
                    contributionAmountList[i] = puppetAllocation * allocation.settled / allocation.allocated;
                    allocationToSettledAmountList[i] -= contributionAmountList[i];
                }
            }
        }

        puppetStore.settleList(allocation.collateralToken, puppetList, allocationToSettledAmountList);
        if (totalContribution > 0) {
            contributeStore.contributeMany(allocation.collateralToken, puppetStore, puppetList, contributionAmountList);
        }
        puppetStore.removeAllocation(allocationKey);

        logEvent(
            "Settle",
            abi.encode(
                allocation.collateralToken,
                allocation.matchKey,
                allocationKey,
                listHash,
                puppetList,
                allocationToSettledAmountList,
                contributionAmountList,
                profit, // Now a single value for both profit and loss
                allocation.settled,
                totalContribution,
                (startGas - gasleft()) * tx.gasprice
            )
        );
    }

    // governance
    function setConfig(
        Config memory _config
    ) external auth {
        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
