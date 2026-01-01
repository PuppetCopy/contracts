// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test, console2} from "forge-std/src/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {GmxVenueValidator} from "../../src/position/validator/GmxVenueValidator.sol";
import {IVenueValidator} from "../../src/position/interface/IVenueValidator.sol";
import {Const} from "../../script/Const.sol";
import {Error} from "../../src/utils/Error.sol";

interface IDataStore {
    function getBytes32ValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (bytes32[] memory);
    function getBytes32Count(bytes32 setKey) external view returns (uint256);
}

/**
 * @title GmxVenueValidatorForkTest
 * @dev Run: forge test --match-contract GmxVenueValidatorForkTest --fork-url arbitrum -vvv
 */
contract GmxVenueValidatorForkTest is Test {
    address account;
    GmxVenueValidator validator;
    IDataStore dataStore;

    address constant ETH_USD_MARKET = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    function setUp() public {
        account = vm.envAddress("DEPLOYER_ADDRESS");
        validator = new GmxVenueValidator(Const.gmxDataStore, Const.gmxReader, Const.gmxReferralStorage, Const.gmxRouter);
        dataStore = IDataStore(Const.gmxDataStore);
    }

    // ============ Position Net Value (requires fork) ============

    function test_GetPositionNetValue() public view {
        bytes32 listKey = keccak256(abi.encode(keccak256(abi.encode("ACCOUNT_POSITION_LIST")), account));
        uint256 positionCount = dataStore.getBytes32Count(listKey);

        console2.log("Account:", account);
        console2.log("Position count:", positionCount);

        if (positionCount == 0) return;

        bytes32[] memory positionKeys = dataStore.getBytes32ValuesAt(listKey, 0, positionCount);
        for (uint256 i = 0; i < positionKeys.length; i++) {
            uint256 netValue = validator.getPositionNetValue(positionKeys[i]);
            console2.log("Position", i, "net value:", netValue);
        }
    }

    // ============ createOrder (requires fork for getPositionInfo) ============

    function test_ValidateCreateOrder() public view {
        // This is a multicall containing createOrder - validate via validatePreCallSingle
        bytes memory callData = hex"f59c48eb0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000005966208be4bb7f8cb56f91f36000000000000000000000000000000000000000000000000000000000000ad91be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaa8aba07435c0000000000000000000000000000000000000000000000000000533ea3d939800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000145e9ee481bb885a49e1ff4c1166222587d6191600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000000000000000000100000000000000000000000070d95587d40a2caf56bd97485ab3eec10bee6336000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Validate as single call to exchange router
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);

        // Verify position info extraction
        assertEq(
            validator.getPositionInfo(IERC7579Account(account), callData).positionKey,
            keccak256(abi.encode(account, ETH_USD_MARKET, Const.usdc, true))
        );
    }

    // ============ updateOrder / cancelOrder ============

    function test_ValidateUpdateOrder() public view {
        bytes memory callData = abi.encodeWithSignature(
            "updateOrder(bytes32,uint256,uint256,uint256,uint256,uint256,bool)",
            keccak256("order"), 1000e30, 3000e30, 2900e30, 0, 0, false
        );
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    function test_ValidateCancelOrder() public view {
        bytes memory callData = abi.encodeWithSignature("cancelOrder(bytes32)", keccak256("order"));
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    // ============ claimFundingFees ============

    function test_ValidateClaimFundingFees() public view {
        bytes memory callData = hex"c41b1ab3000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000145e9ee481bb885a49e1ff4c1166222587d6191600000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ccb4faa6f1f1b30911619f1184082ab4e25813c000000000000000000000000fec8f404fbca3b11afd3b3f0c57507c2a06de6360000000000000000000000000000000000000000000000000000000000000002000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831";
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    function test_ValidateClaimFundingFees_RevertsWithWrongReceiver() public {
        address[] memory markets = new address[](1);
        markets[0] = ETH_USD_MARKET;
        address[] memory tokens = new address[](1);
        tokens[0] = Const.usdc;

        bytes memory callData = abi.encodeWithSignature(
            "claimFundingFees(address[],address[],address)",
            markets, tokens, address(0xdead)
        );

        vm.expectRevert(Error.GmxVenueValidator__InvalidReceiver.selector);
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    // ============ claimCollateral ============

    function test_ValidateClaimCollateral() public view {
        address[] memory markets = new address[](1);
        markets[0] = ETH_USD_MARKET;
        address[] memory tokens = new address[](1);
        tokens[0] = Const.usdc;
        uint256[] memory timeKeys = new uint256[](1);
        timeKeys[0] = block.timestamp;

        bytes memory callData = abi.encodeWithSignature(
            "claimCollateral(address[],address[],uint256[],address)",
            markets, tokens, timeKeys, account
        );

        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    function test_ValidateClaimCollateral_RevertsWithWrongReceiver() public {
        address[] memory markets = new address[](1);
        markets[0] = ETH_USD_MARKET;
        address[] memory tokens = new address[](1);
        tokens[0] = Const.usdc;
        uint256[] memory timeKeys = new uint256[](1);
        timeKeys[0] = block.timestamp;

        bytes memory callData = abi.encodeWithSignature(
            "claimCollateral(address[],address[],uint256[],address)",
            markets, tokens, timeKeys, address(0xdead)
        );

        vm.expectRevert(Error.GmxVenueValidator__InvalidReceiver.selector);
        validator.validatePreCallSingle(account, Const.gmxExchangeRouter, 0, callData);
    }

    // ============ approve ============

    function test_ValidateApprove() public view {
        bytes memory callData = abi.encodeWithSignature("approve(address,uint256)", Const.gmxRouter, type(uint256).max);
        // approve is called on the token contract, not the exchange router
        validator.validatePreCallSingle(account, Const.usdc, 0, callData);
    }

    function test_ValidateApprove_RevertsWithWrongSpender() public {
        bytes memory callData = abi.encodeWithSignature("approve(address,uint256)", address(0xdead), type(uint256).max);

        vm.expectRevert(Error.GmxVenueValidator__InvalidReceiver.selector);
        validator.validatePreCallSingle(account, Const.usdc, 0, callData);
    }

    // ============ setTraderReferralCodeByUser ============

    function test_ValidateSetReferral() public view {
        bytes memory callData = abi.encodeWithSignature("setTraderReferralCodeByUser(bytes32)", Const.referralCode);
        validator.validatePreCallSingle(account, Const.gmxReferralStorage, 0, callData);
    }

    // ============ validatePreCallBatch ============

    function test_ValidatePreCallBatch() public view {
        // Create batch of executions
        Execution[] memory executions = new Execution[](2);

        // First execution: approve
        executions[0] = Execution({
            target: Const.usdc,
            value: 0,
            callData: abi.encodeWithSignature("approve(address,uint256)", Const.gmxRouter, type(uint256).max)
        });

        // Second execution: multicall with createOrder
        executions[1] = Execution({
            target: Const.gmxExchangeRouter,
            value: 0,
            callData: hex"f59c48eb0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000005966208be4bb7f8cb56f91f36000000000000000000000000000000000000000000000000000000000000ad91be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaa8aba07435c0000000000000000000000000000000000000000000000000000533ea3d939800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000145e9ee481bb885a49e1ff4c1166222587d6191600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000000000000000000100000000000000000000000070d95587d40a2caf56bd97485ab3eec10bee6336000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        });

        validator.validatePreCallBatch(account, executions);
    }
}
