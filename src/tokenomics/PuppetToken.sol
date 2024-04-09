// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth} from "@solmate/contracts/auth/Auth.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../utils/Precision.sol";
import {Dictator} from "./../utils/Dictator.sol";

/**
 * @title PuppetToken
 * @dev An ERC20 token with a mint rate limit designed to mitigate and provide feedback of a potential critical faults or bugs in the minting process.
 * The limit restricts the quantity of new tokens that can be minted within a given timeframe, proportional to the existing supply.
 */
contract PuppetToken is Auth, ERC20 {
    event PuppetToken__SetConfig(Config config);
    event PuppetToken__ReleaseCore(address to, uint timestamp, uint amount, uint releasedAmount);

    string private constant _NAME = "Puppet Test";
    string private constant _SYMBOL = "PUPPET-TEST";

    uint private constant CORE_RELEASE_DURATION = 31540000 * 2; // 2 years
    uint private constant CORE_RELEASE_RATE = 0.35e30; // 35%
    uint private constant CORE_RELEASE_END_SCHEDULE = 1822262400; // Thu Sep 30 2027

    uint private constant GENESIS_MINT_AMOUNT = 100_000e18;

    struct Config {
        uint limitFactor; // Rate limit for minting new tokens in basis points
        uint durationWindow;
    }

    Config public config;

    uint mintWindowCount = 0;
    uint public epoch = 0; // Current epoch for rate limit calculation
    uint public coreReleasedAmount = 0; // the  amount of tokens released to the core

    constructor(Dictator _authority, Config memory _config) Auth(address(0), _authority) ERC20(_NAME, _SYMBOL) {
        _setConfig(_config); // init at 1% of circulating supply per hour
        _mint(_authority.owner(), GENESIS_MINT_AMOUNT);
    }

    function getLimitAmount() public view returns (uint) {
        return Precision.applyFactor(config.limitFactor, totalSupply());
    }

    function getMarginAmount() public view returns (uint) {
        return getLimitAmount() - mintWindowCount;
    }

    /**
     * @dev Mints new tokens with a governance-controlled rate limit.
     * @param _for The address to mint tokens for.
     * @param _amount The amount of tokens to mint.
     * @return The amount of tokens minted.
     */
    function mint(address _for, uint _amount) external requiresAuth returns (uint) {
        uint nextEpoch = block.timestamp / config.durationWindow;

        // Reset mint count and update epoch at the start of a new window
        if (nextEpoch > epoch) {
            mintWindowCount = 0;
            epoch = nextEpoch;
        }

        // Add the requested mint amount to the window's mint count
        mintWindowCount += _amount;

        // Enforce the mint rate limit based on total emitted tokens
        if (mintWindowCount > getLimitAmount()) {
            revert PuppetToken__ExceededRateLimit(config, getLimitAmount());
        }

        _mint(_for, _amount);
        return _amount;
    }

    function mintCoreRelease(address _to) external requiresAuth returns (uint) {
        if (block.timestamp > CORE_RELEASE_END_SCHEDULE) revert PuppetToken__CoreReleaseEnded();

        uint timeElapsed = CORE_RELEASE_END_SCHEDULE - block.timestamp;
        uint timeMultiplier = Math.min(Precision.toFactor(timeElapsed, CORE_RELEASE_END_SCHEDULE), Precision.FLOAT_PRECISION);
        uint maxMintableAmount = Precision.applyFactor(CORE_RELEASE_RATE, totalSupply());
        uint maxMintableAmountForPeriod = Precision.applyFactor(timeMultiplier, maxMintableAmount);
        uint mintableAmount = maxMintableAmountForPeriod - coreReleasedAmount;

        _mint(_to, mintableAmount);

        coreReleasedAmount += mintableAmount;

        emit PuppetToken__ReleaseCore(_to, block.timestamp, mintableAmount, coreReleasedAmount);

        return mintableAmount;
    }

    /**
     * @dev Set the mint rate limit for the token.
     * @param _config The new rate limit configuration.
     */
    function setConfig(Config calldata _config) external requiresAuth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;
        mintWindowCount = 0; // Reset the mint count window on rate limit change

        emit PuppetToken__SetConfig(_config);
    }

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(Config config, uint maxMintAmount);
    error PuppetToken__CoreReleaseEnded();
}
