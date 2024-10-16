// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
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
        ContributeStore _contributeStore,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("AllocationLogic", "1", _authority) {
        positionStore = _positionStore;
        puppetStore = _puppetStore;
        contributeStore = _contributeStore;
    }

    function allocate(
        IERC20 collateralToken,
        bytes32 sourceRequestKey,
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

        allocation.allocated += puppetStore.allocatePuppetList(
            collateralToken, matchKey, allocationKey, puppetList, balanceToAllocationList
        );
        puppetStore.setAllocation(allocationKey, allocation);

        uint transactionCost = (startGas - gasleft()) * tx.gasprice;

        _logEvent(
            "Allocate",
            abi.encode(
                collateralToken,
                sourceRequestKey,
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

        bytes32 puppetListHash = keccak256(abi.encode(puppetList));
        if (puppetStore.getSettledAllocationHash(puppetListHash) != allocationKey) {
            revert Error.AllocationLogic__InvalidPuppetListIntegrity();
        }
        puppetStore.setSettledAllocationHash(puppetListHash, allocationKey);

        (uint[] memory balanceList, uint[] memory allocationList) =
            puppetStore.getBalanceAndAllocationList(allocation.collateralToken, allocationKey, puppetList);

        uint[] memory contributionAmountList = new uint[](puppetList.length);
        uint totalPuppetContribution;
        uint traderPerformanceContribution;

        if (allocation.profit > 0) {
            totalPuppetContribution = Precision.applyFactor(config.performanceContributionRate, allocation.profit);

            if (config.traderPerformanceContributionShare > 0) {
                traderPerformanceContribution =
                    Precision.applyFactor(config.traderPerformanceContributionShare, allocation.profit);

                contributeStore.interTransferIn(allocation.collateralToken, positionStore, totalPuppetContribution);
                contributeStore.contribute(
                    allocation.collateralToken,
                    positionStore.getSubaccount(allocation.matchKey).account(),
                    traderPerformanceContribution
                );
            }

            uint settledAfterContribution = allocation.settled - totalPuppetContribution - traderPerformanceContribution;

            for (uint i = 0; i < allocationList.length; i++) {
                uint puppetAllocation = allocationList[i];
                if (puppetAllocation == 0) continue;

                contributionAmountList[i] = puppetAllocation * totalPuppetContribution / allocation.allocated;
                balanceList[i] += puppetAllocation * settledAfterContribution / allocation.allocated;
            }

            contributeStore.interTransferIn(allocation.collateralToken, positionStore, totalPuppetContribution);
            contributeStore.contributeMany(allocation.collateralToken, puppetList, contributionAmountList);
        } else if (allocation.settled > 0) {
            for (uint i = 0; i < allocationList.length; i++) {
                uint puppetAllocation = allocationList[i];
                if (puppetAllocation == 0) continue;

                balanceList[i] += puppetAllocation * allocation.settled / allocation.allocated;
            }
        }

        puppetStore.setBalanceList(allocation.collateralToken, puppetList, allocationList);

        if (allocation.size > 0) {
            allocation.profit = 0;
            allocation.allocated -= allocation.settled;

            puppetStore.setAllocation(allocationKey, allocation);
        } else {
            puppetStore.removeAllocation(allocationKey);
        }

        _logEvent(
            "Settle",
            abi.encode(
                allocation.collateralToken,
                allocation.matchKey,
                allocationKey,
                puppetListHash,
                puppetList,
                allocationList,
                contributionAmountList,
                allocation.allocated,
                allocation.settled,
                totalPuppetContribution,
                traderPerformanceContribution,
                (startGas - gasleft()) * tx.gasprice,
                allocation.profit
            )
        );
    }

    // internal

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
