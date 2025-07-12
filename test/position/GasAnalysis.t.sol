// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

contract GasAnalysis is Test {
    function testAnalyzeGasData() public {
        // Raw data from fork test
        uint[] memory puppetCounts = new uint[](5);
        puppetCounts[0] = 1;
        puppetCounts[1] = 2;  
        puppetCounts[2] = 5;
        puppetCounts[3] = 10;
        puppetCounts[4] = 25;

        uint[] memory mirrorGas = new uint[](5);
        mirrorGas[0] = 1235690;
        mirrorGas[1] = 1130696;
        mirrorGas[2] = 1227611;
        mirrorGas[3] = 1358766;
        mirrorGas[4] = 1795630;

        uint[] memory adjustGas = new uint[](5);
        adjustGas[0] = 914075;
        adjustGas[1] = 913495;
        adjustGas[2] = 923742;
        adjustGas[3] = 940825;
        adjustGas[4] = 992003;

        console.log("=== MARGINAL GAS COST ANALYSIS ===");
        console.log("Calculating additional gas per puppet based on marginal increases:\n");

        // Calculate marginal cost per puppet (handle negative changes)
        console.log("MIRROR - Marginal gas per additional puppet:");
        for (uint i = 1; i < puppetCounts.length; i++) {
            uint puppetIncrease = puppetCounts[i] - puppetCounts[i-1];
            
            if (mirrorGas[i] >= mirrorGas[i-1]) {
                uint gasIncrease = mirrorGas[i] - mirrorGas[i-1];
                uint marginalGasPerPuppet = gasIncrease / puppetIncrease;
                console.log("From %s to %s puppets: +%s gas per puppet", 
                    puppetCounts[i-1], puppetCounts[i], marginalGasPerPuppet);
            } else {
                uint gasDecrease = mirrorGas[i-1] - mirrorGas[i];
                uint marginalGasPerPuppet = gasDecrease / puppetIncrease;
                console.log("From %s to %s puppets: -%s gas per puppet", 
                    puppetCounts[i-1], puppetCounts[i], marginalGasPerPuppet);
            }
        }

        console.log("\nADJUST - Marginal gas per additional puppet:");
        for (uint i = 1; i < puppetCounts.length; i++) {
            uint puppetIncrease = puppetCounts[i] - puppetCounts[i-1];
            
            if (adjustGas[i] >= adjustGas[i-1]) {
                uint gasIncrease = adjustGas[i] - adjustGas[i-1];
                uint marginalGasPerPuppet = gasIncrease / puppetIncrease;
                console.log("From %s to %s puppets: +%s gas per puppet", 
                    puppetCounts[i-1], puppetCounts[i], marginalGasPerPuppet);
            } else {
                uint gasDecrease = adjustGas[i-1] - adjustGas[i];
                uint marginalGasPerPuppet = gasDecrease / puppetIncrease;
                console.log("From %s to %s puppets: -%s gas per puppet", 
                    puppetCounts[i-1], puppetCounts[i], marginalGasPerPuppet);
            }
        }

        // Calculate base gas (extrapolated from 1 puppet data)
        console.log("\n=== BASE GAS CALCULATION ===");
        
        // Using 10-25 puppet range for most stable marginal cost
        uint mirrorMarginalCost = (mirrorGas[4] - mirrorGas[3]) / (puppetCounts[4] - puppetCounts[3]);
        uint adjustMarginalCost = (adjustGas[4] - adjustGas[3]) / (puppetCounts[4] - puppetCounts[3]);
        
        // Also calculate using 5-25 puppet range for better average
        uint mirrorMarginalCost2 = (mirrorGas[4] - mirrorGas[2]) / (puppetCounts[4] - puppetCounts[2]);
        uint adjustMarginalCost2 = (adjustGas[4] - adjustGas[2]) / (puppetCounts[4] - puppetCounts[2]);
        
        console.log("Mirror marginal cost (10-25 puppets): %s gas per puppet", mirrorMarginalCost);
        console.log("Adjust marginal cost (10-25 puppets): %s gas per puppet", adjustMarginalCost);
        console.log("Mirror marginal cost (5-25 puppets): %s gas per puppet", mirrorMarginalCost2);
        console.log("Adjust marginal cost (5-25 puppets): %s gas per puppet", adjustMarginalCost2);
        
        // Calculate base gas by subtracting marginal costs
        uint mirrorBaseGas = mirrorGas[0] - (1 * mirrorMarginalCost);
        uint adjustBaseGas = adjustGas[0] - (1 * adjustMarginalCost);
        
        console.log("\nEstimated base gas:");
        console.log("Mirror base gas: %s", mirrorBaseGas);
        console.log("Adjust base gas: %s", adjustBaseGas);
        
        console.log("\n=== FINAL FORMULA ===");
        console.log("requestMirror gas = %s + (puppetCount * %s)", mirrorBaseGas, mirrorMarginalCost);
        console.log("requestAdjust gas = %s + (puppetCount * %s)", adjustBaseGas, adjustMarginalCost);
        
        // Verify formulas with actual data
        console.log("\n=== FORMULA VERIFICATION ===");
        for (uint i = 0; i < puppetCounts.length; i++) {
            uint predictedMirror = mirrorBaseGas + (puppetCounts[i] * mirrorMarginalCost);
            uint predictedAdjust = adjustBaseGas + (puppetCounts[i] * adjustMarginalCost);
            
            console.log("Puppets: %s - Mirror predicted: %s, actual: %s", 
                puppetCounts[i], predictedMirror, mirrorGas[i]);
            console.log("Puppets: %s - Adjust predicted: %s, actual: %s", 
                puppetCounts[i], predictedAdjust, adjustGas[i]);
        }
    }
}