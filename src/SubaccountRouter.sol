// // SPDX-License-Identifier: BUSL-1.1

// pragma solidity 0.8.23;

// import {MulticallRouter} from "./utils/MulticallRouter.sol";

// contract SubaccountRouter is MulticallRouter {
//     constructor(RewardRouterParams memory _params, RewardRouterConfigParams memory _config)
//         MulticallRouter(_params.dictator, _params.wnt, _params.router, _config.dao)
//     {
//         params = _params;
//         config = _config;
//     }

//     receive() external payable {
//         address wnt = TokenUtils.wnt(dataStore);
//         if (msg.sender != wnt) {
//             revert Errors.InvalidNativeTokenSender(msg.sender);
//         }
//     }

//     function addSubaccount(address subaccount) external payable nonReentrant {
//         address account = msg.sender;
//         SubaccountUtils.addSubaccount(dataStore, eventEmitter, account, subaccount);
//     }

//     function removeSubaccount(address subaccount) external payable nonReentrant {
//         address account = msg.sender;
//         SubaccountUtils.removeSubaccount(dataStore, eventEmitter, account, subaccount);
//     }

//     function setMaxAllowedSubaccountActionCount(address subaccount, bytes32 actionType, uint maxAllowedCount) external payable nonReentrant {
//         address account = msg.sender;

//         SubaccountUtils.setMaxAllowedSubaccountActionCount(dataStore, eventEmitter, account, subaccount, actionType, maxAllowedCount);
//     }

//     function setSubaccountAutoTopUpAmount(address subaccount, uint amount) external payable nonReentrant {
//         address account = msg.sender;

//         SubaccountUtils.setSubaccountAutoTopUpAmount(dataStore, eventEmitter, account, subaccount, amount);
//     }

//     function createOrder(address account, IBaseOrderUtils.CreateOrderParams calldata params) external payable nonReentrant returns (bytes32) {
//         uint startingGas = gasleft();

//         _handleSubaccountAction(account, Keys.SUBACCOUNT_ORDER_ACTION);

//         if (params.addresses.receiver != account) {
//             revert Errors.InvalidReceiverForSubaccountOrder(params.addresses.receiver, account);
//         }

//         if (
//             params.orderType == Order.OrderType.MarketSwap || params.orderType == Order.OrderType.LimitSwap
//                 || params.orderType == Order.OrderType.MarketIncrease || params.orderType == Order.OrderType.LimitIncrease
//         ) {
//             router.pluginTransfer(
//                 params.addresses.initialCollateralToken, // token
//                 account, // account
//                 address(orderVault), // receiver
//                 params.numbers.initialCollateralDeltaAmount // amount
//             );
//         }

//         bytes32 key = orderHandler.createOrder(account, params);

//         _autoTopUpSubaccount(
//             account, // account
//             msg.sender, // subaccount
//             startingGas, // startingGas
//             params.numbers.executionFee // executionFee
//         );

//         return key;
//     }

//     function updateOrder(bytes32 key, uint sizeDeltaUsd, uint acceptablePrice, uint triggerPrice, uint minOutputAmount)
//         external
//         payable
//         nonReentrant
//     {
//         uint startingGas = gasleft();

//         Order.Props memory order = OrderStoreUtils.get(dataStore, key);

//         if (order.account() == address(0)) revert Errors.EmptyOrder();

//         _handleSubaccountAction(order.account(), Keys.SUBACCOUNT_ORDER_ACTION);

//         orderHandler.updateOrder(key, sizeDeltaUsd, acceptablePrice, triggerPrice, minOutputAmount, order);

//         _autoTopUpSubaccount(
//             order.account(), // account
//             msg.sender, // subaccount
//             startingGas, // startingGas
//             0 // executionFee
//         );
//     }

//     function cancelOrder(bytes32 key) external payable nonReentrant {
//         uint startingGas = gasleft();

//         Order.Props memory order = OrderStoreUtils.get(dataStore, key);

//         if (order.account() == address(0)) revert Errors.EmptyOrder();

//         _handleSubaccountAction(order.account(), Keys.SUBACCOUNT_ORDER_ACTION);

//         orderHandler.cancelOrder(key);

//         _autoTopUpSubaccount(
//             order.account(), // account
//             msg.sender, // subaccount
//             startingGas, // startingGas
//             0 // executionFee
//         );
//     }

//     function _handleSubaccountAction(address account, bytes32 actionType) internal {
//         FeatureUtils.validateFeature(dataStore, Keys.subaccountFeatureDisabledKey(address(this)));

//         address subaccount = msg.sender;
//         SubaccountUtils.validateSubaccount(dataStore, account, subaccount);

//         SubaccountUtils.incrementSubaccountActionCount(dataStore, eventEmitter, account, subaccount, actionType);
//     }

//     // the subaccount is topped up with wrapped native tokens
//     // the subaccount should separately unwrap the token as needed
//     function _autoTopUpSubaccount(address account, address subaccount, uint startingGas, uint executionFee) internal {
//         uint amount = SubaccountUtils.getSubaccountAutoTopUpAmount(dataStore, account, subaccount);
//         if (amount == 0) {
//             return;
//         }

//         IERC20 wnt = IERC20(dataStore.getAddress(Keys.WNT));

//         if (wnt.allowance(account, address(router)) < amount) return;
//         if (wnt.balanceOf(account) < amount) return;

//         // cap the top up amount to the amount of native tokens used
//         uint nativeTokensUsed = (startingGas - gasleft()) * tx.gasprice + executionFee;
//         if (nativeTokensUsed < amount) amount = nativeTokensUsed;

//         router.pluginTransfer(
//             address(wnt), // token
//             account, // account
//             address(this), // receiver
//             amount // amount
//         );

//         TokenUtils.withdrawAndSendNativeToken(dataStore, address(wnt), subaccount, amount);

//         EventUtils.EventLogData memory eventData;

//         eventData.addressItems.initItems(2);
//         eventData.addressItems.setItem(0, "account", account);
//         eventData.addressItems.setItem(1, "subaccount", subaccount);

//         eventData.uintItems.initItems(1);
//         eventData.uintItems.setItem(0, "amount", amount);

//         eventEmitter.emitEventLog2("SubaccountAutoTopUp", Cast.toBytes32(account), Cast.toBytes32(subaccount), eventData);
//     }
// }
