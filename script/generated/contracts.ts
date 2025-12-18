// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import accountAbi from './abi/puppetAccount.js'
import accountstoreAbi from './abi/puppetAccountStore.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import matchmakerrouterAbi from './abi/puppetMatchmakerRouter.js'
import matchmakerrouterproxyAbi from './abi/puppetMatchmakerRouterProxy.js'
import mirrorAbi from './abi/puppetMirror.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import settleAbi from './abi/puppetSettle.js'
import subscribeAbi from './abi/puppetSubscribe.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import userrouterAbi from './abi/puppetUserRouter.js'
import userrouterproxyAbi from './abi/puppetUserRouterProxy.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x686B8A9701659F623c28e0A7c5053D9a499EFfE8',
    chainId: 42161,
    abi: dictatorshipAbi
  },
  PuppetToken: {
    address: '0x3b1A496303b8272C6558b1E9159074F13176adc8',
    chainId: 42161,
    abi: puppettokenAbi
  },
  TokenRouter: {
    address: '0x50403a2A8bfFedFE685c9729670614401d5ADcC3',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  FeeMarketplaceStore: {
    address: '0xaF5798725AFA764748f9Dc85E8418510B459F722',
    chainId: 42161,
    abi: feemarketplacestoreAbi
  },
  FeeMarketplace: {
    address: '0x4d80C64A10e44c724203485A4349727e01A0BaDF',
    chainId: 42161,
    abi: feemarketplaceAbi
  },
  PuppetVoteToken: {
    address: '0x95718B4EEC9316E3a61ef75A2BBD3951cF465Bff',
    chainId: 42161,
    abi: puppetvotetokenAbi
  },
  UserRouterProxy: {
    address: '0xBf8F9dfBDcE977B2048D685E0d226b328e00400c',
    chainId: 42161,
    abi: userrouterproxyAbi
  },
  MatchmakerRouterProxy: {
    address: '0xA65a035B2EaA68b6670f098Aae6fAf7506AFcF9E',
    chainId: 42161,
    abi: matchmakerrouterproxyAbi
  },
  AccountStore: {
    address: '0x9c10EC021E503F8E1795a75604f8c0c4a2A8BcFC',
    chainId: 42161,
    abi: accountstoreAbi
  },
  Account: {
    address: '0xcA67b43Cb9C53d186Ca943A803e93A0A0b487A03',
    chainId: 42161,
    abi: accountAbi
  },
  Subscribe: {
    address: '0x58c1183775cAebAF64C0f930a68A9801Dc74AE26',
    chainId: 42161,
    abi: subscribeAbi
  },
  Mirror: {
    address: '0x3716923fFD18b729794B0bc9370F68ACA19E7E1b',
    chainId: 42161,
    abi: mirrorAbi
  },
  Settle: {
    address: '0x522ACc1d41AAfc4097b7DAC066ad6a146f04cB0F',
    chainId: 42161,
    abi: settleAbi
  },
  MatchmakerRouter: {
    address: '0xF44C71FaBEdDD30d0a606dceE6498D4eC4F69e6e',
    chainId: 42161,
    abi: matchmakerrouterAbi
  },
  UserRouter: {
    address: '0xcEdEA6C652bd757B2937eC36B9c8aCbf70CF2841',
    chainId: 42161,
    abi: userrouterAbi
  }
} as const
