// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IStage} from "./IStage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

struct PositionParams {
    IStage[] stages;
    bytes32[][] positionKeys;
}

struct CallIntent {
    address account;
    IERC7579Account subaccount;
    IERC20 token;
    uint amount;
    uint triggerNetValue;
    uint acceptableNetValue;
    bytes32 positionParamsHash;
    uint deadline;
    uint nonce;
}

struct SubaccountInfo {
    address account;
    address signer;
    IERC20 baseToken;
    bytes32 name;
    bool disposed;
    uint nonce;
    uint chainId;
    address stage;
    address subaccount;
}
