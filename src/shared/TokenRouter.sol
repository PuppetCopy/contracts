// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CallUtils} from "../utils/CallUtils.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @title TokenRouter
 * @dev Central token router and spending approval for transferring tokens
 */
contract TokenRouter is CoreContract {
    struct Config {
        uint transferGasLimit;
    }

    Config public config;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority) {
        authority = _authority;

        _setConfig(abi.encode(_config));
    }

    /**
     * @dev low level call to an ERC20 contract, return raw data to be handled by authorised contract
     * @param token the token to transfer
     * @param from the account to transfer from
     * @param to the account to transfer to
     * @param amount the amount to transfer
     */
    function transfer(IERC20 token, address from, address to, uint amount) external auth {
        CallUtils.callTarget(
            config.transferGasLimit, address(token), abi.encodeCall(token.transferFrom, (from, to, amount))
        );
    }

    function _setConfig(
        bytes memory _data
    ) internal virtual override {
        config = abi.decode(_data, (Config));

        require(config.transferGasLimit > 0, Error.TokenRouter__EmptyTokenTranferGasLimit());
    }
}
