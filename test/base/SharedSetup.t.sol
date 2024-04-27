// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Dictator} from "src/shared/Dictator.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Router} from "src/shared/Router.sol";

import {VotingEscrow} from "src/tokenomics/VotingEscrow.sol";

import {SubaccountFactory} from "src/shared/SubaccountFactory.sol";

import {SubaccountStore} from "src/shared/store/SubaccountStore.sol";
import {CugarStore} from "src/shared/store/CugarStore.sol";
import {Cugar} from "src/shared/Cugar.sol";

import {Role} from "script/Const.sol";

import {BasicSetup} from "./BasicSetup.t.sol";

contract SharedSetup is BasicSetup {
    VotingEscrow votingEscrow;
    SubaccountStore subaccountStore;
    SubaccountFactory subaccountFactory;
    

    Cugar cugar;
    CugarStore cugarStore;

    function setUp() public virtual override {
        super.setUp();

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        dictator.setRoleCapability(Role.VEST, address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setRoleCapability(Role.VEST, address(votingEscrow), votingEscrow.withdraw.selector, true);
        dictator.setUserRole(address(votingEscrow), Role.TOKEN_TRANSFER, true);

        subaccountFactory = new SubaccountFactory(dictator);
        dictator.setRoleCapability(Role.SUBACCOUNT_CREATE, address(subaccountFactory), subaccountFactory.createSubaccount.selector, true);
        dictator.setRoleCapability(Role.SUBACCOUNT_SET_OPERATOR, address(subaccountFactory), subaccountFactory.setOperator.selector, true);

        subaccountStore = new SubaccountStore(dictator, address(subaccountFactory));

        cugar = new Cugar(dictator, votingEscrow);
        dictator.setRoleCapability(Role.INCREASE_CONTRIBUTION, address(cugar), cugar.increaseSeedContribution.selector, true);
        dictator.setRoleCapability(Role.CONTRIBUTE, address(cugar), cugar.contribute.selector, true);
        dictator.setRoleCapability(Role.CLAIM, address(cugar), cugar.claim.selector, true);

        cugarStore = new CugarStore(dictator, router, address(cugar));
        dictator.setUserRole(address(cugarStore), Role.TOKEN_TRANSFER, true);
    }
}
