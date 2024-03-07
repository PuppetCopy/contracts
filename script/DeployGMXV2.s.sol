// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IGMXMarket} from "src/integrations/GMXV2/interfaces/IGMXMarket.sol";
import {IGMXReader} from "src/integrations/GMXV2/interfaces/IGMXReader.sol";

import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";

import {DataStore} from "src/integrations/utilities/DataStore.sol";
import {DecreaseSizeResolver} from "src/integrations/utilities/DecreaseSizeResolver.sol";

import {Orchestrator} from "src/integrations/GMXV2/Orchestrator.sol";
import {RouteFactory} from "src/integrations/GMXV2/RouteFactory.sol";

import {Dictator} from "src/utilities/Dictator.sol";
import {DeployerUtilities} from "script/utilities/DeployerUtilities.sol";

// ---- Usage ----
// NOTICE: UPDATE PUPPET ADDRESSES IN DeployerUtilities.sol AFTER DEPLOYMENT
// forge script --libraries ...... script/DeployGMXV2.s.sol:DeployGMXV2 --verify --legacy --rpc-url $RPC_URL --broadcast
// --constructor-args "000000000000000000000000a12a6281c1773f267c274c3be1b71db2bace06cb0000000000000000000000002a6c106ae13b558bb9e2ec64bd2f1f7beff3a5e000000000000000000000000075236b405f460245999f70bc06978ab2b4116920

contract DeployGMXV2 is DeployerUtilities {

    address private _dataStore;
    address private _orchestrator;
    address private _routeFactory;
    address private _decreaseSizeResolver;
    address private _scoreGaugeV1;

    bytes private _ethLongMarketData;
    bytes private _ethShortMarketData;

    Dictator private _dictator;

    function run() public {
        vm.startBroadcast(_deployerPrivateKey);

        _deployContracts();

        _setAdditionalData();

        _setDictatorRoles();

        _initializeDataStore();

        _initializeOrchestrator();

        _initializeResolver();

        _printAddresses();

        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        _dataStore = address(new DataStore(_deployer));

        _orchestrator = address(new Orchestrator(_dictator, DataStore(_dataStore)));
        _routeFactory = address(new RouteFactory());
        _decreaseSizeResolver = payable(address(new DecreaseSizeResolver(_dictator, _gelatoAutomationArbi, address(_dataStore))));
        _scoreGaugeV1 = address(0);
    }

    function _setAdditionalData() internal {
        bytes32 _marketType = bytes32(0x4bd5869a01440a9ac6d7bf7aa7004f402b52b845f20e2cec925101e13d84d075); // (https://arbiscan.io/tx/0x80ef8c8a10babfaad5c9b2c97d0f4b0f30f61ba6ceb201ea23f5c5737e46bc36)
        address _shortToken = _usdcOld;
        address _longToken = _weth;
        address _indexToken = _weth;

        address _ethLongMarketToken;
        address _ethShortMarketToken;
        {
            bytes32 _salt = keccak256(abi.encode("GMX_MARKET", _indexToken, _longToken, _shortToken, _marketType));
            IGMXMarket.Props memory _marketData = IGMXReader(_gmxV2Reader).getMarketBySalt(
                _gmxV2DataStore,
                _salt
            );

            if (_marketData.marketToken == address(0)) revert ("_setAdditionalData: InvalidMarketToken");
            if (_marketData.indexToken != _indexToken) revert ("_setAdditionalData: InvalidIndexToken");

            _ethLongMarketToken = _marketData.marketToken;
            _ethShortMarketToken = _marketData.marketToken;
        }

        _ethLongMarketData = abi.encode(_ethLongMarketToken);
        _ethShortMarketData = abi.encode(_ethShortMarketToken);
    }

    function _setDictatorRoles() internal {
        if (_orchestrator == address(0)) revert("_setDictatorRoles: ZERO_ADDRESS");

        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));
        _setRoleCapability(1, address(_orchestrator), _orchestratorInstance.decreaseSize.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.setRouteType.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.initialize.selector, true);
        _setRoleCapability(0, address(_orchestrator), _orchestratorInstance.updateFees.selector, true);

        _setUserRole(_deployer, 0, true);
        _setUserRole(_deployer, 1, true);
    }

    function _initializeDataStore() internal {
        DataStore _dataStoreInstance = DataStore(_dataStore);
        _dataStoreInstance.updateOwnership(_orchestrator, true);
        _dataStoreInstance.updateOwnership(_routeFactory, true);
        _dataStoreInstance.updateOwnership(_deployer, false);
    }

    function _initializeOrchestrator() internal {
        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));

        bytes memory _gmxInfo = abi.encode(_gmxV2Router, _gmxV2ExchangeRouter, _gmxV2OrderVault, _gmxV2OrderHandler, _gmxV2Reader, _gmxV2DataStore);
        _orchestratorInstance.initialize(_minExecutionFeeGMXV2, _weth, _deployer, _routeFactory, _gmxInfo);
        _orchestratorInstance.setRouteType(_weth, _weth, true, _ethLongMarketData);
        _orchestratorInstance.setRouteType(_usdcOld, _weth, false, _ethShortMarketData);

        uint256 _managementFee = 100; // 1% fee
        uint256 _withdrawalFee = 100; // 1% fee
        uint256 _performanceFee = 500; // 5% max fee
        _orchestratorInstance.updateFees(_managementFee, _withdrawalFee, _performanceFee);

        IBaseOrchestrator(_orchestrator).depositExecutionFees{ value: 0.1 ether }();
    }

    function _initializeResolver() internal {
        DecreaseSizeResolver(payable(_decreaseSizeResolver)).createTask(_orchestrator);



        // DepositFundsToGelato1Balance.s.sol // TODO -- run this script manually

        // _setUserRole(_gelatoFunctionCallerArbi, 1, true); // TODO -- whitelist Gelato Function Caller
    }

    function _printAddresses() internal {
        emit Log("Deployed Addresses");
        emit Log("==============================================");
        emit Log("==============================================");
        emit LogNamedAddress("DataStore: ", _dataStore);
        emit LogNamedAddress("RouteFactory: ", _routeFactory);
        emit LogNamedAddress("Orchestrator: ", _orchestrator);
        emit LogNamedAddress("DecreaseSizeResolver: ", _decreaseSizeResolver);
        emit LogNamedAddress("ScoreGaugeV1: ", _scoreGaugeV1);
        emit Log("==============================================");
        emit Log("==============================================");
    }
}

// ------------------- Libraries -------------------

// src/integrations/libraries:
// Keys: // --libraries 'src/integrations/libraries/Keys.sol:Keys:0xa9A725FA649093e7ab5b368EcA0fd5D7703fA6c6'
// CommonHelper: // --libraries 'src/integrations/libraries/CommonHelper.sol:CommonHelper:0x20C1E1e86611eF39EbbBe4e011C17400Aa5C0351'
// SharesHelper: // --libraries 'src/integrations/libraries/SharesHelper.sol:SharesHelper:0x7B2D7d166Fd18449b90F8Af24cbfE6118ae2e10e'
// RouteReader: // --libraries 'src/integrations/libraries/RouteReader.sol:RouteReader:0x1A90e321D0D019383599936D45323C210dE5C12D'
// RouteSetter: // --libraries 'src/integrations/libraries/RouteSetter.sol:RouteSetter:0x56BDB07eB4492beB272531A7E46E9aEEc961A540'
// OrchestratorHelper: // --libraries 'src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper:0xE38CEAA21E5E0A3C0418DC0a520085a77231cCF5'

// src/integrations/GMXV2/libraries:
// GMXV2Keys: // --libraries 'src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:0xbC730fF81eD4E1e85485f0703e35C0448Bc60aE5'
// GMXV2OrchestratorHelper: // --libraries 'src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper:0x5BAA0537c3B448aDFd53da5Bb0D23e552402B9EB'
// OrderUtils: // --libraries 'src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:0x52daBB11490Df14911e82adC525C278379f39980'
// GMXV2RouteHelper: // --libraries 'src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper:0x0f4a0d8fC9E499D876f6f7c2A8e4b8a1360B0c16'

// ------------------- Contracts -------------------

// DataStore:  0x75236b405F460245999F70bc06978AB2B4116920
// RouteFactory:  0xF72042137F5a1b07E683E55AF8701CEBfA051cf4
// Orchestrator:  0x9212c5a9e49B4E502F2A6E0358DEBe038707D6AC
// DecreaseSizeResolver:  0x4ae74D2Cb2F10D90e6E37Cf256A15a783C4f655B
// ScoreGaugeV1:  0x0000000000000000000000000000000000000000