// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title PuppetToken
 * @dev An ERC20 token with a governance-controlled mint rate limit to mitigate possible abuse and ensure stability until it reaches clarity through
 * maturity
 * The mint rate limit is designed to cap the amount of new tokens that can be minted within a specified time window,
 * as a percentage of the total tokens emitted since the initial supply. the mint rate limit can be lifted or adjust through governance once clarity
 * is achieved.
 */
contract PuppetToken is Auth, ERC20 {
    event PuppetToken__MintLimitRateSet(uint rateLimitFactor, uint timeframeLimit);

    string private constant _NAME = "Muppet Test";
    string private constant _SYMBOL = "MUPPET";

    uint private constant DAO_SUPPLY = 2_000_000e18;
    uint private constant CORE_SUPPLY = 1_000_000e18;
    uint private constant ESCROWED_SUPPLY = DAO_SUPPLY + CORE_SUPPLY;
    uint private constant LP_BOOTSTRAP = 100_000e18;
    uint private constant INITIAL_SUPPLY = ESCROWED_SUPPLY + LP_BOOTSTRAP;

    uint private constant BASIS_DIVISOR = 10000;

    // Rate limit for minting new tokens (100 basis points = 1% of total emitted tokens per hour)
    uint public rateLimitFactor = 100;
    // Time window for rate limit calculation (1 hour)
    uint public timeframeLimit = 1 hours;
    // Amount minted in the current window
    uint public mintWindowCount;
    // Current epoch for rate limit calculation
    uint public epoch;

    constructor(Authority _authority, address _governance) Auth(address(0), _authority) ERC20(_NAME, _SYMBOL) {
        _mint(_governance, INITIAL_SUPPLY);

        emit PuppetToken__MintLimitRateSet(rateLimitFactor, timeframeLimit);
    }

    function totalEmitted() public view returns (uint) {
        return totalSupply() - ESCROWED_SUPPLY;
    }

    function rateLimit() public view returns (uint) {
        return totalEmitted() * rateLimitFactor / BASIS_DIVISOR;
    }

    /**
     * @dev Mints new tokens with a governance-controlled rate limit.
     * @param _for The address to mint tokens for.
     * @param _amount The amount of tokens to mint.
     * @return The amount of tokens minted.
     */
    function mint(address _for, uint _amount) external requiresAuth returns (uint) {
        uint nextEpoch = block.timestamp / timeframeLimit;

        // Reset mint count and update epoch at the start of a new window
        if (nextEpoch > epoch) {
            mintWindowCount = 0;
            epoch = nextEpoch;
        }

        // Add the requested mint amount to the window's mint count
        mintWindowCount += _amount;

        // Enforce the mint rate limit based on total emitted tokens
        if (mintWindowCount > rateLimit()) {
            revert PuppetToken__ExceededRateLimit(timeframeLimit, rateLimitFactor, rateLimit());
        }

        _mint(_for, _amount);
        return _amount;
    }

    /**
     * @dev Allows governance to adjust the mint rate limit and window.
     * @param _rateLimitFactor The new rate limit as a basis point percentage of total emitted tokens.
     * @param _timeframeLimit The new mint window timeframe in seconds.
     */
    function setMintLimitRate(uint _rateLimitFactor, uint _timeframeLimit) external requiresAuth {
        if (_rateLimitFactor > BASIS_DIVISOR) {
            revert PuppetToken__InvalidRate();
        }

        rateLimitFactor = _rateLimitFactor;
        timeframeLimit = _timeframeLimit;
        mintWindowCount = 0; // Reset the mint count window on rate limit change

        emit PuppetToken__MintLimitRateSet(_rateLimitFactor, _timeframeLimit);
    }

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint limitWindow, uint rateLimit, uint maxMintAmount);
}
