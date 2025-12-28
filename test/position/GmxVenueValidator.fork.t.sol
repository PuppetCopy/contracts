// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test, console2} from "forge-std/src/Test.sol";
import {GmxVenueValidator} from "../../src/position/validator/GmxVenueValidator.sol";
import {Dictatorship} from "../../src/shared/Dictatorship.sol";

interface IPositionStoreUtils {
    function getAccountPositionKeys(address dataStore, address account, uint256 start, uint256 end) external view returns (bytes32[] memory);
    function getAccountPositionCount(address dataStore, address account) external view returns (uint256);
}

interface IDataStore {
    function getBytes32ValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (bytes32[] memory);
    function getBytes32Count(bytes32 setKey) external view returns (uint256);
}

/**
 * @title GmxVenueValidatorForkTest
 * @notice Fork test to verify GmxVenueValidator against real GMX V2 positions
 * @dev Run: forge test --match-contract GmxVenueValidatorForkTest --fork-url $RPC_URL -vvvv
 */
contract GmxVenueValidatorForkTest is Test {
    // GMX V2 Arbitrum Mainnet
    address constant GMX_DATASTORE = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant GMX_READER = 0x470fbC46bcC0f16532691Df360A07d8Bf5ee0789;
    address constant GMX_REFERRAL_STORAGE = 0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d;

    // Keys for position list
    bytes32 constant POSITION_LIST = keccak256(abi.encode("POSITION_LIST"));

    Dictatorship dictator;
    GmxVenueValidator validator;
    IDataStore dataStore;

    function setUp() public {
        dictator = new Dictatorship(address(this));
        validator = new GmxVenueValidator(GMX_DATASTORE, GMX_READER, GMX_REFERRAL_STORAGE);
        dictator.registerContract(address(validator));
        dataStore = IDataStore(GMX_DATASTORE);
    }

    function test_GetPositionNetValue() public view {
        // Get first few position keys from GMX DataStore
        uint256 positionCount = dataStore.getBytes32Count(POSITION_LIST);
        console2.log("Total positions in GMX:", positionCount);

        if (positionCount == 0) {
            console2.log("No positions found");
            return;
        }

        // Get up to 5 positions
        uint256 toFetch = positionCount > 5 ? 5 : positionCount;
        bytes32[] memory positionKeys = dataStore.getBytes32ValuesAt(POSITION_LIST, 0, toFetch);

        console2.log("\n=== Position Net Values ===");
        for (uint256 i = 0; i < positionKeys.length; i++) {
            bytes32 posKey = positionKeys[i];
            console2.log("\nPosition", i);
            console2.logBytes32(posKey);

            try validator.getPositionNetValue(posKey) returns (uint256 netValue) {
                console2.log("Net Value (token units):", netValue);
            } catch Error(string memory reason) {
                console2.log("Error:", reason);
            } catch (bytes memory) {
                console2.log("Error: low-level revert");
            }
        }
    }

    function test_SinglePositionValue() public view {
        // Test with a specific known position key (can be updated)
        // This is a placeholder - the test_GetPositionNetValue will find real ones
        bytes32 positionKey = bytes32(0);

        if (positionKey == bytes32(0)) {
            console2.log("No specific position key set, skipping");
            return;
        }

        uint256 netValue = validator.getPositionNetValue(positionKey);
        console2.log("Net Value:", netValue);
    }
}
