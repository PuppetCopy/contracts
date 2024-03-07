// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface IWETH {
	function deposit() external payable;

	function withdraw(uint256 wad) external;

	function decimals() external view returns (uint8);
}
