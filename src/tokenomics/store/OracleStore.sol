// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";

uint8 constant SLOT_COUNT = 7;

contract OracleStore is StoreController {
    struct SeedSlot {
        uint price;
        uint blockNumber;
        uint timestamp;
    }

    SeedSlot public seed;

    uint public slot;

    uint[SLOT_COUNT] public slotMin;
    uint public medianMin;

    uint[SLOT_COUNT] public slotMax;
    uint public medianMax;

    constructor(Authority _authority, address _initSetter, uint _seedPrice) StoreController(_authority, _initSetter) {
        require(_seedPrice > 0, "Seed price cannot be 0");

        seed = SeedSlot({price: _seedPrice, blockNumber: block.number, timestamp: block.timestamp});

        /// seed all the OHLC data with the initial high price
        for (uint i = 0; i < SLOT_COUNT; i++) {
            slotMin[i] = _seedPrice;
            slotMax[i] = _seedPrice;
        }

        medianMin = _seedPrice;
        medianMax = _seedPrice;
    }

    function getLatestSeed() external view returns (SeedSlot memory) {
        return seed;
    }

    function setLatestSeed(SeedSlot memory _seed) external isSetter {
        seed = _seed;
    }

    function getSlotArrMin() external view returns (uint[SLOT_COUNT] memory) {
        return slotMin;
    }

    function setSlotMin(uint8 _slot, uint _price) external isSetter {
        slotMin[_slot] = _price;
    }

    function getSlotArrMax() external view returns (uint[SLOT_COUNT] memory) {
        return slotMax;
    }

    function setSlotMax(uint8 _slot, uint _price) external isSetter {
        slotMax[_slot] = _price;
    }

    function setSlot(uint8 _slot) external isSetter {
        slot = _slot;
    }

    function setMedianMin(uint _medianMin) external isSetter {
        medianMin = _medianMin;
    }

    function setMedianMax(uint _medianMax) external isSetter {
        medianMax = _medianMax;
    }
}
