// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveTricryptoOptimizedWETH {
    // Events
    event Transfer(address indexed sender, address indexed receiver, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event TokenExchange(address indexed buyer, uint sold_id, uint tokens_sold, uint bought_id, uint tokens_bought, uint fee, uint packed_price_scale);
    event AddLiquidity(address indexed provider, uint[2] token_amounts, uint fee, uint token_supply, uint packed_price_scale);
    event RemoveLiquidity(address indexed provider, uint[2] token_amounts, uint token_supply);
    event RemoveLiquidityOne(address indexed provider, uint token_amount, uint coin_index, uint coin_amount, uint approx_fee, uint packed_price_scale);
    event CommitNewParameters(uint indexed deadline, uint mid_fee, uint out_fee, uint fee_gamma, uint allowed_extra_profit, uint adjustment_step, uint ma_time);
    event NewParameters(uint mid_fee, uint out_fee, uint fee_gamma, uint allowed_extra_profit, uint adjustment_step, uint ma_time);
    event RampAgamma(uint initial_A, uint future_A, uint initial_gamma, uint future_gamma, uint initial_time, uint future_time);
    event StopRampA(uint current_A, uint current_gamma, uint time);
    event ClaimAdminFee(address indexed admin, uint tokens);

    // External functions
    function exchange(uint i, uint j, uint dx, uint min_dy, bool use_eth, address receiver) external payable returns (uint);
    function exchange_underlying(uint i, uint j, uint dx, uint min_dy, address receiver) external payable returns (uint);
    function exchange_extended(uint i, uint j, uint dx, uint min_dy, bool use_eth, address sender, address receiver, bytes32 cb) external returns (uint);
    function add_liquidity(uint[2] calldata amounts, uint min_mint_amount, bool use_eth, address receiver) external payable returns (uint);
    function remove_liquidity(uint _amount, uint[2] calldata min_amounts, bool use_eth, address receiver, bool claim_admin_fees) external returns (uint[2] memory);
    function remove_liquidity_one_coin(uint token_amount, uint i, uint min_amount, bool use_eth, address receiver) external returns (uint);
    function claim_admin_fees() external;

    // View functions
    function fee_receiver() external view returns (address);
    function calc_token_amount(uint[2] calldata amounts, bool deposit) external view returns (uint);
    function get_dy(uint i, uint j, uint dx) external view returns (uint);
    function get_dx(uint i, uint j, uint dy) external view returns (uint);
    function lp_price() external view returns (uint);
    function get_virtual_price() external view returns (uint);
    function price_oracle(uint k) external view returns (uint);
    function last_prices(uint k) external view returns (uint);
    function price_scale(uint k) external view returns (uint);
    function fee() external view returns (uint);
    function calc_withdraw_one_coin(uint token_amount, uint i) external view returns (uint);
    function calc_token_fee(uint[2] calldata amounts, uint[2] calldata xp) external view returns (uint);
    function A() external view returns (uint);
    function gamma() external view returns (uint);
    function mid_fee() external view returns (uint);
    function out_fee() external view returns (uint);
    function fee_gamma() external view returns (uint);
    function allowed_extra_profit() external view returns (uint);
    function adjustment_step() external view returns (uint);
    function ma_time() external view returns (uint);
    function precisions() external view returns (uint[2] memory);
    function fee_calc(uint[2] calldata xp) external view returns (uint);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    // Admin functions
    function ramp_A_gamma(uint future_A, uint future_gamma, uint future_time) external;
    function stop_ramp_A_gamma() external;
    function commit_new_parameters(uint _new_mid_fee, uint _new_out_fee, uint _new_fee_gamma, uint _new_allowed_extra_profit, uint _new_adjustment_step, uint _new_ma_time) external;
    function apply_new_parameters() external;
    function revert_new_parameters() external;

    // ERC20-like functions
    function transfer(address _to, uint _value) external returns (bool);
    function transferFrom(address _from, address _to, uint _value) external returns (bool);
    function approve(address _spender, uint _value) external returns (bool);
    function increaseAllowance(address _spender, uint _add_value) external returns (bool);
    function decreaseAllowance(address _spender, uint _sub_value) external returns (bool);
    function permit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) external returns (bool);

    // ERC20-like view functions
    function balanceOf(address _owner) external view returns (uint);
    function allowance(address _owner, address _spender) external view returns (uint);
    function totalSupply() external view returns (uint);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // Additional view functions specific to Curve
    function coins(uint i) external view returns (address);
    function balances(uint i) external view returns (uint);
    function get_balances() external view returns (uint[2] memory);
    function get_current_balances() external view returns (uint[2] memory);
    function get_twap_balances(uint[2] memory _first_balances, uint[2] memory _last_balances, uint _time_elapsed) external view returns (uint[2] memory);
    function get_price_cumulative_last() external view returns (uint[2] memory);
    function admin_fee() external view returns (uint);
    function admin_actions_deadline() external view returns (uint);
    function transfer_ownership(address _new_owner) external;
    function accept_ownership() external;
}
