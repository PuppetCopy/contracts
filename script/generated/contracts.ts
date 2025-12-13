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
    address: '0x9C10ec021E503f8E1795a75604f8c0c4A2A8BcfC',
    chainId: 42161,
    abi: accountstoreAbi
  },
  Account: {
    address: '0xCA67b43CB9c53d186CA943a803e93a0a0B487a03',
    chainId: 42161,
    abi: accountAbi
  },
  Subscribe: {
    address: '0x58c1183775CaebAf64c0f930A68a9801dC74AE26',
    chainId: 42161,
    abi: subscribeAbi
  },
  Mirror: {
    address: '0x3716923FFd18b729794B0bc9370f68acA19E7e1b',
    chainId: 42161,
    abi: mirrorAbi
  },
  Settle: {
    address: '0x522acC1d41AAFc4097b7daC066aD6A146F04cB0F',
    chainId: 42161,
    abi: settleAbi
  },
  MatchmakerRouter: {
    address: '0xF44c71fAbedDD30d0A606DCEE6498D4ec4f69E6e',
    chainId: 42161,
    abi: matchmakerrouterAbi
  },
  UserRouter: {
    address: '0xCEdEa6c652Bd757b2937eC36b9c8aCbf70cf2841',
    chainId: 42161,
    abi: userrouterAbi
  }
} as const
