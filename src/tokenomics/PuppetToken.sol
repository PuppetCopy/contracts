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
 *
 * The mintCore function in the contract is designed to allocate tokens to the core contributors over time, with the allocation amount decreasing
 * as more time passes from the deployment of the contract. This is intended to gradually transfer governance power and incentivises broader ownership
 */
contract PuppetToken is Auth, ERC20 {
    event PuppetToken__SetConfig(Config config);
    event PuppetToken__MintCore(address operator, address receiver, uint timestamp, uint amount, uint share);

    uint private constant CORE_SHARE_MULTIPLIER = 0.5e30; // 50%, starting power factor for core minting
    uint private constant CORE_RELEASE_DURATION_DIVISOR = 31540000; // 1 year
    uint private constant GENESIS_MINT_AMOUNT = 100_000e18;

    struct Config {
        uint limitFactor; // Rate limit for minting new tokens in basis points
        uint durationWindow; // Time window for minting rate limit in seconds
    }

    Config public config;

    uint windowCount = 0; // Current mint count for the rate limit window
    uint epoch = 0; // Current epoch for rate limit calculation

    uint public deployTimestamp = block.timestamp; // used to calculate the deminishing mint rate for core minting
    uint public mineMintCount = 0; // the amount of tokens minted through protocol use
    uint public coreMintCount = 0; // the  amount of tokens released to the core

    constructor(Dictator _authority, Config memory _config) Auth(address(0), _authority) ERC20("Puppet Test", "PUPPET-TEST") {
        _setConfig(_config); // init at 1% of circulating supply per hour
        _mint(_authority.owner(), GENESIS_MINT_AMOUNT);
    }

    function getLimitAmount() public view returns (uint) {
        return Precision.applyFactor(config.limitFactor, totalSupply());
    }

    function getMarginAmount() public view returns (uint) {
        return getLimitAmount() - windowCount;
    }

    function getCoreShare() public view returns (uint) {
        uint _timeElapsed = block.timestamp - deployTimestamp;
        uint _diminishFactor = Precision.toFactor(CORE_RELEASE_DURATION_DIVISOR + _timeElapsed, CORE_RELEASE_DURATION_DIVISOR);
        return Precision.toFactor(CORE_SHARE_MULTIPLIER, _diminishFactor);
    }

    /**
     * @dev Mints new tokens with a governance-controlled rate limit.
     * @param _receiver The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     * @return The amount of tokens minted.
     */
    function mint(address _receiver, uint _amount) external requiresAuth returns (uint) {
        uint _nextEpoch = block.timestamp / config.durationWindow;

        // Reset mint count and update epoch at the start of a new window
        if (_nextEpoch > epoch) {
            windowCount = 0;
            epoch = _nextEpoch;
        }

        // Add the requested mint amount to the window's mint count
        windowCount += _amount;
        mineMintCount += _amount;

        // Enforce the mint rate limit based on total emitted tokens
        if (windowCount > getLimitAmount()) {
            revert PuppetToken__ExceededRateLimit(getLimitAmount() - (windowCount - _amount));
        }

        _mint(_receiver, _amount);
        return _amount;
    }

    /**
     * @dev Mints new tokens to the core with a time-based reduction release schedule.
     * @param _receiver The address to mint tokens to.
     * @return The amount of tokens minted.
     */
    function mintCore(address _receiver) external requiresAuth returns (uint) {
        uint _mintShare = getCoreShare();
        uint _maxMintable = mineMintCount * _mintShare / Precision.FLOAT_PRECISION;
        uint _mintable = _maxMintable - coreMintCount;

        _mint(_receiver, _mintable);

        coreMintCount += _mintable;

        emit PuppetToken__MintCore(msg.sender, _receiver, block.timestamp, _mintable, _mintShare);

        return _mintable;
    }

    /**
     * @dev Set the mint rate limit for the token.
     * @param _config The new rate limit configuration.
     */
    function setConfig(Config calldata _config) external requiresAuth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        if (_config.limitFactor == 0) revert PuppetToken__InvalidRate();

        config = _config;
        windowCount = 0; // Reset the mint count window on rate limit change

        emit PuppetToken__SetConfig(_config);
    }

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint maxMintableAmount);
}
