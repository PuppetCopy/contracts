// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Address {
    address constant dao = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;

    // Puppet core
    address constant Dictator = 0xECaC4151bF1d17eEC1e3b9bd3bc4a6f2e50E0AFA;
    address constant EventEmitter = 0x3E62bDfCB20e8253478fe79981d46514949D2cF0;
    address constant PuppetToken = 0x5FeCb50777A594149D3e4A96C48CD1c0032c9972;
    address constant PuppetVoteToken = 0x9e40F0fee198AD9A3b97275606336d923d7197d8;
    address constant Router = 0x039597eF5b22cC810676512aA23394c95119a312;

    // Tokenomics
    address constant ContributeStore = 0xD8f35E3F2F58579d0AFC937913539c06932Ca13D;
    address constant VotingEscrowStore = 0x2A87123506E4459783A449f43224669d53B6EFB0;
    address constant RewardStore = 0x9e2Ba591081B10612E8Fdf868EC20c3472CC15CF;

    address constant VotingEscrowLogic = 0xA9233Fb481b6790199F39AE501B05d623Fa85A86;
    address constant ContributeLogic = 0x2C78298cd4a7A2312547c94D6F9AABBB8c709A95;
    address constant RewardLogic = 0x41b93E8265a963089579A944B77d78BF37dBac42;

    address constant RewardRouter = 0x8192468Ab9852391734fA4862581Bb8D96168CE3;

    address constant BasePool = 0x19da41A2ccd0792b9b674777E72447903FE29074;

    address constant nt = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant wnt = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    address constant datastore = 0x75236b405F460245999F70bc06978AB2B4116920;

    address constant gmxExchangeRouter = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8;
    address constant gmxRouter = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address constant gmxOracle = 0xa11B501c2dd83Acd29F6727570f2502FAaa617F2;
    address constant gmxDatastore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant gmxOrderHandler = 0x352f684ab9e97a6321a13CF03A61316B681D9fD2;
    address constant gmxOrderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant gmxEthUsdcMarket = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    bytes32 constant referralCode = 0x5055505045540000000000000000000000000000000000000000000000000000;
}
