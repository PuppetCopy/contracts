// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;
import {CommonHelper} from "src/integrations/libraries/CommonHelper.sol";
import {BaseGMXV2} from "../../BaseGMXV2.t.sol";

contract GMXV2PuppetWithdrawFuzz is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();

        uint256 _amount = 1 ether;
        address _user = context.users.alice;

        _dealERC20(context.usdc, _user, _amount);

        vm.startPrank(_user);

        context.orchestrator.deposit{ value: _amount }(_amount, _weth, _user);
        require(CommonHelper.puppetAccountBalance(context.dataStore, _user, _weth) == _amount, "GMXV2PuppetWithdrawFuzz: SETUP FAILED - WETH");

        _approveERC20(address(context.orchestrator), context.usdc, _amount);
        context.orchestrator.deposit(_amount, context.usdc, _user);
        require(CommonHelper.puppetAccountBalance(context.dataStore, _user, context.usdc) == _amount, "GMXV2PuppetWithdrawFuzz: SETUP FAILED - USDC");

        vm.stopPrank();
    }

    function testFuzz_Withdraw_Amount(uint256 _amount) external {
        _fuzz_PuppetWithdraw.withdraw_fuzzAmount(context, _amount);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_Withdraw_Token(address _token) external {
        _fuzz_PuppetWithdraw.withdraw_fuzzToken(context, _token);
    }

    function testFuzz_Withdraw_Receiver(address _receiver) external {
        _fuzz_PuppetWithdraw.withdraw_fuzzReceiver(context, _receiver);
    }
}