// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

library PositionUtils {
    function getMatchingKey(IERC20 _token, IERC7579Account _subaccount) internal pure returns (bytes32) {
        return keccak256(abi.encode(_token, _subaccount));
    }
}
