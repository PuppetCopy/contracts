// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";

import {SequencerRouter} from "src/SequencerRouter.sol";
import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {Position} from "@gmx/contracts/position/Position.sol";
import {PositionStoreUtils} from "@gmx/contracts/position/PositionStoreUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {Const} from "script/Const.sol";

/// @notice Fork test that hits the real GMX V2 exchange router on Arbitrum to ensure open requests work end-to-end.
/// @dev Skips automatically if no RPC URL is provided in the environment.
contract TradingForkTest is Test {
    // GMX V2 (Arbitrum) addresses from script/generated/gmx/gmxContracts.ts
    address private constant GMX_EXCHANGE_ROUTER = Const.gmxExchangeRouter;
    address private constant GMX_DATASTORE = Const.gmxDataStore;
    address private constant GMX_ORDER_VAULT = Const.gmxOrderVault;
    address private constant GMX_ETH_USD_MARKET = Const.gmxEthUsdcMarket;

    // Collateral: native USDC on Arbitrum
    IERC20 private constant USDC = IERC20(Const.usdc);

    string private constant ARB_RPC_ENV = "RPC_42161_1";

    // Test actors
    address private admin = address(0xA11CE);
    address private sequencer = address(0xBEE);
    address private trader = address(0xCAFE);
    address private puppet1 = address(0x1);
    address private puppet2 = address(0x2);

    // Core contracts
    Dictatorship private authority;
    TokenRouter private tokenRouter;
    AccountStore private accountStore;
    AccountContract private account;
    Subscribe private subscribe;
    Mirror private mirror;
    Settle private settle;
    SequencerRouter private sequencerRouter;

    function setUp() public {
        // Prefer RPC_42161_1 (in .env); fall back to ARBITRUM_RPC_URL for compatibility
        string memory rpc = vm.envOr(ARB_RPC_ENV, string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("ARBITRUM_RPC_URL", string(""));
        }
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(rpc);
        vm.deal(admin, 100 ether);
        vm.deal(sequencer, 10 ether);

        authority = new Dictatorship(admin);
        tokenRouter = new TokenRouter(authority, TokenRouter.Config({transferGasLimit: 200_000}));
        accountStore = new AccountStore(authority, tokenRouter);
        account = new AccountContract(authority, accountStore, AccountContract.Config({transferOutGasLimit: 200_000}));

        subscribe = new Subscribe(
            authority,
            Subscribe.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10_000, // 100%
                minActivityThrottle: 1,
                maxActivityThrottle: 30 days
            })
        );

        mirror = new Mirror(
            authority,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(GMX_EXCHANGE_ROUTER),
                gmxDataStore: IGmxReadDataStore(GMX_DATASTORE),
                gmxOrderVault: GMX_ORDER_VAULT,
                // casting to bytes32 is safe because "PUPPET" is 6 bytes and will be zero-padded
                // forge-lint: disable-next-line(unsafe-typecast)
                referralCode: bytes32("PUPPET"),
                maxPuppetList: 50,
                maxSequencerFeeToAllocationRatio: 0.1e30,
                maxSequencerFeeToAdjustmentRatio: 0.1e30,
                maxSequencerFeeToCloseRatio: 0.1e30,
                maxMatchOpenDuration: 30 seconds,
                maxMatchAdjustDuration: 60 seconds
            })
        );

        settle = new Settle(
            authority,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.05e30, // 5%
                maxSequencerFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );

        sequencerRouter = new SequencerRouter(
            authority,
            account,
            subscribe,
            mirror,
            settle,
            SequencerRouter.Config({
                feeReceiver: sequencer,
                matchBaseGasLimit: 1_300_853,
                matchPerPuppetGasLimit: 30_000,
                adjustBaseGasLimit: 910_663,
                adjustPerPuppetGasLimit: 3_412,
                settleBaseGasLimit: 1_300_853,
                settlePerPuppetGasLimit: 30_000,
                gasPriceBufferBasisPoints: 12000, // 120% (20% buffer)
                maxEthPriceAge: 300,
                maxIndexPriceAge: 3000,
                maxFiatPriceAge: 60_000,
                maxGasAge: 2000,
                stalledCheckInterval: 30_000,
                stalledPositionThreshold: 5 * 60 * 1000,
                minMatchTraderCollateral: 25e30,
                minAllocationUsd: 20e30,
                minAdjustUsd: 10e30
            })
        );

        _wirePermissions();
        _bootstrapBalancesAndRules();
    }

    function testFork_OpenCreatesOrderOnGmx() public {
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Mock trader state in DataStore so Mirror pre-checks pass
        _mockTraderPosition(trader, GMX_ETH_USD_MARKET, USDC, true, 10_000e30, 2_000e6);

        uint executionFee = 0.02 ether;
        uint sequencerFee = 1e6; // 1 USDC

        Mirror.CallPosition memory params = Mirror.CallPosition({
            collateralToken: USDC,
            trader: trader,
            market: GMX_ETH_USD_MARKET,
            isLong: true,
            executionFee: executionFee,
            allocationId: 1,
            sequencerFee: sequencerFee
        });

        vm.startPrank(sequencer);
        vm.deal(sequencer, executionFee + 1 ether); // ensure ETH for execution fee
        (address allocationAddr, bytes32 orderKey) = sequencerRouter.matchmake{value: executionFee}(params, puppetList);
        vm.stopPrank();

        assertTrue(orderKey != bytes32(0), "GMX order key should be non-zero");
        // Allocation should be funded and tracked after open
        assertGt(mirror.allocationMap(allocationAddr), 0, "allocation should record contributions");
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _wirePermissions() internal {
        vm.startPrank(admin);

        // Register contracts for logging
        authority.registerContract(tokenRouter);
        authority.registerContract(account);
        authority.registerContract(settle);
        authority.registerContract(subscribe);
        authority.registerContract(mirror);
        authority.registerContract(sequencerRouter);

        // TokenRouter permissions
        authority.setPermission(tokenRouter, tokenRouter.transfer.selector, address(accountStore));

        // AccountStore access
        authority.setAccess(accountStore, address(account));
        authority.setAccess(accountStore, address(settle));

        // Account permissions for Mirror/Settle
        authority.setPermission(account, account.setBalanceList.selector, address(mirror));
        authority.setPermission(account, account.createAllocationAccount.selector, address(mirror));
        authority.setPermission(account, account.transferOut.selector, address(mirror));
        authority.setPermission(account, account.execute.selector, address(mirror));
        authority.setPermission(account, account.execute.selector, address(settle));
        authority.setPermission(account, account.setBalanceList.selector, address(settle));
        authority.setPermission(account, account.transferInAllocation.selector, address(settle));
        authority.setPermission(account, account.transferOut.selector, address(settle));

        // Mirror permissions
        authority.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(subscribe));
        authority.setPermission(mirror, mirror.matchmake.selector, address(sequencerRouter));
        authority.setPermission(mirror, mirror.adjust.selector, address(sequencerRouter));
        authority.setPermission(mirror, mirror.close.selector, address(sequencerRouter));

        // Settle permissions
        authority.setPermission(settle, settle.settle.selector, address(sequencerRouter));
        authority.setPermission(settle, settle.collectAllocationAccountDust.selector, address(sequencerRouter));

        // Sequencer entrypoints (use sequencer as the caller for this test)
        authority.setPermission(sequencerRouter, sequencerRouter.matchmake.selector, sequencer);
        authority.setPermission(sequencerRouter, sequencerRouter.adjust.selector, sequencer);
        authority.setPermission(sequencerRouter, sequencerRouter.close.selector, sequencer);

        // Administrative helpers
        authority.setPermission(account, account.setDepositCapList.selector, admin);
        authority.setPermission(account, account.deposit.selector, admin);
        authority.setPermission(subscribe, subscribe.rule.selector, admin);

        vm.stopPrank();
    }

    function _bootstrapBalancesAndRules() internal {
        vm.startPrank(admin);

        // Allow deposits for USDC
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC;
        uint[] memory caps = new uint[](1);
        caps[0] = 10_000_000e6; // generous cap for testing
        account.setDepositCapList(tokens, caps);

        // Seed puppets with USDC and approve router
        deal(address(USDC), admin, 5_000_000e6, true);
        USDC.approve(address(tokenRouter), type(uint).max);
        account.deposit(USDC, admin, puppet1, 1_000e6);
        account.deposit(USDC, admin, puppet2, 800e6);

        // Set rules for puppets following trader
        subscribe.rule(
            mirror,
            USDC,
            puppet1,
            trader,
            Subscribe.RuleParams({allowanceRate: 5_000, throttleActivity: 1 hours, expiry: block.timestamp + 30 days})
        );
        subscribe.rule(
            mirror,
            USDC,
            puppet2,
            trader,
            Subscribe.RuleParams({allowanceRate: 5_000, throttleActivity: 1 hours, expiry: block.timestamp + 30 days})
        );

        vm.stopPrank();
    }

    function _mockTraderPosition(
        address _trader,
        address _market,
        IERC20 _collateralToken,
        bool _isLong,
        uint _sizeUsd,
        uint _collateralAmount
    ) internal {
        bytes32 positionKey = Position.getPositionKey(_trader, _market, address(_collateralToken), _isLong);
        bytes32 sizeKey = keccak256(abi.encode(positionKey, PositionStoreUtils.SIZE_IN_USD));
        bytes32 collateralKey = keccak256(abi.encode(positionKey, PositionStoreUtils.COLLATERAL_AMOUNT));
        bytes32 increasedAtKey = keccak256(abi.encode(positionKey, PositionStoreUtils.INCREASED_AT_TIME));

        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, sizeKey), abi.encode(_sizeUsd));
        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, collateralKey), abi.encode(_collateralAmount));
        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, increasedAtKey), abi.encode(block.timestamp));
    }
}
