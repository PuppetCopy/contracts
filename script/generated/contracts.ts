// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import allocationAbi from './abi/puppetAllocation.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import positionAbi from './abi/puppetPosition.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import throttlepolicyAbi from './abi/puppetThrottlePolicy.js'

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
    address: '0x0000000000000000000000000000000000000000',
    chainId: 42161,
    abi: allocationAbi
  },
  Position: {
    address: '0x0000000000000000000000000000000000000000',
    chainId: 42161,
    abi: positionAbi
  },
  ThrottlePolicy: {
    address: '0x0000000000000000000000000000000000000007',
    chainId: 42161,
    abi: throttlepolicyAbi
  }
} as const
