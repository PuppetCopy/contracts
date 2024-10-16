// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library Address {
    address constant dao = 0x145E9Ee481Bb885A49E1fF4c1166222587D61916;

    // Puppet core
    address constant Dictator = 0x6474AF87CbF50cbdE88710b3DaF7247A22910AA1;
    address constant PuppetToken = 0x29e21E47E2a1C4128b789b1b49FEAB91dBD7A80A;
    address constant PuppetVoteToken = 0xFeDA7274a47e142170824A4AbC8CF6A38033A254;
    address constant Router = 0xFd5943807B3A9dB50DB8D0DAf4162E68f7139b2C;

    // Tokenomics
    address constant ContributeStore = 0xD8f35E3F2F58579d0AFC937913539c06932Ca13D;
    address constant VotingEscrowStore = 0x2A87123506E4459783A449f43224669d53B6EFB0;
    address constant RewardStore = 0x9e2Ba591081B10612E8Fdf868EC20c3472CC15CF;

    address constant VotingEscrowLogic = 0xA9233Fb481b6790199F39AE501B05d623Fa85A86;
    address constant ContributeLogic = 0x2C78298cd4a7A2312547c94D6F9AABBB8c709A95;
    address constant RewardLogic = 0xf560b1f2dE1eb62e93FBA01Ee13578AACB8Fcd52;
    address constant RewardRouter = 0x8192468Ab9852391734fA4862581Bb8D96168CE3;

    // Puppet
    address constant PuppetStore = 0xeA9D224D16E3a35a8EB78ada6BD8D157a5F22aC4;
    address constant PuppetRouter = 0x402bF957BfFa22936da3bb66809D1e6E841aa059;
    address constant PuppetLogic = 0xd58c8E29F36c2f082d0d6f6C3f07a6B7A519B86a;

    // Position
    address constant MirrorPositionStore = 0x5F5C9d9272b4Bae556e0F83BE2c488B6E77F03EC;
    address constant PositionRouter = 0xe24B30FB459656425c8215eDf555585fc6b1F711;
    address constant AllocationLogic = 0x3E0894BE6984Ff281e0dd142F3606734F7A9CE94;
    address constant RequestLogic = 0x4b2BBd178167D75d25807911ce5d8F9690a8DF5C;
    address constant ExecutionLogic = 0x4BCFCBE765Dd1836a4B6F402fB16724bEcECbC6a;
    address constant UnhandledCallbackLogic = 0xB5546C0292f6570981630CF758B5bc3846DeB996;

    // Liquidity Pools
    address constant BasePool = 0x19da41A2ccd0792b9b674777E72447903FE29074;

    // Periphery
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant nt = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant wnt = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    address constant gmxExchangeRouter = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8;
    address constant gmxRouter = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address constant gmxOracle = 0xa11B501c2dd83Acd29F6727570f2502FAaa617F2;
    address constant gmxDatastore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address constant gmxOrderHandler = 0x352f684ab9e97a6321a13CF03A61316B681D9fD2;
    address constant gmxOrderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant gmxEthUsdcMarket = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    bytes32 constant referralCode = 0x5055505045540000000000000000000000000000000000000000000000000000;
}
