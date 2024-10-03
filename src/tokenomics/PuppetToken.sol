// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
    /// @notice Emitted when tokens are minted to the core.
    /// @param operator The address that triggered the minting.
    /// @param receiver The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    event Puppet__MintCore(address operator, address indexed receiver, uint amount);

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
    uint public mintedCoreAmount = 0;

    /// @notice The timestamp when the contract was deployed.
    uint public immutable deployTimestamp = block.timestamp;

    /// @notice The current configuration.
    Config public config;

    /// @notice Initializes the contract with authority, configuration, and initial receiver of
    /// genesis mint.
    /// @param _authority The authority contract for permission checks.
    /// @param _config The initial configuration for mint rate limit.
    /// @param receiver The address to receive the genesis mint amount.
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config,
        address receiver
    ) ERC20("Puppet Test", "PUPPET-TEST") CoreContract("PuppetToken", "1", _authority, _eventEmitter) {
        _setConfig(_config);
        _mint(receiver, GENESIS_MINT_AMOUNT);

        emissionRate = getLimitAmount();
    }

    /// @notice Returns the core share based on the last mint time.
    /// @return The core share.
    function getCoreShare() public view returns (uint) {
        return getCoreShare(lastMintTime);
    }

    /// @notice Returns the core share based on a specific time.
    /// @param _time The time to calculate the core share for.
    /// @return The core share.
    function getCoreShare(uint _time) public view returns (uint) {
        uint _timeElapsed = _time - deployTimestamp;
        return Precision.toFactor(CORE_RELEASE_DURATION_DIVISOR, CORE_RELEASE_DURATION_DIVISOR + _timeElapsed);
    }

    /// @notice Returns the amount of core tokens that can be minted based on the last mint time.
    /// @param _lastMintTime The last mint time to calculate for.
    /// @return The mintable core amount.
    function getMintableCoreAmount(uint _lastMintTime) public view returns (uint) {
        uint _totalMintedAmount = totalSupply() - mintedCoreAmount - GENESIS_MINT_AMOUNT;
        uint _maxMintableAmount = Precision.applyFactor(getCoreShare(_lastMintTime), _totalMintedAmount);

        if (_maxMintableAmount < mintedCoreAmount) revert Puppet__CoreShareExceedsMining();

        return _maxMintableAmount - mintedCoreAmount;
    }

    /// @notice Returns the limit amount based on the current configuration.
    /// @return The limit amount.
    function getLimitAmount() public view returns (uint) {
        return Precision.applyFactor(config.limitFactor, totalSupply());
    }

    /// @notice Mints new tokens with a governance-configured rate limit.
    /// @param _receiver The address to mint tokens to.
    /// @param _amount The amount of tokens to mint.
    /// @return The amount of tokens minted.
    function mint(address _receiver, uint _amount) external auth returns (uint) {
        uint _limitAmount = getLimitAmount();
        uint _timeElapsed = block.timestamp - lastMintTime;
        uint _durationWindow = config.durationWindow;
        uint _decayRate = _limitAmount * _timeElapsed / _durationWindow;

        emissionRate = _decayRate > emissionRate ? _amount : emissionRate - _decayRate + _amount;

        // Enforce the mint rate limit based on total emitted tokens
        if (emissionRate > _limitAmount) {
            revert Puppet__ExceededRateLimit(_limitAmount, emissionRate);
        }

        // Add the requested mint amount to the window's mint count
        _mint(_receiver, _amount);
        lastMintTime = block.timestamp;

        return _amount;
    }

    /// @notice Mints new tokens to the core with a time-based reduction release schedule.
    /// @param _receiver The address to mint tokens to.
    /// @return The amount of tokens minted.
    function mintCore(address _receiver) external auth returns (uint) {
        uint _lastMintTime = lastMintTime;
        uint _mintableAmount = getMintableCoreAmount(_lastMintTime);

        mintedCoreAmount += _mintableAmount;
        _mint(_receiver, _mintableAmount);

        emit Puppet__MintCore(msg.sender, _receiver, _mintableAmount);

        return _mintableAmount;
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        if (_config.limitFactor == 0) revert Puppet__InvalidRate();

        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }

    /// @dev Error for when the rate is invalid (zero).
    error Puppet__InvalidRate();

    /// @dev Error for when the minting exceeds the rate limit.
    /// @param rateLimit The rate limit.
    /// @param emissionRate The current emission rate.
    error Puppet__ExceededRateLimit(uint rateLimit, uint emissionRate);

    /// @dev Error for when the core share exceeds the mintable amount.
    error Puppet__CoreShareExceedsMining();
}
