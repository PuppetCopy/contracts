// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/src/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";

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
    IERC20 constant usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 constant wnt = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    // GMX V2 addresses (Arbitrum)
    address constant gmxExchangeRouter = 0x1C3fa76e6E1088bCE750f23a5BFcffa1efEF6A41;
    address constant gmxRouter = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address constant gmxDataStore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant gmxOrderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant gmxReferralStorage = 0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d;
    address constant gmxEthUsdcMarket = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;

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
