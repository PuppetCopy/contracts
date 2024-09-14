// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Router} from "src/shared/Router.sol";
import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
import {Precision, ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mintable} from "src/utils/interfaces/IERC20Mintable.sol";

import {console, stdError} from "forge-std/src/Test.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

contract ContributeLogicTest is BasicSetup {
    ContributeStore contributeStore;
    ContributeLogic contributeLogic;
    ContributeRouter contributeRouter;
    IERC20Mintable mockRevenueToken;

    IERC20[] claimableTokenList = new IERC20[](2);

    function setUp() public override {
        BasicSetup.setUp();

        claimableTokenList[0] = wnt;
        claimableTokenList[1] = usdc;

        contributeStore = new ContributeStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(contributeStore));

        allowNextLoggerAccess();
        contributeLogic = new ContributeLogic(
            dictator,
            eventEmitter,
            puppetToken,
            contributeStore,
            ContributeLogic.Config({baselineEmissionRate: 0.1e30})
        );

        dictator.setAccess(eventEmitter, address(contributeLogic));
        dictator.setAccess(contributeStore, address(contributeLogic));

        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(contributeLogic));

        contributeRouter = new ContributeRouter(contributeLogic);
        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(contributeRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(contributeRouter));

        dictator.setPermission(contributeLogic, contributeLogic.setBuybackQuote.selector, users.owner);

        dictator.setPermission(puppetToken, puppetToken.mint.selector, users.owner);

        puppetToken.mint(users.alice, 100 * 1e18);
        puppetToken.mint(users.bob, 100 * 1e18);
        puppetToken.mint(users.yossi, 100 * 1e18);

        dictator.setAccess(contributeStore, users.owner);

        wnt.approve(address(router), type(uint).max - 1);
        usdc.approve(address(router), type(uint).max - 1);
        puppetToken.approve(address(router), type(uint).max - 1);

        vm.stopPrank();
    }

    function testContribute() public {
        uint256 amount = 100e18;
        address user = users.bob;

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, amount);
        contributeStore.contribute(usdc, users.owner, user, amount);
        vm.stopPrank();

        assertEq(contributeStore.getUserContributionBalanceMap(usdc, users.bob), amount);
        assertEq(contributeStore.getUserAccruedReward(users.bob), 0);
        assertEq(contributeStore.getUserCursor(usdc, users.bob), 0);
        assertEq(usdc.balanceOf(address(contributeStore)), amount);
    }

    function testSetBuybackQuote() public {
        uint256 quoteAmount = 100 * 1e18;
        
        vm.prank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);

        assertEq(contributeStore.getBuybackQuote(usdc), quoteAmount, "Buyback quote should be set correctly");
    }

    function testBuybackContribute() public {
        uint256 amount = 100e18;
        address user = users.alice;

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, amount);
        contributeStore.contribute(usdc, users.owner, user, amount/2);
        contributeStore.contribute(usdc, users.owner, users.bob, amount/2);
        vm.stopPrank();

        uint256 quoteAmount = 100 * 1e18;
        uint256 revenueAmount = 100 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        assertEq(usdc.balanceOf(users.alice), revenueAmount, "Alice should receive the revenue tokens");
        assertEq(puppetToken.balanceOf(address(contributeStore)), quoteAmount, "ContributeStore should receive the quote amount");
        assertEq(contributeStore.getCursor(usdc), 1);
        assertEq(contributeStore.getCursorRate(usdc, 0), quoteAmount * Precision.FLOAT_PRECISION / amount);
        assertEq(contributeStore.getCursorBalance(usdc), 0);
        assertEq(contributeStore.getUserCursor(usdc, users.alice), 0);
    }

    function testCannotBuybackTwice() public {
        uint256 amount = 100e18;
        address user = users.alice;

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, amount);
        contributeStore.contribute(usdc, users.owner, user, amount);
        vm.stopPrank();

        uint256 quoteAmount = 50 * 1e18;
        uint256 revenueAmount = 50 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        assertEq(contributeStore.getCursorBalance(usdc), 0);
        vm.prank(users.alice);
        vm.expectRevert(stdError.divisionError);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);
    }

    function testClaimContribute() public {
        uint256 quoteAmount = 100 * 1e18;
        uint256 revenueAmount = 50 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        puppetToken.approve(address(router), quoteAmount);

        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        // @audit Can only claim after someone boughtBack the tokens
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        uint256 claimableAmount = contributeLogic.getClaimable(tokenList, users.alice);
        
        vm.prank(users.alice);
        uint256 claimedAmount = contributeRouter.claim(tokenList, claimableAmount);

        assertEq(puppetToken.balanceOf(users.alice), claimedAmount);
        assertEq(contributeStore.getUserAccruedReward(users.alice), 0);
    }

    function testStuckFundsAfterBuyBack() public {
        uint256 quoteAmount = 20 * 1e18;
        uint256 revenueAmount = 100 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        puppetToken.approve(address(router), quoteAmount);

        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        // Imagine a scenario where a contribution happens just before the users buysBack 
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        uint256 claimableAmount = contributeLogic.getClaimable(tokenList, users.alice);

        console.log(claimableAmount);

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        uint256 claimableAmount1 = contributeLogic.getClaimable(tokenList, users.alice);

        console.log(claimableAmount1);
        
        // vm.prank(users.alice);
        // uint256 claimedAmount = contributeRouter.claim(tokenList, claimableAmount);

        // assertEq(puppetToken.balanceOf(users.alice), claimedAmount);
        // assertEq(contributeStore.getUserAccruedReward(users.alice), 0);
    }

    function testCannnotClaimIfNotReceiverOfContribution() public {
        uint256 quoteAmount = 100 * 1e18;
        uint256 revenueAmount = 50 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        puppetToken.approve(address(router), quoteAmount);

        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        // @audit Can only claim after someone boughtBack the tokens
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        uint256 claimableAmount = contributeLogic.getClaimable(tokenList, users.alice);
        
        vm.prank(users.bob);
        vm.expectRevert(abi.encodeWithSelector(ContributeLogic.ContributeLogic__InsufficientClaimableReward.selector, 0));
        uint256 claimedAmount = contributeRouter.claim(tokenList, claimableAmount);

        assertEq(puppetToken.balanceOf(users.alice), claimedAmount, "Alice should receive the claimed amount");
    }
    function testContributeAfterBuyBackDoesNotReduceClaimAmount() public {
        uint256 amountUsdc = 100e6;
        // uint256 amountWnt = 100e18;
        address user = users.alice;

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, amountUsdc);
        contributeStore.contribute(usdc, users.owner, user, amountUsdc/2);
        vm.stopPrank();

        uint256 quoteAmount = 50 * 1e18;
        uint256 revenueAmount = 50 * 1e6;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        vm.stopPrank();

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);

        // @note Someone could technically front-run the second contribute and buyBack to reduce the claim amount for users
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        vm.startPrank(users.owner);
        contributeStore.contribute(usdc, users.owner, user, amountUsdc/2);
        vm.stopPrank();

        assertEq(contributeStore.getUserContributionBalanceMap(usdc, user), amountUsdc/2);

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        assertEq(contributeLogic.getClaimable(tokenList, users.alice), 50e18);

        vm.prank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        vm.prank(users.alice);
        contributeRouter.buyback(usdc,  users.alice, revenueAmount);

        assertEq(contributeLogic.getClaimable(tokenList, users.alice), 100e18);
        assertEq(contributeStore.getUserContributionBalanceMap(usdc, user), amountUsdc/2);

        vm.prank(users.alice);
        contributeRouter.claim(tokenList, 100e18);
    }


    function testFeeOnTransferTokensShouldReduceClaimAmounts() public {

        uint256 quoteAmount = 40 * 1e18;
        uint256 revenueAmount = 100 * 1e18;

        // Assume the token used for contribution is a fee-on-transfer token
        TransferFeeToken feeToken = new TransferFeeToken( 5e18);
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(IERC20(address(feeToken)), quoteAmount);
        IERC20(address(feeToken)).approve(address(router), type(uint256).max);

        _dealERC20(address(feeToken), users.owner, revenueAmount + 20e18);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.alice, revenueAmount*25/100);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.alice, revenueAmount*15/100);
        contributeStore.contribute(IERC20(address(feeToken)), users.owner, users.bob, revenueAmount*40/100);
        vm.stopPrank();


        assertEq(feeToken.balanceOf(address(contributeStore)), 65e18);
        assertEq(contributeStore.getCursorBalance(IERC20(address(feeToken))), 80e18);

        // Alice buys back
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        contributeRouter.buyback(IERC20(address(feeToken)),  users.alice, feeToken.balanceOf(address(contributeStore)));
        vm.stopPrank();

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = IERC20(address(feeToken));

        uint256 claimableAmountAlice = contributeLogic.getClaimable(tokenList, users.alice);
        uint256 claimableAmountBob = contributeLogic.getClaimable(tokenList, users.bob);

        assertEq(claimableAmountAlice, 20e18);
        assertEq(claimableAmountBob, 20e18);

        // However the real amount should be :
        // 30e18 * 40e18 *e30 / (65e18*e30) which after rounding down gives 18e18. This is the amount that should be claimable by Alice

        uint256 realAmountToClaimAlice = uint256((30e18 * 40e18 * 1e30)) /uint256((65e18 * 1e30));
        uint256 realAmountToClaimBob = uint256((35e18 * 40e18 * 1e30)) /uint256((65e18 * 1e30));

        assertApproxEqAbs(realAmountToClaimAlice , 18.4e18, 1e17);
        assertApproxEqAbs(realAmountToClaimBob , 21.5e18, 1e17);

    }

    function testCannotClaimMoreWithoutBuyBack() public {

        uint256 quoteAmount = 40 * 1e18;
        uint256 revenueAmount = 100 * 1e18;
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);

        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount*25/100);
        // contributeStore.contribute(usdc, users.bob, users.alice, revenueAmount*40/100);
        vm.stopPrank();


        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        uint256 claimableAmountAliceBefore = contributeLogic.getClaimable(tokenList, users.alice);

        assertEq(claimableAmountAliceBefore, 0);

        // Alice buys back
        vm.startPrank(users.bob);
        puppetToken.approve(address(router), quoteAmount);
        contributeRouter.buyback(usdc,  users.bob, usdc.balanceOf(address(contributeStore)));
        vm.stopPrank();

        uint256 claimableAmountAliceAfter = contributeLogic.getClaimable(tokenList, users.alice);

        assertEq(claimableAmountAliceAfter, 40e18);

        vm.prank(users.owner);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount*15/100);

        uint256 claimableAmountAliceAfterContribute = contributeLogic.getClaimable(tokenList, users.alice);

        // Claim amount does not change since no buyBack happened
        assertEq(claimableAmountAliceAfterContribute, 40e18);
    }
    /////////////////////////////////////  FUZZ Tests ////////////////////////////////////////////

    function testFuzz_Contribute(uint256 amount) public {

        amount = bound(amount, 0, usdc.balanceOf(users.owner));
        
        address user = users.bob;

        vm.startPrank(users.owner);
        _dealERC20(address(usdc), users.owner, amount);
        contributeStore.contribute(usdc, users.owner, user, amount);
        vm.stopPrank();

        assertEq(contributeStore.getUserContributionBalanceMap(usdc, user), amount);
        assertEq(contributeStore.getUserAccruedReward(user), 0);
        assertEq(contributeStore.getUserCursor(usdc, user), 0);
        assertEq(usdc.balanceOf(address(contributeStore)), amount);
    }

    function testFuzz_BuybackContribute(uint256 amount, uint256 quoteAmount, uint256 revenueAmount) public {
        _dealERC20(address(usdc), users.owner, amount);
        amount = bound(amount, 1, usdc.balanceOf(users.owner));
        quoteAmount = bound(quoteAmount, 1, puppetToken.balanceOf(users.alice));
        revenueAmount = bound(revenueAmount, 1, amount);

        address user = users.alice;

        vm.startPrank(users.owner);
        // _dealERC20(address(usdc), users.owner, amount);
        contributeStore.contribute(usdc, users.owner, user, amount);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        vm.stopPrank();

        console.log("amount", amount);
        console.log("revenueAmount", revenueAmount);
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        contributeRouter.buyback(usdc, users.alice, revenueAmount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(users.alice), revenueAmount, "Alice should receive the revenue tokens");
        assertEq(puppetToken.balanceOf(address(contributeStore)), quoteAmount, "ContributeStore should receive the quote amount");
        assertEq(contributeStore.getCursor(usdc), 1);
        assertEq(contributeStore.getCursorRate(usdc, 0), quoteAmount * Precision.FLOAT_PRECISION / amount);
        assertEq(contributeStore.getCursorBalance(usdc), 0);
        assertEq(contributeStore.getUserCursor(usdc, users.alice), 0);
    }

    function testFuzz_ClaimContribute(uint256 quoteAmount, uint256 revenueAmount) public {

        revenueAmount = bound(revenueAmount, 1, 1_000_000e6);
        _dealERC20(address(usdc), users.owner, revenueAmount);
        quoteAmount = bound(quoteAmount, 1, puppetToken.balanceOf(users.alice));
        
        vm.startPrank(users.owner);
        contributeLogic.setBuybackQuote(usdc, quoteAmount);
        puppetToken.approve(address(router), quoteAmount);

        _dealERC20(address(usdc), users.owner, revenueAmount);
        contributeStore.contribute(usdc, users.owner, users.alice, revenueAmount);
        vm.stopPrank();

        uint256 balanceBefore = puppetToken.balanceOf(users.alice);
        vm.startPrank(users.alice);
        puppetToken.approve(address(router), quoteAmount);
        contributeRouter.buyback(usdc, users.alice, revenueAmount);

        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        uint256 claimableAmount = contributeLogic.getClaimable(tokenList, users.alice);
        uint256 claimedAmount = contributeRouter.claim(tokenList, claimableAmount);
        vm.stopPrank();

        assertEq(puppetToken.balanceOf(users.alice), balanceBefore - quoteAmount + claimedAmount);
        assertEq(contributeStore.getUserAccruedReward(users.alice), 0);
    }

    function testFuzz_MultipleBuybacksAndClaims(
        uint256[5] memory contributionAmounts,
        uint256[5] memory quoteAmounts,
        uint256[5] memory revenueAmounts
    ) public {
        IERC20[] memory tokenList = new IERC20[](1);
        tokenList[0] = usdc;

        for (uint i = 0; i < 5; i++) {
            uint256 contributionAmount = bound(contributionAmounts[i], 1, 1_000_000e6);
            _dealERC20(address(usdc), users.owner, contributionAmount);
            uint256 quoteAmount = bound(quoteAmounts[i], 1, puppetToken.balanceOf(users.alice));
            uint256 revenueAmount = bound(revenueAmounts[i], 1, contributionAmount);

            vm.startPrank(users.owner);
            contributeStore.contribute(usdc, users.owner, users.alice, contributionAmount);
            contributeLogic.setBuybackQuote(usdc, quoteAmount);
            vm.stopPrank();

            vm.startPrank(users.alice);
            puppetToken.approve(address(router), quoteAmount);
            contributeRouter.buyback(usdc, users.alice, revenueAmount);

            uint256 claimableAmount = contributeLogic.getClaimable(tokenList, users.alice);
            if (claimableAmount > 0) {
                contributeRouter.claim(tokenList, claimableAmount);
            }
            vm.stopPrank();
        }

        uint256 finalClaimableAmount = contributeLogic.getClaimable(tokenList, users.alice);
        assertEq(contributeStore.getUserAccruedReward(users.alice), finalClaimableAmount);
    }
}

contract ContributeRouter {
    ContributeLogic contributeLogic;

    constructor(ContributeLogic _contributeLogic) {
        contributeLogic = _contributeLogic;
    }

    function buyback(IERC20 token, address receiver, uint revenueAmount) public {
        contributeLogic.buyback(token, msg.sender, receiver, revenueAmount);
    }

    function claim(IERC20[] calldata tokenList, uint amount) public returns (uint) {
        return contributeLogic.claim(tokenList, msg.sender, msg.sender, amount);
    }
}


import {MockERC20} from "node_modules/forge-std/src/mocks/MockERC20.sol";

contract TransferFeeToken is MockERC20 {

    uint immutable fee;

    // --- Init ---
    constructor( uint _fee) {
        fee = _fee;
    }

    // --- Token ---
    function transferFrom(address src, address dst, uint wad) override public returns (bool) {
        require(_balanceOf[src] >= wad, "insufficient-balance");
        if (src != msg.sender && _allowance[src][msg.sender] != type(uint).max) {
            require(_allowance[src][msg.sender] >= wad, "insufficient-allowance");
            _allowance[src][msg.sender] = _allowance[src][msg.sender] - wad;
        }

        _balanceOf[src] = _balanceOf[src] - wad;
        _balanceOf[dst] = _balanceOf[dst] +  (wad - fee);
        _balanceOf[address(0)] = _balanceOf[address(0)] + fee;

        return true;
    }
}