// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecreaseSizeResolver} from "src/integrations/utilities/DecreaseSizeResolver.sol";
import {DeployerUtilities} from "./DeployerUtilities.sol";
import {Dictator} from "src/utilities/Dictator.sol";

// ---- Usage ----
// NOTICE: RUN ON POLYGON
// forge script script/utilities/DepositFundsToGelato1Balance.s.sol:DepositFundsToGelato1Balance --legacy --rpc-url $RPC_URL --broadcast

contract DepositFundsToGelato1Balance is DeployerUtilities {

    function run() public {
        vm.startBroadcast(_deployerPrivateKey);

        _depositFundsToGelato1Balance();

        vm.stopBroadcast();
    }

    function _depositFundsToGelato1Balance() internal {
        Dictator _dictator = new Dictator(_dictatorAddr);
        DecreaseSizeResolver _resolver = new DecreaseSizeResolver(_dictator, _gelatoAutomationPolygon, address(0));

        uint256 _amount = IERC20(_polygonUSDC).balanceOf(_deployer);
        _resolver.depositFunds(_amount, _polygonUSDC, _deployer);
    }
}