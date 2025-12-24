// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import allocationAbi from './abi/puppetAllocation.js'
import allowanceratepolicyAbi from './abi/puppetAllowanceRatePolicy.js'
import allowedrecipientpolicyAbi from './abi/puppetAllowedRecipientPolicy.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import throttlepolicyAbi from './abi/puppetThrottlePolicy.js'
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
    address: '0x0000000000000000000000000000000000000001',
    chainId: 42161,
    abi: userrouterproxyAbi
  },
  UserRouter: {
    address: '0x0000000000000000000000000000000000000002',
    chainId: 42161,
    abi: userrouterAbi
  },
  PuppetModule: {
    address: '0x0000000000000000000000000000000000000003',
    chainId: 42161
  },
  Allocation: {
    address: '0x0000000000000000000000000000000000000004',
    chainId: 42161,
    abi: allocationAbi
  },
  AllowedRecipientPolicy: {
    address: '0x0000000000000000000000000000000000000005',
    chainId: 42161,
    abi: allowedrecipientpolicyAbi
  },
  AllowanceRatePolicy: {
    address: '0x0000000000000000000000000000000000000006',
    chainId: 42161,
    abi: allowanceratepolicyAbi
  },
  ThrottlePolicy: {
    address: '0x0000000000000000000000000000000000000007',
    chainId: 42161,
    abi: throttlepolicyAbi
  }
} as const
