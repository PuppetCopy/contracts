// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utils/StoreController.sol";

uint8 constant SLOT_COUNT = 7;

contract OracleStore is StoreController {
    struct SlotSeed {
        uint price;
        uint blockNumber;
        uint timestamp;
        uint updateInterval;
    }

    SlotSeed public seedUpdate;

    uint public slot;

    uint[SLOT_COUNT] public slotMin;
    uint public medianMin;

    uint[SLOT_COUNT] public slotMax;
    uint public medianMax;

    constructor(Authority _authority, address _initSetter, uint _seedPrice, uint _updateInterval) StoreController(_authority, _initSetter) {
        require(_seedPrice > 0, "Seed price cannot be 0");

        seedUpdate = SlotSeed({price: _seedPrice, blockNumber: block.number, timestamp: block.timestamp, updateInterval: _updateInterval});

        slot = (seedUpdate.timestamp / _updateInterval) % SLOT_COUNT;

        /// seed all the OHLC data with the initial high price
        for (uint i = 0; i < SLOT_COUNT; i++) {
            slotMin[i] = _seedPrice;
            slotMax[i] = _seedPrice;
        }

        medianMin = _seedPrice;
        medianMax = _seedPrice;
    }

    function getLatestSeed() external view returns (SlotSeed memory) {
        return seedUpdate;
    }

    function getSlotArrMin() external view returns (uint[SLOT_COUNT] memory) {
        return slotMin;
    }

    function getSlotArrMax() external view returns (uint[SLOT_COUNT] memory) {
        return slotMax;
    }

    function setLatestUpdate(SlotSeed memory _seedUpdate) external isSetter {
        seedUpdate = _seedUpdate;
    }

    function setSeedUpdateInterval(uint _updateInterval) external isSetter {
        SlotSeed memory nextSeed = SlotSeed({
            price: seedUpdate.price,
            blockNumber: seedUpdate.blockNumber,
            timestamp: seedUpdate.timestamp,
            updateInterval: _updateInterval
        });

        seedUpdate = nextSeed;
    }

    function setSlot(uint8 _slot) external isSetter {
        slot = _slot;
    }

    function setSlotMin(uint8 _slot, uint _price) external isSetter {
        slotMin[_slot] = _price;
    }

    function setMedianMin(uint _medianMin) external isSetter {
        medianMin = _medianMin;
    }

    function setSlotMax(uint8 _slot, uint _price) external isSetter {
        slotMax[_slot] = _price;
    }

    function setMedianMax(uint _medianMax) external isSetter {
        medianMax = _medianMax;
    }
}
