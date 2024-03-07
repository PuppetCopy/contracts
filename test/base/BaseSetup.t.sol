// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWeightedPoolFactory} from "test/interfaces/IWeightedPoolFactory.sol";
import {IRateProvider} from "test/interfaces/IRateProvider.sol";

import {Context, Expectations, Users, ForkIDs} from "test/utilities/Types.sol";

import {DataStore} from "src/integrations/utilities/DataStore.sol";
import {DecreaseSizeResolver} from "src/integrations/utilities/DecreaseSizeResolver.sol";
import {Dictator} from "src/utilities/Dictator.sol";

import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {WNT} from "src/utilities/common/WNT.sol";

import {DeployerUtilities} from "script/utilities/DeployerUtilities.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";

/// @notice Base test contract with common functionality needed by all tests
abstract contract BaseSetup is BasicSetup, DeployerUtilities {
    // ============================================================================================
    // Variables
    // ============================================================================================

    bytes internal _emptyBytes;

    uint internal _polygonForkId;
    uint internal _arbitrumForkId;

    Context public context;
    // Roles public roles;
    Expectations public expectations;
    ForkIDs public forkIDs;

    // ============================================================================================
    // Contracts
    // ============================================================================================

    // utilities
    Dictator internal _dictator;
    DataStore internal _dataStore;

    // token
    WNT internal _wnt;
    PuppetToken internal _puppetERC20;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual override {
        BasicSetup.setUp();

        forkIDs = ForkIDs({arbitrum: vm.createFork(vm.envString("ARBITRUM_RPC_URL"))});

        vm.selectFork(forkIDs.arbitrum);
        assertEq(vm.activeFork(), forkIDs.arbitrum, "arbitrum fork not selected");

        _deployTokenAndUtils();

        _labelContracts();

        // set chain id to Arbitrum
        vm.chainId(4216138);
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _deployTokenAndUtils() internal {
        vm.startPrank(users.owner);

        _dictator = new Dictator(users.owner);
        _dataStore = new DataStore(users.owner);
        _puppetERC20 = new PuppetToken(_dictator, _dictator.owner());

        vm.stopPrank();
        vm.startPrank(users.owner);

        _wnt = new WNT();
        // _rewardRouter = new RewardRouter(
        //     _dictator, IERC20(address(_puppetERC20)), _votingEscrow, _gaugeController, _wnt, _router, users.treasury
        // );

        _setUserRole(users.owner, 0, true);
        _setUserRole(users.keeper, 1, true);

        vm.stopPrank();
    }

    // // OPTIONAL -- use a WeightedPool2Tokens instead of WeightedPoolV4
    // // WeightedPool2Tokens was released alongside, but distinct from, WeightedPoolV1. The differences are that it's
    // optimized for 2 tokens and adds oracles
    // // it's deprecated, but it's the only one that has an oracle. the use of the oracle is not recommended, as
    // described here: https://chainsecurity.com/oracle-manipulation-after-merge/
    // // use function `getTimeWeightedAverage` to get the price
    // // WeightedPool2Tokens Factory on Arbitrum:
    // https://github.com/balancer/balancer-deployments/blob/master/tasks/deprecated/20210418-weighted-pool/output/arbitrum.json#L3
    // function _initBalancerPool() internal {
    //     vm.startPrank(users.owner);

    //     // setup 8020 pool, used in VotingEscrow
    //     _balancerOperations = new BalancerOperations();
    //     IWeightedPoolFactory _weightedPoolFactory = IWeightedPoolFactory(0xc7E5ED1054A24Ef31D827E6F86caA58B3Bc168d7);

    //     IRateProvider[] memory _rateProviders = new IRateProvider[](2);
    //     _rateProviders[0] = IRateProvider(address(0));
    //     _rateProviders[1] = IRateProvider(address(0));
    //     IERC20[] memory _tokens = new IERC20[](2);
    //     _tokens[0] = IERC20(_weth);
    //     _tokens[1] = IERC20(address(_puppetERC20));
    //     uint[] memory _normalizedWeights = new uint[](2);
    //     _normalizedWeights[0] = 200000000000000000;
    //     _normalizedWeights[1] = 800000000000000000;

    //     address _bpt = _weightedPoolFactory.create(
    //         "80PUPPET-20ETH", "80PUPPET-20ETH", _tokens, _normalizedWeights, _rateProviders, 10000000000000000, users.owner, bytes32(0)
    //     );

    //     _puppetBPT = IERC20(_bpt);

    //     // seed liquidity
    //     _dealERC20(_weth, users.owner, 100 ether);
    //     uint _balance = _puppetERC20.balanceOf(users.owner);
    //     require(_balance > 0, "_initBalancerPool: E0");

    //     address[] memory _tokenAddresses = new address[](2);
    //     _tokenAddresses[0] = _weth;
    //     _tokenAddresses[1] = address(_puppetERC20);
    //     uint[] memory _amounts = new uint[](2);
    //     _amounts[0] = 10 * 1e18;
    //     _amounts[1] = _balance;
    //     IERC20(_weth).approve(address(_balancerOperations), 10 * 1e18);
    //     Puppet(_puppetERC20).approve(address(_balancerOperations), _balance);
    //     _balancerOperations.initPool(address(_puppetBPT), _tokenAddresses, _amounts);

    //     vm.stopPrank();
    // }

    function _labelContracts() internal {
        vm.label({account: address(_dictator), newLabel: "Dictator"});
        vm.label({account: address(_dataStore), newLabel: "DataStore"});
        vm.label({account: address(_puppetERC20), newLabel: "PuppetERC20"});
    }

    /// @dev Generates a user, labels its address, and funds it with test assets
    function _createUser(string memory _name) internal returns (address payable) {
        address payable _user = payable(makeAddr(_name));
        vm.deal({account: _user, newBalance: 100 ether});
        deal({token: address(_wnt), to: _user, give: 1_000_000 * 10 ** 18});
        deal({token: address(_usdcOld), to: _user, give: 1_000_000 * 10 ** 6});
        deal({token: address(_usdc), to: _user, give: 1_000_000 * 10 ** 6});
        deal({token: address(_frax), to: _user, give: 1_000_000 * 10 ** 6});
        return _user;
    }

    // function grantTesterRole(Dictator _dictator, address _user, address _contract) internal {
    //     // _setRoleCapability(0, address(_votingEscrow), addToWhitelistSig, true);
    //     _dictator.setRoleCapability(2, _contract, functionSig, true);

    //     // bytes4 _grantRoleSig = _dictator.grantRole.selector;
    //     // _dictator.grantRole(_contract, _user, _role);
    // }

    function _depositFundsToGelato1Balance() internal {
        // vm.selectFork(forkIDs.polygon);
        // assertEq(vm.activeFork(), forkIDs.polygon, "_depositFundsToGelato1Balance: polygon fork not selected");

        DecreaseSizeResolver _resolver = new DecreaseSizeResolver(_dictator, _gelatoAutomationPolygon, address(0));

        uint _amount = 1_000_000 * 10 ** 6;
        deal({token: address(_polygonUSDC), to: address(_resolver), give: _amount});

        _resolver.depositFunds(_amount, _polygonUSDC, users.owner);

        vm.selectFork(forkIDs.arbitrum);
        assertEq(vm.activeFork(), forkIDs.arbitrum, "_depositFundsToGelato1Balance: arbitrum fork not selected");
    }

    function _approveERC20(address _spender, address _token, uint _amount) internal {
        IERC20(_token).approve(_spender, 0);
        IERC20(_token).approve(_spender, _amount);
    }
}
