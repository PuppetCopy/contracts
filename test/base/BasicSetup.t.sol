// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Test } from "forge-std/src/Test.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Router} from "src/shared/Router.sol";
import {IWNT} from "./../../src/utils/interfaces/IWNT.sol";

contract BasicSetup is Test {
    struct Users {
        address payable owner;
        address payable alice;
        address payable bob;
        address payable yossi;
    }

    Users users;

    IWNT wnt = IWNT(address(deployMockERC20("Wrapped Native", "WNT", 18)));
    IERC20 usdc = IERC20(address(deployMockERC20("USDC", "USDC", 18)));

    Dictator dictator;
    PuppetToken puppetToken;
    Router router;

    function setUp() public virtual {
        vm.deal(users.owner, 100 ether);

        users = Users({
            owner: _createUser("Owner"), //
            alice: _createUser("Alice"),
            bob: _createUser("Bob"),
            yossi: _createUser("Yossi")
        });
        vm.startPrank(users.owner);

        dictator = new Dictator(users.owner);
        router = new Router(dictator, 200_000);
        puppetToken = new PuppetToken(dictator, PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}), users.owner);

        skip(1 hours);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets
    function _createUser(string memory _name) internal virtual returns (address payable) {
        address payable _user = payable(makeAddr(_name));

        vm.deal(_user, 100 ether);
        // deal(address(_wnt), 100);
        return _user;
    }

    function _dealERC20(address _token, address _user, uint _amount) internal {
        _amount = IERC20(_token).balanceOf(_user) + _amount;
        deal({token: _token, to: _user, give: _amount});
    }
}
