// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {MatchmakerRouter} from "src/MatchmakerRouter.sol";
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
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Const} from "script/Const.sol";

/// @notice Fork test that hits the real GMX V2 exchange router on Arbitrum to ensure open requests work end-to-end.
/// @dev Skips automatically if no RPC URL is provided in the environment.
contract TradingForkTest is Test {
    // GMX V2 (Arbitrum) addresses from script/generated/gmx/gmxContracts.ts
    address private constant GMX_EXCHANGE_ROUTER = Const.gmxExchangeRouter;
    address private constant GMX_DATASTORE = Const.gmxDataStore;
    address private constant GMX_ORDER_VAULT = Const.gmxOrderVault;
    address private constant GMX_ETH_USD_MARKET = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    // Collateral: native USDC on Arbitrum
    IERC20 private constant USDC = IERC20(Const.usdc);

    string private constant ARB_RPC_ENV = "RPC_42161_1";

    // Test actors
    address private admin = address(0xA11CE);
    address private matchmaker = address(0xBEE);
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
    MatchmakerRouter private matchmakerRouter;
    PuppetToken private puppetToken;
    FeeMarketplaceStore private feeMarketplaceStore;
    FeeMarketplace private feeMarketplace;

    function setUp() public {
        string memory rpc = vm.envOr("RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr(ARB_RPC_ENV, string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("ARBITRUM_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(rpc);
        vm.deal(admin, 100 ether);
        vm.deal(matchmaker, 10 ether);

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
                maxMatchmakerFeeToAllocationRatio: 0.1e30,
                maxMatchmakerFeeToAdjustmentRatio: 0.1e30,
                maxMatchmakerFeeToCloseRatio: 0.1e30,
                maxMatchOpenDuration: 30 seconds,
                maxMatchAdjustDuration: 60 seconds,
                collateralReserveBps: 500
            })
        );

        settle = new Settle(
            authority,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.05e30, // 5%
                maxMatchmakerFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );

        puppetToken = new PuppetToken(admin);
        feeMarketplaceStore = new FeeMarketplaceStore(authority, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(
            authority,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000,
                unlockTimeframe: 1 days,
                askDecayTimeframe: 1 days,
                askStart: 100e18
            })
        );

        matchmakerRouter = new MatchmakerRouter(
            authority,
            account,
            subscribe,
            mirror,
            settle,
            feeMarketplace,
            MatchmakerRouter.Config({
                feeReceiver: matchmaker,
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
        _mockTraderPosition(trader, GMX_ETH_USD_MARKET, USDC, true, 10_000e30, 2_000e6, 5);

        uint executionFee = 0.02 ether;
        uint fee = 1e6; // 1 USDC

        Mirror.CallPosition memory params = Mirror.CallPosition({
            collateralToken: USDC,
            trader: trader,
            market: GMX_ETH_USD_MARKET,
            isLong: true,
            executionFee: executionFee,
            allocationId: 1,
            matchmakerFee: fee
        });

        vm.startPrank(matchmaker);
        vm.deal(matchmaker, executionFee + 1 ether); // ensure ETH for execution fee
        (address allocationAddr, bytes32 orderKey) = matchmakerRouter.matchmake{value: executionFee}(params, puppetList);
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
        authority.registerContract(matchmakerRouter);

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
        authority.setPermission(mirror, mirror.matchmake.selector, address(matchmakerRouter));
        authority.setPermission(mirror, mirror.adjust.selector, address(matchmakerRouter));
        authority.setPermission(mirror, mirror.close.selector, address(matchmakerRouter));

        // Settle permissions
        authority.setPermission(settle, settle.settle.selector, address(matchmakerRouter));
        authority.setPermission(settle, settle.collectAllocationAccountDust.selector, address(matchmakerRouter));

        //  entrypoints (use matchmaker as the caller for this test)
        authority.setPermission(matchmakerRouter, matchmakerRouter.matchmake.selector, matchmaker);
        authority.setPermission(matchmakerRouter, matchmakerRouter.adjust.selector, matchmaker);
        authority.setPermission(matchmakerRouter, matchmakerRouter.close.selector, matchmaker);

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
        uint _collateralAmount,
        uint _sizeInTokens
    ) internal {
        bytes32 positionKey = Position.getPositionKey(_trader, _market, address(_collateralToken), _isLong);
        bytes32 sizeKey = keccak256(abi.encode(positionKey, PositionStoreUtils.SIZE_IN_USD));
        bytes32 sizeTokensKey = keccak256(abi.encode(positionKey, PositionStoreUtils.SIZE_IN_TOKENS));
        bytes32 collateralKey = keccak256(abi.encode(positionKey, PositionStoreUtils.COLLATERAL_AMOUNT));
        bytes32 increasedAtKey = keccak256(abi.encode(positionKey, PositionStoreUtils.INCREASED_AT_TIME));

        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, sizeKey), abi.encode(_sizeUsd));
        vm.mockCall(
            GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, sizeTokensKey), abi.encode(_sizeInTokens)
        );
        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, collateralKey), abi.encode(_collateralAmount));
        vm.mockCall(GMX_DATASTORE, abi.encodeWithSelector(IGmxReadDataStore.getUint.selector, increasedAtKey), abi.encode(block.timestamp));
    }

    // -------------------------------------------------------------------------
    // Gas Benchmarking (run with -vvv to see output)
    // -------------------------------------------------------------------------

    /**
     * @notice Read GMX's gas limit configuration from DataStore
     * @dev Run: forge test --match-test testFork_ReadGmxGasLimits -vvv
     */
    function testFork_ReadGmxGasLimits() public view {
        console.log("\n=== GMX DATASTORE GAS LIMITS ===\n");

        // Keys from GMX's Keys.sol
        bytes32 INCREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("INCREASE_ORDER_GAS_LIMIT"));
        bytes32 DECREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("DECREASE_ORDER_GAS_LIMIT"));
        bytes32 SINGLE_SWAP_GAS_LIMIT = keccak256(abi.encode("SINGLE_SWAP_GAS_LIMIT"));

        uint256 increaseGas = IGmxReadDataStore(GMX_DATASTORE).getUint(INCREASE_ORDER_GAS_LIMIT);
        uint256 decreaseGas = IGmxReadDataStore(GMX_DATASTORE).getUint(DECREASE_ORDER_GAS_LIMIT);
        uint256 swapGas = IGmxReadDataStore(GMX_DATASTORE).getUint(SINGLE_SWAP_GAS_LIMIT);

        console.log("INCREASE_ORDER_GAS_LIMIT:", increaseGas);
        console.log("DECREASE_ORDER_GAS_LIMIT:", decreaseGas);
        console.log("SINGLE_SWAP_GAS_LIMIT:   ", swapGas);

        console.log("\n=== ESTIMATED ADJUST LIMITS ===");
        console.log("(adjust uses same GMX calls as matchmake)");
        console.log("(delta is our contract logic: no allocation creation, has throttle checks)");
    }

    /**
     * @notice Gas benchmark for matchmake with varying puppet counts
     * @dev Run: forge test --match-test testFork_GasBenchmark_Matchmake -vvv
     */
    function testFork_GasBenchmark_Matchmake() public {
        console.log("\n=== MATCHMAKE GAS BENCHMARK ===\n");

        uint[] memory puppetCounts = new uint[](5);
        puppetCounts[0] = 1;
        puppetCounts[1] = 5;
        puppetCounts[2] = 10;
        puppetCounts[3] = 25;
        puppetCounts[4] = 50;

        uint[] memory gasResults = new uint[](5);

        for (uint i = 0; i < puppetCounts.length; i++) {
            uint count = puppetCounts[i];
            address[] memory puppets = _setupPuppets(count, i * 100);

            _mockTraderPosition(trader, GMX_ETH_USD_MARKET, USDC, true, 10_000e30, 2_000e6, 5);

            Mirror.CallPosition memory params = Mirror.CallPosition({
                collateralToken: USDC,
                trader: trader,
                market: GMX_ETH_USD_MARKET,
                isLong: true,
                executionFee: 0.02 ether,
                allocationId: i + 100,
                matchmakerFee: 0.01e6 // Small fee to avoid hitting ratio limits
            });

            vm.startPrank(matchmaker);
            vm.deal(matchmaker, 1 ether);

            uint gasBefore = gasleft();
            matchmakerRouter.matchmake{value: 0.02 ether}(params, puppets);
            gasResults[i] = gasBefore - gasleft();

            vm.stopPrank();

            console.log("Puppets:", count, "| Gas:", gasResults[i]);
        }

        // Calculate per-puppet gas
        if (gasResults[4] > gasResults[0]) {
            uint perPuppetGas = (gasResults[4] - gasResults[0]) / 49;
            uint baseGas = gasResults[0] - perPuppetGas;
            console.log("\n--- RECOMMENDED matchmake CONFIG ---");
            console.log("matchBaseGasLimit:     ", baseGas);
            console.log("matchPerPuppetGasLimit:", perPuppetGas);
        }
    }

    /**
     * @notice Gas benchmark for settle with varying puppet counts
     * @dev Run: forge test --match-test testFork_GasBenchmark_Settle -vvv
     */
    function testFork_GasBenchmark_Settle() public {
        console.log("\n=== SETTLE GAS BENCHMARK ===\n");

        uint[] memory puppetCounts = new uint[](5);
        puppetCounts[0] = 1;
        puppetCounts[1] = 5;
        puppetCounts[2] = 10;
        puppetCounts[3] = 25;
        puppetCounts[4] = 50;

        uint[] memory gasResults = new uint[](5);

        // Grant settle permission to matchmaker
        vm.prank(admin);
        authority.setPermission(matchmakerRouter, matchmakerRouter.settleAllocation.selector, matchmaker);

        for (uint i = 0; i < puppetCounts.length; i++) {
            uint count = puppetCounts[i];
            uint allocationId = i + 200;

            // Setup puppets and create allocation via matchmake first
            address[] memory puppets = _setupPuppets(count, 1000 + i * 100);

            _mockTraderPosition(trader, GMX_ETH_USD_MARKET, USDC, true, 10_000e30, 2_000e6, 5);

            Mirror.CallPosition memory matchParams = Mirror.CallPosition({
                collateralToken: USDC,
                trader: trader,
                market: GMX_ETH_USD_MARKET,
                isLong: true,
                executionFee: 0.02 ether,
                allocationId: allocationId,
                matchmakerFee: 0.01e6 // Small fee to avoid hitting ratio limits
            });

            vm.startPrank(matchmaker);
            vm.deal(matchmaker, 1 ether);
            (address allocationAddr,) = matchmakerRouter.matchmake{value: 0.02 ether}(matchParams, puppets);
            vm.stopPrank();

            // Fund allocation with profit
            deal(address(USDC), allocationAddr, 100e6, true);

            // Benchmark settle
            Settle.CallSettle memory settleParams = Settle.CallSettle({
                collateralToken: USDC,
                distributionToken: USDC,
                matchmakerFeeReceiver: matchmaker,
                trader: trader,
                allocationId: allocationId,
                matchmakerExecutionFee: 0.01e6,
                amount: 100e6
            });

            vm.startPrank(matchmaker);

            uint gasBefore = gasleft();
            matchmakerRouter.settleAllocation(settleParams, puppets);
            gasResults[i] = gasBefore - gasleft();

            vm.stopPrank();

            console.log("Puppets:", count, "| Gas:", gasResults[i]);
        }

        // Calculate per-puppet gas
        if (gasResults[4] > gasResults[0]) {
            uint perPuppetGas = (gasResults[4] - gasResults[0]) / 49;
            uint baseGas = gasResults[0] - perPuppetGas;
            console.log("\n--- RECOMMENDED settle CONFIG ---");
            console.log("settleBaseGasLimit:     ", baseGas);
            console.log("settlePerPuppetGasLimit:", perPuppetGas);
        }
    }

    function _setupPuppets(uint count, uint offset) internal returns (address[] memory) {
        address[] memory puppets = new address[](count);

        vm.startPrank(admin);
        for (uint i = 0; i < count; i++) {
            address puppet = address(uint160(0x2000 + offset + i));
            puppets[i] = puppet;

            account.deposit(USDC, admin, puppet, 100e6);

            subscribe.rule(
                mirror,
                USDC,
                puppet,
                trader,
                Subscribe.RuleParams({
                    allowanceRate: 1000,
                    throttleActivity: 1,
                    expiry: block.timestamp + 30 days
                })
            );
        }
        vm.stopPrank();

        return puppets;
    }
}
