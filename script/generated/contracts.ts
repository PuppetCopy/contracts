// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import accountAbi from './abi/puppetAccount.js'
import accountstoreAbi from './abi/puppetAccountStore.js'
import allocationAbi from './abi/puppetAllocation.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import rewarddistributorAbi from './abi/puppetRewardDistributor.js'
import subscribeAbi from './abi/puppetSubscribe.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'

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
  Allocation: {
    address: '0x0000000000000000000000000000000000000001',
    chainId: 42161,
    abi: allocationAbi
  },
  RewardDistributor: {
    address: '0x0000000000000000000000000000000000000002',
    chainId: 42161,
    abi: rewarddistributorAbi
  }
} as const
