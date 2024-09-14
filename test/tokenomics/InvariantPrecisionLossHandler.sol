// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {console2} from "forge-std/src/console2.sol";
import {CommonBase} from "forge-std/src/Base.sol";
import {StdUtils} from "forge-std/src/StdUtils.sol";
import {Precision} from "../../src/utils/Precision.sol";
import {Test, console} from "forge-std/src/Test.sol";


contract PrecisionLoss{

    uint256 multiplier =0.1e30;
    uint256 MAXTIME = 63120000;

    function getVestedBonusOriginal(uint amount, uint duration) public view returns (uint) {
        uint numerator = multiplier * duration ** 2;

        uint256 calc = numerator / MAXTIME ** 2;
        return Precision.applyFactor(calc, amount);
    }

    function getVestedBonusSimplified(uint amount, uint duration) public view returns (uint) {
        uint numerator = multiplier * duration ** 2;

        uint256 calc = Precision.applyFactor(numerator, amount);
        return calc / MAXTIME ** 2;
    }
}

contract InvariantPrecisionLossHandler is Test {
    // real contract being tested
    PrecisionLoss internal _underlying;

    // invariant variables, set to 1 as the invariant will
    // be errorOutput != 0, so don't want it to fail immediately 
    uint public originalOutput   = 1;
    uint public simplifiedOutput = 1;

    // optimized finding variables
    uint public maxPrecisionLoss;
    uint public mplAmount;
    uint public mplDuration;

    function setUp() public {
        _underlying = new PrecisionLoss();
    }

    // function that will be called during invariant fuzz tests
    function testGetVestedBonus(uint amount, uint duration) public {
        // precision ranges
        amount = bound(amount, 0 , 1000000000e18 );
        duration  = bound(duration , 0, 63120000);

        // run both original & simplified functions
        originalOutput   = _underlying.getVestedBonusOriginal(amount, duration);
        simplifiedOutput = _underlying.getVestedBonusSimplified(amount, duration);

        // find the difference in precision loss
        uint precisionLoss = simplifiedOutput - originalOutput;

        //
        // if this run produced greater precision loss than all 
        // previous, or if the precision loss was the same AND 
        // originalOutput == 0 AND simplifiedOutput > 0, then save it 
        // & its inputs
        //
        // we are really interested in seeing if we can reach a state
        // where originalOutput == 0 && simplifiedOutput > 0 as this 
        // is a more damaging form of precision loss
        //
        // could also optimize for lowest uusdAmount & daiAmount 
        // required to produce the precision loss.
        //
        assert(precisionLoss == 0);
        if(precisionLoss > 0) {
            if(precisionLoss > maxPrecisionLoss || 
                (precisionLoss == maxPrecisionLoss 
              && originalOutput == 0 && simplifiedOutput > 0)) {
                maxPrecisionLoss = precisionLoss;
                mplAmount    = amount;
                mplDuration     = duration;

                console2.log("originalOutput   : ", originalOutput);
                console2.log("simplifiedOutput : ", simplifiedOutput);
                console2.log("maxPrecisionLoss : ", maxPrecisionLoss);
                console2.log("mplAmount    : ", mplAmount);
                console2.log("mplDuration     : ", mplDuration);
            }            
        }

    }
}