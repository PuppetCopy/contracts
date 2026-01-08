// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Error} from "../utils/Error.sol";
import {IUserRouter} from "../utils/interfaces/IUserRouter.sol";

/// @title MasterHook
/// @notice ERC-7579 Hook module for master accounts enabling fund-raising through Allocation
contract MasterHook is IHook {
    struct InstallParams {
        address user;
        address signer;
        IERC20 baseToken;
        bytes32 name;
    }

    IUserRouter public immutable router;

    constructor(IUserRouter _router) {
        router = _router;
    }

    function preCheck(address msgSender, uint msgValue, bytes calldata msgData) external returns (bytes memory) {
        return router.processPreCall(msgSender, msg.sender, msgValue, msgData);
    }

    function postCheck(bytes calldata hookData) external {
        router.processPostCall(hookData);
    }

    function onInstall(bytes calldata _data) external {
        IERC7579Account _masterAccount = IERC7579Account(msg.sender);

        if (router.isDisposed(_masterAccount) && router.hasRemainingShares(_masterAccount)) revert Error.Allocate__DisposedWithShares();

        InstallParams memory params = abi.decode(_data, (InstallParams));

        router.createMasterAccount(params.user, params.signer, _masterAccount, params.baseToken, params.name);
    }

    function onUninstall(bytes calldata) external {
        router.disposeMasterAccount(IERC7579Account(msg.sender));
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _account) external view returns (bool) {
        return !router.isDisposed(IERC7579Account(_account));
    }
}
