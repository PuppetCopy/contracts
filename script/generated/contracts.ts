// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import allocationAbi from './abi/puppetAllocation.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import gmxvenuevalidatorAbi from './abi/puppetGmxVenueValidator.js'
import positionAbi from './abi/puppetPosition.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import subscriptionpolicyAbi from './abi/puppetSubscriptionPolicy.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x2FE36B7fDC9546078EB13b9D946EAA6FfCda3e9B',
    chainId: 42161,
    abi: dictatorshipAbi
  },
  PuppetToken: {
    address: '0x3b1A496303b8272C6558b1E9159074F13176adc8',
    chainId: 42161,
    abi: puppettokenAbi
  },
  PuppetVoteToken: {
    address: '0x95718B4EEC9316E3a61ef75A2BBD3951cF465Bff',
    chainId: 42161,
    abi: puppetvotetokenAbi
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
  Allocation: {
    address: '0xb1293c11821a924C29abd72FE16C71ee9E18B76F',
    chainId: 42161,
    abi: allocationAbi
  },
  Position: {
    address: '0xb08328BE0F311Fb27f01BdFdBB7075677e87C4E4',
    chainId: 42161,
    abi: positionAbi
  },
  SubscriptionPolicy: {
    address: '0x9DB9575bF24e85957150dA2b3C4100c7576010AF',
    chainId: 42161,
    abi: subscriptionpolicyAbi
  },
  ThrottlePolicy: {
    address: '0x9951b027Cb58E04897348f576dc71248d3f890bb',
    chainId: 42161
  },
  GmxVenueValidator: {
    address: '0x354E5b839D23507BF60B36550e9dCf1d5A0070fD',
    chainId: 42161,
    abi: gmxvenuevalidatorAbi
  }
} as const
