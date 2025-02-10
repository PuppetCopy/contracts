// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {FeeMarketplace} from "../tokenomics/FeeMarketplace.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract AllocationLogic is CoreContract {
    struct Config {
        uint limitAllocationListLength;
        uint performanceContributionRate;
        uint traderPerformanceContributionShare;
    }

    PositionStore immutable positionStore;
    PuppetStore immutable puppetStore;
    FeeMarketplace immutable feeMarket;

    Config public config;

    constructor(
        IAuthority _authority,
        FeeMarketplace _feeMarketplace,
        PuppetStore _puppetStore,
        PositionStore _positionStore
    ) CoreContract("AllocationLogic", "1", _authority) {
        feeMarket = _feeMarketplace;
        positionStore = _positionStore;
        puppetStore = _puppetStore;
    }

    function allocate(
        IERC20 collateralToken,
        bytes32 sourceRequestKey,
        bytes32 matchKey,
        bytes32 positionKey,
        address[] calldata puppetList
    ) external auth returns (bytes32 allocationKey) {
        uint startGas = gasleft();

        allocationKey = PositionUtils.getAllocationKey(matchKey, positionKey);

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(allocationKey);

        if (allocation.size > 0) {
            revert Error.AllocationLogic__PendingSettlment();
        }
        uint puppetListLength = puppetList.length;

        if (puppetListLength > config.limitAllocationListLength) {
            revert Error.AllocationLogic__PuppetListLimit();
        }

        if (allocation.matchKey == bytes32(0)) {
            allocation.matchKey = matchKey;
            allocation.collateralToken = collateralToken;
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
                positionKey,
                allocationKey,
                puppetListHash,
                puppetList,
                activityThrottleList,
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
            revert Error.AllocationLogic__UtillizedAllocationed();
        }

        bytes32 puppetListHash = keccak256(abi.encode(puppetList));
        if (puppetStore.getSettledAllocationHash(puppetListHash) != allocationKey) {
            revert Error.AllocationLogic__InvalidPuppetListIntegrity();
        }
        puppetStore.setSettledAllocationHash(puppetListHash, allocationKey);

        (uint[] memory balanceList, uint[] memory allocationList) =
            puppetStore.getBalanceAndAllocationList(allocation.collateralToken, allocationKey, puppetList);

        uint totalPuppetContribution;

        if (allocation.profit > 0) {
            totalPuppetContribution = Precision.applyFactor(config.performanceContributionRate, allocation.profit);

            uint settledAfterContribution = allocation.settled - totalPuppetContribution;

            for (uint i = 0; i < allocationList.length; i++) {
                uint puppetAllocation = allocationList[i];
                if (puppetAllocation == 0) continue;

                balanceList[i] += puppetAllocation * settledAfterContribution / allocation.allocated;
            }

            if (feeMarket.askPrice(allocation.collateralToken) > 0) {
                feeMarket.deposit(allocation.collateralToken, address(positionStore), totalPuppetContribution);
            }

        } else if (allocation.settled > 0) {
            for (uint i = 0; i < allocationList.length; i++) {
                uint puppetAllocation = allocationList[i];
                if (puppetAllocation == 0) continue;

                balanceList[i] += puppetAllocation * allocation.settled / allocation.allocated;
            }
        }

        puppetStore.setBalanceList(allocation.collateralToken, puppetList, balanceList);

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
                totalPuppetContribution,
                (startGas - gasleft()) * tx.gasprice,
                allocation.allocated,
                allocation.settled,
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
