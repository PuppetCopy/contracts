// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library GmxOrder {
    struct CallParams {
        address market;
        address collateralToken;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        address[] puppetList;
    }
}
