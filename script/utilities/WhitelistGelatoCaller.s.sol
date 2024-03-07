// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {DeployerUtilities} from "./DeployerUtilities.sol";

// ---- Usage ----
// forge script script/utilities/WhitelistGelatoCaller.s.sol:WhitelistGelatoCaller --legacy --rpc-url $RPC_URL --broadcast

contract WhitelistGelatoCaller is DeployerUtilities {
  function run() public {
    vm.startBroadcast(_deployerPrivateKey);

    address _caller = 0x3dc4D3F38B820F717F2ddb516bCA96Ce3a3879AD;
    _setUserRole(_caller, 1, true);

    vm.stopBroadcast();
  }
}
