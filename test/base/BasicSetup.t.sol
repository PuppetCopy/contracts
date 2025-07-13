// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {IWNT} from "src/utils/interfaces/IWNT.sol";

import {Test} from "forge-std/src/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract BasicSetup is Test {
    struct Users {
        address payable owner;
        address payable alice;
        address payable bob;
        address payable yossi;
    }

    Users users;

    MockERC20 wnt = new MockERC20("Wrapped Native", "WNT", 18);
    MockERC20 usdc = new MockERC20("USDC", "USDC", 6);

    Dictatorship dictator;
    PuppetToken puppetToken;
    TokenRouter tokenRouter;
    PuppetVoteToken vPuppetToken;

    function setUp() public virtual {
        vm.deal(users.owner, 100 ether);

        users = Users({
            owner: _createUser("Owner"), //
            alice: _createUser("Alice"),
            bob: _createUser("Bob"),
            yossi: _createUser("Yossi")
        });

        vm.startPrank(users.owner);

        dictator = new Dictatorship(users.owner);
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config(200_000));
        dictator.initContract(tokenRouter);
        puppetToken = new PuppetToken(users.owner);
        vPuppetToken = new PuppetVoteToken(dictator);

        // Owner funding operations
        puppetToken.approve(address(tokenRouter), type(uint).max);
        usdc.mint(users.owner, 2000e6);
        wnt.mint(users.owner, 2000e18);
        wnt.approve(address(tokenRouter), type(uint).max);
        usdc.approve(address(tokenRouter), type(uint).max);

        skip(1 hours);
    }

    function _getNextContractAddress() internal view returns (address) {
        return vm.computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1);
    }

    function _getNextContractAddress(
        uint count
    ) internal view returns (address) {
        return vm.computeCreateAddress(users.owner, vm.getNonce(users.owner) + count);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets
    function _createUser(
        string memory _name
    ) internal virtual returns (address payable) {
        address payable _user = payable(makeAddr(_name));

        vm.deal(_user, 100 ether);
        // deal(address(_wnt), 100);
        return _user;
    }

    function _dealERC20(MockERC20 _token, address _user, uint _amount) internal {
        _amount = _token.balanceOf(_user) + _amount;
        _token.mint(_user, _amount);
    }
}
