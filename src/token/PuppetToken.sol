// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Permission} from "./../utils/auth/Permission.sol";

import {Precision} from "./../utils/Precision.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @title PuppetToken
 * @dev An ERC20 token with a mint rate limit designed to mitigate and provide feedback of a potential critical faults or bugs in the minting process.
 * The limit restricts the quantity of new tokens that can be minted within a given timeframe, proportional to the existing supply.
 *
 * The mintCore function in the contract is designed to allocate tokens to the core contributors over time, with the allocation amount decreasing
 * as more time passes from the deployment of the contract. This is intended to gradually transfer governance power and incentivises broader ownership
 */
contract PuppetToken is Permission, ERC20 {
    event PuppetToken__SetConfig(Config config);
    event PuppetToken__MintCore(address operator, address indexed receiver, uint amount);

    uint private constant CORE_RELEASE_DURATION_DIVISOR = 31560000; // 1 year
    uint private constant GENESIS_MINT_AMOUNT = 100_000e18;

    struct Config {
        uint limitFactor; // Rate limit for minting new tokens in percentage of total supply, e.g. 0.01e30 (1%) circulating supply per durationWindow
        uint durationWindow; // Time window for minting rate limit in seconds
    }

    Config public config;

    uint lastMintTime = block.timestamp; // Last mint time for the rate limit window
    uint emissionRate; // Current mint capacity

    uint public immutable deployTimestamp = block.timestamp; // used to calculate the deminishing mint rate for core minting
    uint public mintedCoreAmount = 0; // the amount of tokens minted to the core

    constructor(IAuthority _authority, Config memory _config, address receiver) Permission(_authority) ERC20("Puppet Test", "PUPPET-TEST") {
        _setConfig(_config);
        _mint(receiver, GENESIS_MINT_AMOUNT);
    }

    function getCoreShare() public view returns (uint) {
        return getCoreShare(lastMintTime);
    }

    function getCoreShare(uint _time) public view returns (uint) {
        uint _timeElapsed = _time - deployTimestamp;
        return Precision.toFactor(CORE_RELEASE_DURATION_DIVISOR, CORE_RELEASE_DURATION_DIVISOR + _timeElapsed);
    }

    function getMintableCoreAmount(uint _lastMintTime) public view returns (uint) {
        uint _totalMinedAmount = totalSupply() - mintedCoreAmount - GENESIS_MINT_AMOUNT;
        uint _maxMintableAmount = Precision.applyFactor(getCoreShare(_lastMintTime), _totalMinedAmount);

        if (_maxMintableAmount < mintedCoreAmount) revert PuppetToken__CoreShareExceedsMining();

        return _maxMintableAmount - mintedCoreAmount;
    }

    function getLimitAmount() public view returns (uint) {
        return Precision.applyFactor(config.limitFactor, totalSupply());
    }

    /**
     * @dev Mints new tokens with a governance-configured rate limit.
     * @param _receiver The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     * @return The amount of tokens minted.
     */
    function mint(address _receiver, uint _amount) external auth returns (uint) {
        uint _limitAmount = getLimitAmount();
        uint _timeElapsed = block.timestamp - lastMintTime;
        uint _decayRate = _limitAmount * _timeElapsed / config.durationWindow;

        if (_decayRate > _amount) {
            uint _nextRateDelta = _decayRate - _amount;
            emissionRate = _nextRateDelta > emissionRate ? 0 : emissionRate - _nextRateDelta;
        } else {
            emissionRate += (_amount - _decayRate);

            // Enforce the mint rate limit based on total emitted tokens
            if (emissionRate > _limitAmount) {
                revert PuppetToken__ExceededRateLimit(_limitAmount, emissionRate);
            }
        }

        // Add the requested mint amount to the window's mint count
        _mint(_receiver, _amount);
        lastMintTime = block.timestamp;

        return _amount;
    }

    /**
     * @dev Mints new tokens to the core with a time-based reduction release schedule.
     * @param _receiver The address to mint tokens to.
     */
    function mintCore(address _receiver) external auth returns (uint) {
        uint _lastMintTime = lastMintTime;
        uint _mintableAmount = getMintableCoreAmount(_lastMintTime);

        mintedCoreAmount += _mintableAmount;
        _mint(_receiver, _mintableAmount);

        emit PuppetToken__MintCore(msg.sender, _receiver, _mintableAmount);

        return _mintableAmount;
    }

    /**
     * @dev Set the mint rate limit for the token.
     * @param _config The new rate limit configuration.
     */
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        if (_config.limitFactor == 0) revert PuppetToken__InvalidRate();

        config = _config;
        emissionRate = 0; // Reset the mint count window on rate limit change

        emit PuppetToken__SetConfig(_config);
    }

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint rate);
    error PuppetToken__CoreShareExceedsMining();
}
