// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {Account} from "./position/Account.sol";
import {Mirror} from "./position/Mirror.sol";
import {Rule} from "./position/Rule.sol";
import {FeeMarketplace} from "./shared/FeeMarketplace.sol";

/**
 * @title UserRouter
 * @notice Simple router for Puppet Protocol operations on Arbitrum
 * @dev Cross-chain deposits are handled entirely by Rhinestone SDK's intent system
 * @dev Users create intents via SDK which handles routing, bridging, and settlement
 */
contract UserRouter is ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    Account public immutable account;
    Rule public immutable rule;
    FeeMarketplace public immutable feeMarketplace;
    Mirror public immutable mirror;

    // Rhinestone settlement contract (set this to actual Rhinestone contract on Arbitrum)
    address public rhinestoneSettler;

    // Events
    event Deposit(address indexed user, IERC20 indexed token, uint amount);
    event Withdrawal(address indexed user, IERC20 indexed token, uint amount);
    event RuleSet(address indexed user, address indexed trader, Mirror indexed mirror);
    event RhinestoneSettlerUpdated(address indexed oldSettler, address indexed newSettler);

    modifier onlyRhinestoneOrDirect() {
        // Allow both Rhinestone settlement and direct calls
        // In production, implement proper authorization
        _;
    }

    constructor(Account _account, Rule _rule, FeeMarketplace _feeMarketplace, Mirror _mirror) {
        account = _account;
        rule = _rule;
        feeMarketplace = _feeMarketplace;
        mirror = _mirror;
    }

    // ============================================
    // Direct On-Chain Operations (Arbitrum only)
    // ============================================

    /**
     * @notice Standard deposit for Arbitrum users
     * @param token The token to deposit
     * @param amount The amount to deposit
     */
    function deposit(IERC20 token, uint amount) external payable nonReentrant {
        require(amount > 0, "UserRouter: Invalid amount");
        
        // Transfer tokens from user
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve and deposit to Account
        token.forceApprove(address(account), amount);
        account.deposit(token, address(this), msg.sender, amount);

        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw funds from Account
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(IERC20 token, uint amount) external nonReentrant {
        account.withdraw(token, msg.sender, msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount);
    }

    /**
     * @notice Set trading rules
     * @param _mirror The mirror contract
     * @param _collateralToken The collateral token
     * @param _trader The trader to follow
     * @param _ruleParams Rule parameters
     */
    function setRule(
        Mirror _mirror,
        IERC20 _collateralToken,
        address _trader,
        Rule.RuleParams calldata _ruleParams
    ) external {
        rule.setRule(_mirror, _collateralToken, msg.sender, _trader, _ruleParams);
        emit RuleSet(msg.sender, _trader, _mirror);
    }

    /**
     * @notice Accept marketplace offer
     * @param feeToken The fee token
     * @param receiver The fee receiver
     * @param purchaseAmount The purchase amount
     */
    function acceptOffer(IERC20 feeToken, address receiver, uint purchaseAmount) external nonReentrant {
        feeMarketplace.acceptOffer(feeToken, msg.sender, receiver, purchaseAmount);
    }

    // ============================================
    // Rhinestone Settlement Integration
    // ============================================

    /**
     * @notice Process cross-chain deposit settled by Rhinestone
     * @dev Called by Rhinestone after successful cross-chain settlement
     * @dev Rhinestone handles ALL complexity: routing, bridging, verification
     * @param user The user who initiated the deposit
     * @param token The token being deposited  
     * @param amount The amount being deposited
     */
    function processRhinestoneDeposit(
        address user,
        IERC20 token,
        uint amount
    ) external nonReentrant onlyRhinestoneOrDirect {
        require(amount > 0, "UserRouter: Invalid amount");
        require(user != address(0), "UserRouter: Invalid user");

        // Rhinestone should have already transferred tokens to this contract
        uint balance = token.balanceOf(address(this));
        require(balance >= amount, "UserRouter: Insufficient tokens");

        // Approve and deposit to Account
        token.forceApprove(address(account), amount);
        account.deposit(token, address(this), user, amount);

        emit Deposit(user, token, amount);
    }

    /**
     * @notice Process any Rhinestone action (deposit, withdraw, setRule, etc.)
     * @dev More flexible endpoint for Rhinestone to call with different actions
     * @param user The user initiating the action
     * @param action The action type (0=deposit, 1=withdraw, 2=setRule, 3=acceptOffer)
     * @param data Encoded parameters for the action
     */
    function processRhinestoneAction(
        address user,
        uint8 action,
        bytes calldata data
    ) external nonReentrant onlyRhinestoneOrDirect {
        if (action == 0) {
            // Deposit
            (IERC20 token, uint amount) = abi.decode(data, (IERC20, uint));
            
            token.forceApprove(address(account), amount);
            account.deposit(token, address(this), user, amount);
            
            emit Deposit(user, token, amount);
        } else if (action == 1) {
            // Withdraw
            (IERC20 token, uint amount) = abi.decode(data, (IERC20, uint));
            account.withdraw(token, user, user, amount);
            
            emit Withdrawal(user, token, amount);
        } else if (action == 2) {
            // Set Rule
            (Mirror _mirror, IERC20 _collateralToken, address _trader, Rule.RuleParams memory _ruleParams) =
                abi.decode(data, (Mirror, IERC20, address, Rule.RuleParams));
            
            rule.setRule(_mirror, _collateralToken, user, _trader, _ruleParams);
            emit RuleSet(user, _trader, _mirror);
        } else if (action == 3) {
            // Accept Offer
            (IERC20 feeToken, address receiver, uint purchaseAmount) = 
                abi.decode(data, (IERC20, address, uint));
            
            feeMarketplace.acceptOffer(feeToken, user, receiver, purchaseAmount);
        } else {
            revert("UserRouter: Invalid action");
        }
    }

    /**
     * @notice Update Rhinestone settler address
     * @dev Only owner/governance should be able to call this
     * @param _rhinestoneSettler The new Rhinestone settler address
     */
    function setRhinestoneSettler(address _rhinestoneSettler) external {
        // TODO: Add proper access control
        address oldSettler = rhinestoneSettler;
        rhinestoneSettler = _rhinestoneSettler;
        emit RhinestoneSettlerUpdated(oldSettler, _rhinestoneSettler);
    }
}