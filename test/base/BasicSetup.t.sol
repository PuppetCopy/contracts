// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StdCheats} from "forge-std/src/StdCheats.sol";
import {StdUtils} from "forge-std/src/StdUtils.sol";
import {PRBTest} from "@prb/test/src/PRBTest.sol";

import {Dictator} from "src/utils/Dictator.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Router} from "src/utils/Router.sol";
import {WNT} from "src/utils/WNT.sol";

contract BasicSetup is PRBTest, StdCheats, StdUtils {
    struct Users {
        address payable owner;
        address payable alice;
        address payable bob;
        address payable yossi;
    }

    uint8 constant TOKEN_ROUTER_ROLE = 0;
    uint8 constant PUPPET_MINTER_ROLE = 1;

    uint internal constant BASIS_POINTS_DIVISOR = 10_000;
    Users users;
    WNT wnt;
    Dictator dictator;
    PuppetToken puppetToken;
    Router router;

    function setUp() public virtual {
        address payable owner = payable(makeAddr("Owner"));
        vm.deal(owner, 100 ether);

        dictator = new Dictator(owner);

        vm.startPrank(owner);

        users = Users({owner: owner, alice: _createUser("Alice", 2), bob: _createUser("Bob", 2), yossi: _createUser("Yossi", 2)});

        puppetToken = new PuppetToken(dictator);
        dictator.setRoleCapability(PUPPET_MINTER_ROLE, address(puppetToken), puppetToken.mint.selector, true);

        router = new Router(dictator);
        dictator.setRoleCapability(TOKEN_ROUTER_ROLE, address(router), router.pluginTransfer.selector, true);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets
    function _createUser(string memory _name, uint8 _role) internal virtual returns (address payable) {
        address payable _user = payable(makeAddr(_name));
        dictator.setUserRole(_user, _role, true);

        vm.deal(_user, 100 ether);
        // deal(address(_wnt), 100);
        return _user;
    }

    function _dealERC20(address _token, address _user, uint _amount) internal {
        _amount = IERC20(_token).balanceOf(_user) + (_amount * 10 ** 18);
        deal({token: _token, to: _user, give: _amount});
    }
}
