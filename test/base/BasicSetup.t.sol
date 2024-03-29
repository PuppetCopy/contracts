// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StdCheats} from "forge-std/src/StdCheats.sol";
import {StdUtils} from "forge-std/src/StdUtils.sol";
import {PRBTest} from "@prb/test/src/PRBTest.sol";

import {Dictator} from "src/utils/Dictator.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Router} from "src/utils/Router.sol";
import {IWNT} from "./../../src/utils/interfaces/IWNT.sol";

contract BasicSetup is PRBTest, StdCheats, StdUtils {
    struct Users {
        address payable owner;
        address payable alice;
        address payable bob;
        address payable yossi;
    }

    uint8 constant ADMIN_ROLE = 0;
    uint8 constant TRANSFER_TOKEN_ROLE = 1;
    uint8 constant MINT_PUPPET_ROLE = 2;

    uint internal constant BASIS_POINTS_DIVISOR = 10_000;

    Users users;
    IWNT wnt;
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
        puppetToken = new PuppetToken(dictator);
        router = new Router(dictator);

        dictator.setRoleCapability(MINT_PUPPET_ROLE, address(puppetToken), puppetToken.mint.selector, true);
        dictator.setRoleCapability(TRANSFER_TOKEN_ROLE, address(router), router.transfer.selector, true);

        dictator.setUserRole(users.owner, ADMIN_ROLE, true);
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
