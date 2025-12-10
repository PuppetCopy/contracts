// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

library Const {
    address constant dao = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;
    address constant sequencer = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;

    // Liquidity Pools
    address constant BasePool = 0x19da41A2ccd0792b9b674777E72447903FE29074;

    // Periphery
    address constant wnt = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    // GMX V2 core contracts (Arbitrum)
    address constant gmxExchangeRouter = 0x1C3fa76e6E1088bCE750f23a5BFcffa1efEF6A41;
    address constant gmxOrderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant gmxRouter = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address constant gmxReader = 0x470fbC46bcC0f16532691Df360A07d8Bf5ee0789;
    address constant gmxOracle = 0xa11B501c2dd83Acd29F6727570f2502FAaa617F2;
    address constant gmxDataStore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant gmxOrderHandler = 0xe68CAAACdf6439628DFD2fe624847602991A31eB;
    address constant gmxOrderHandlerGassless = 0xfc9Bc118fdDb89FF6fF720840446D73478dE4153;
    address constant gmxLiquidationHandler = 0xdAb9bA9e3a301CCb353f18B4C8542BA2149E4010;
    address constant gmxAdlHandler = 0x9242FbED25700e82aE26ae319BCf68E9C508451c;
    address constant gmxEthUsdcMarket = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
    address constant chainlinkPriceFeedProvider = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;

    bytes32 constant referralCode = 0x5055505045540000000000000000000000000000000000000000000000000000;
}
