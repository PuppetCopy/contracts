// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface ISubaccount {
    function getAccount() external view returns (address);
    function execute(address _to, bytes calldata _data) external payable returns (bool success, bytes memory returnData);
    function depositWnt(uint amount) external payable;
}
