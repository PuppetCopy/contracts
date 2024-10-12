// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {Permission} from "../utils/auth/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC20Mintable} from "../utils/interfaces/IERC20Mintable.sol";

/// @title PuppetToken
/// @notice An ERC20 token with a mint rate limit designed to mitigate and provide feedback of a
/// potential critical faults or bugs in the minting process.
/// @dev The limit restricts the quantity of new tokens that can be minted within a given timeframe, proportional to the
/// existing supply. The mintCore function in the contract is designed to allocate tokens to the core contributors over
/// time, with the allocation amount decreasing as more time passes from the deployment of the contract. This is
/// intended to gradually transfer governance power and incentivises broader ownership.
contract PuppetToken is CoreContract, ERC20, IERC20Mintable {
    /// @dev Constant representing the divisor for calculating core release duration.
    uint private constant CORE_RELEASE_DURATION_DIVISOR = 31560000; // 1 year

    /// @dev Constant representing the amount of tokens minted at genesis.
    uint private constant GENESIS_MINT_AMOUNT = 100_000e18;

    /// @notice The configuration for the mint rate limit.
    struct Config {
        // Rate limit for minting new tokens in percentage of total supply, e.g. 0.01e30 (1%)
        uint limitFactor;
        // circulating supply per durationWindow Time window for minting rate limit in seconds
        uint durationWindow;
    }

    /// @dev The timestamp of the last mint operation.
    uint lastMintTime = block.timestamp;

    /// @dev The current mint capacity.
    uint emissionRate;

    /// @notice The amount of tokens minted to the core.
    uint public mintedCoreAmount;

    /// @notice The timestamp when the contract was deployed.
    uint public immutable deployTimestamp = block.timestamp;

    /// @notice The current configuration.
    Config public config;

    /// @notice Initializes the contract with authority, configuration, and initial receiver of
    /// genesis mint.
    /// @param _authority The authority contract for permission checks.
    /// @param receiver The address to receive the genesis mint amount.
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        address receiver
    ) ERC20("Puppet Test", "PUPPET-TEST") CoreContract("PuppetToken", "1", _authority, _eventEmitter) {
        _mint(receiver, GENESIS_MINT_AMOUNT);
    }

    /// @notice Returns the core share based on the last mint time.
    /// @return The core share.
    function getCoreShare() public view returns (uint) {
        return getCoreShare(lastMintTime);
    }

    /// @notice Returns the core share based on a specific time.
    /// @param _time The time to calculate the core share for.
    /// @return The core share.
    function getCoreShare(
        uint _time
    ) public view returns (uint) {
        uint _timeElapsed = _time - deployTimestamp;
        return Precision.toFactor(CORE_RELEASE_DURATION_DIVISOR, CORE_RELEASE_DURATION_DIVISOR + _timeElapsed);
    }

    /// @notice Returns the amount of core tokens that can be minted based on the last mint time.
    /// @param _lastMintTime The last mint time to calculate for.
    /// @return The mintable core amount.
    function getMintableCoreAmount(
        uint _lastMintTime
    ) public view returns (uint) {
        uint _totalMintedAmount = totalSupply() - mintedCoreAmount - GENESIS_MINT_AMOUNT;
        uint _maxMintableAmount = Precision.applyFactor(getCoreShare(_lastMintTime), _totalMintedAmount);

        if (_maxMintableAmount < mintedCoreAmount) revert Error.PuppetToken__CoreShareExceedsMining();

        return _maxMintableAmount - mintedCoreAmount;
    }

    /// @notice Returns the limit amount based on the current configuration.
    /// @return The limit amount.
    function getEmissionRateLimit() public view returns (uint) {
        return Precision.applyFactor(config.limitFactor, totalSupply());
    }

    /// @notice Mints new tokens with a governance-configured rate limit.
    /// @param _receiver The address to mint tokens to.
    /// @param _amount The amount of tokens to mint.
    function mint(address _receiver, uint _amount) external auth {
        uint _allowance = getEmissionRateLimit();
        uint _timeElapsed = block.timestamp - lastMintTime;
        uint _decayRate = _allowance * _timeElapsed / config.durationWindow;
        uint _nextEmissionRate = _decayRate > emissionRate ? _amount : emissionRate - _decayRate + _amount;

        // Enforce the mint rate limit based on total emitted tokens
        if (_nextEmissionRate > _allowance) {
            revert Error.PuppetToken__ExceededRateLimit(_allowance, _nextEmissionRate);
        }

        // Add the requested mint amount to the window's mint count
        emissionRate = _nextEmissionRate;
        lastMintTime = block.timestamp;
        _mint(_receiver, _amount);

        logEvent("Mint", abi.encode(msg.sender, _receiver, _allowance, _nextEmissionRate, _amount));
    }

    /// @notice Mints new tokens to the core with a time-based reduction release schedule.
    /// @param _receiver The address to mint tokens to.
    /// @return The amount of tokens minted.
    function mintCore(
        address _receiver
    ) external auth returns (uint) {
        uint _lastMintTime = lastMintTime;
        uint _mintableAmount = getMintableCoreAmount(_lastMintTime);

        mintedCoreAmount += _mintableAmount;
        _mint(_receiver, _mintableAmount);

        logEvent("MintCore", abi.encode(msg.sender, _receiver, mintedCoreAmount));

        return _mintableAmount;
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(
        Config calldata _config
    ) external auth {
        if (_config.limitFactor == 0) revert Error.PuppetToken__InvalidRate();

        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
