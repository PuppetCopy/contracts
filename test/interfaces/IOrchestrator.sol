// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IOrchestrator {

    struct GMXInfo {
        address gmxRouter;
        address gmxReader;
        address gmxVault;
        address gmxPositionRouter;
        address gmxReferralRebatesSender;
    }
}