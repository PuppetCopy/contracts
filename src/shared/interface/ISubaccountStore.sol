// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface ISubaccountStore {
    function getSubaccountOperator() external view returns (address);
}
