// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;


library Const {
    address constant dao = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;
    address constant orderflowHandler = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;

    // Liquidity Pools
    address constant BasePool = 0x19da41A2ccd0792b9b674777E72447903FE29074;

    // Periphery
    address constant wnt = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    address constant gmxExchangeRouter = 0x602b805EedddBbD9ddff44A7dcBD46cb07849685;
    address constant gmxOrderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant gmxRouter = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address constant gmxOracle = 0xa11B501c2dd83Acd29F6727570f2502FAaa617F2;
    address constant gmxDatastore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant gmxOrderHandler = 0xfc9Bc118fdDb89FF6fF720840446D73478dE4153;
    address constant gmxEthUsdcMarket = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    bytes32 constant referralCode = 0x5055505045540000000000000000000000000000000000000000000000000000;
}
