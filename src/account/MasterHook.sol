// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IHook, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Error} from "../utils/Error.sol";
import {IUserRouter} from "../utils/interfaces/IUserRouter.sol";

/// @title MasterHook
/// @notice ERC-7579 Hook module for master subaccounts enabling fund-raising through Allocation
contract MasterHook is IHook {
    struct InstallParams {
        address account;
        address signer;
        IERC20 baseToken;
        bytes32 name;
    }

    IUserRouter public immutable router;

    mapping(IERC7579Account subaccount => bool) public registered;

    constructor(IUserRouter _router) {
        router = _router;
    }

    function preCheck(address msgSender, uint msgValue, bytes calldata msgData) external returns (bytes memory) {
        return router.processPreCall(msgSender, msg.sender, msgValue, msgData);
    }

    function postCheck(bytes calldata hookData) external {
        router.processPostCall(msg.sender, hookData);
    }

    function onInstall(bytes calldata _data) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);

        if (router.isDisposed(_subaccount) && router.hasRemainingShares(_subaccount)) {
            revert Error.Allocation__DisposedWithShares();
        }

        InstallParams memory params = abi.decode(_data, (InstallParams));

        registered[_subaccount] = true;

        // Account and signer are late-validated via SignatureChecker when signing intents
        router.registerMasterSubaccount(params.account, params.signer, _subaccount, params.baseToken, params.name);
    }

    function onUninstall(bytes calldata) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        registered[_subaccount] = false;
        router.disposeSubaccount(_subaccount);
    }

    function isModuleType(uint _moduleTypeId) external pure returns (bool) {
        return _moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _account) external view returns (bool) {
        return registered[IERC7579Account(_account)];
    }
}
