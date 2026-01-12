// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/src/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Const} from "script/deploy/shared/Const.sol";

/// @title ForkSetup
/// @notice Base test setup for Arbitrum fork tests
abstract contract ForkSetup is Test {
    struct Users {
        address payable owner;
        address payable alice;
        address payable bob;
        address payable trader;
    }

    Users users;

    // Real Arbitrum tokens
    IERC20 constant usdc = IERC20(Const.usdc);
    IERC20 constant wnt = IERC20(Const.wnt);

    // GMX V2 addresses
    address constant gmxExchangeRouter = Const.gmxExchangeRouter;
    address constant gmxRouter = Const.gmxRouter;
    address constant gmxDataStore = Const.gmxDataStore;
    address constant gmxOrderVault = Const.gmxOrderVault;
    address constant gmxReferralStorage = Const.gmxReferralStorage;
    address constant gmxEthUsdcMarket = Const.gmxEthUsdcMarket;

    Dictatorship dictator;

    uint256 forkId;

    function setUp() public virtual {
        // Create Arbitrum fork
        string memory rpcUrl = vm.envOr("RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            revert("RPC_URL environment variable not set");
        }
        forkId = vm.createSelectFork(rpcUrl);

        users = Users({
            owner: _createUser("Owner"),
            alice: _createUser("Alice"),
            bob: _createUser("Bob"),
            trader: _createUser("Trader")
        });

        vm.deal(users.owner, 100 ether);
        vm.startPrank(users.owner);

        dictator = new Dictatorship(users.owner);

        skip(1 hours);
    }

    function _createUser(string memory _name) internal virtual returns (address payable) {
        address payable _user = payable(makeAddr(_name));
        vm.deal(_user, 10 ether);
        return _user;
    }

    /// @notice Deal USDC to user using storage manipulation
    function _dealUSDC(address _user, uint _amount) internal {
        deal(address(usdc), _user, _amount);
    }

    /// @notice Deal WETH to user using storage manipulation
    function _dealWNT(address _user, uint _amount) internal {
        deal(address(wnt), _user, _amount);
    }

    /// @notice Get current block timestamp
    function _timestamp() internal view returns (uint) {
        return block.timestamp;
    }
}
