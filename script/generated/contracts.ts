// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import dictatorshipAbi from './abi/puppetDictatorship.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import matchAbi from './abi/puppetMatch.js'
import allocateAbi from './abi/puppetAllocate.js'
import positionAbi from './abi/puppetPosition.js'
import userrouterAbi from './abi/puppetUserRouter.js'
import masterhookAbi from './abi/puppetMasterHook.js'
import gmxstageAbi from './abi/puppetGmxStage.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x61719F8f2f7445c99C86d43278680F8a69246Db0',
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
  Match: {
    address: '0x6AD7dCD75EB97EaEc1D9e62C6Af7E8a49Ac1A8d4',
    chainId: 42161,
    abi: matchAbi
  },
  Allocate: {
    address: '0x3F74b37D931D71c01EC0BBa730aF2AACbb89F532',
    chainId: 42161,
    abi: allocateAbi
  },
  Position: {
    address: '0xC1EEE594624B613e30DA071F1Cd632179E6Bd1fa',
    chainId: 42161,
    abi: positionAbi
  },
  UserRouter: {
    address: '0x1CF68142f84599E6824CdF03C0B0672431E57534',
    chainId: 42161,
    abi: userrouterAbi
  },
  MasterHook: {
    address: '0x4587Ac86b519c3A08F5F030988917D330524A166',
    chainId: 42161,
    abi: masterhookAbi
  },
  GmxStage: {
    address: '0x6AD7dCD75EB97EaEc1D9e62C6Af7E8a49Ac1A8d4',
    chainId: 42161,
    abi: gmxstageAbi
  }
} as const
