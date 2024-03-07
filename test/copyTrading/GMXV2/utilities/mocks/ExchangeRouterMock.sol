// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OrderUtils, IGMXExchangeRouter} from "src/integrations/GMXV2/interfaces/IGMXExchangeRouter.sol";
import {RouterMock} from "./RouterMock.sol";

contract ExchangeRouterMock is IGMXExchangeRouter {
    uint private _pendingRequestKeySalt;

    RouterMock internal _router;

    constructor(RouterMock _routerMock) {
        _router = _routerMock;
    }

    function createOrder(OrderUtils.CreateOrderParams calldata) external payable override returns (bytes32 _requestKey) {
        _pendingRequestKeySalt += 1;
        _requestKey = keccak256(abi.encodePacked(_pendingRequestKeySalt));
    }

    function sendTokens(address _token, address _receiver, uint _amount) external payable override {
        _router.sendTokens(msg.sender, _token, _receiver, _amount);
    }

    function cancelOrder(bytes32 key) external payable override {}

    function claimFundingFees(address[] memory markets, address[] memory tokens, address receiver) external payable returns (uint[] memory) {}

    function claimAffiliateRewards(address[] memory markets, address[] memory tokens, address receiver)
        external
        payable
        override
        returns (uint[] memory _rewards)
    {
        if (markets.length != tokens.length) {
            revert("ExchangeRouterMock: INVALID_MARKET_TOKEN_LENGTH");
        }

        _rewards = new uint[](markets.length);

        for (uint i = 0; i < markets.length; i++) {
            IERC20Metadata token = IERC20Metadata(tokens[i]);
            uint reward = 10 ** token.decimals() * 100;
            _rewards[i] = reward;

            try token.transfer(receiver, reward) {} catch {}
        }
    }
}
