// This file is auto-generated from Puppet deployments.toml and forge-artifacts
// Do not edit manually.

import dictatorshipAbi from './abi/puppetDictatorship.js'
import withdrawAbi from './abi/puppetWithdraw.js'
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
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import proxyuserrouterAbi from './abi/puppetProxyUserRouter.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x397CA6373D46a15510Ce3045d09b7cbB3Af68EAa',
    abi: dictatorshipAbi
  },
  Withdraw: {
    address: '0x4f87978d851D9D17B73D426A15A58CF9F064e16E',
    abi: withdrawAbi
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
    address: '0xE7eAB5469ebbE492469E723FF5DAe7Cb91c6D04e',
    chainId: 42161,
    blockNumber: 418295895,
    abi: matchAbi
  },
  Allocate: {
    address: '0x5d2D41305b33DFf126FCb9585f919c7f13d183dB',
    chainId: 42161,
    blockNumber: 418295899,
    abi: allocateAbi
  },
  Position: {
    address: '0x49F7e5F896ad4530eBedB1d4697Ffb5b31f34972',
    chainId: 42161,
    blockNumber: 418295891,
    abi: positionAbi
  },
  UserRouter: {
    address: '0x91DeC0891d3d5DF935790C6dc97c674f7f976994',
    chainId: 42161,
    blockNumber: 418295904,
    abi: userrouterAbi
  },
  UserRouterImpl: {
    address: '0x0B1ba8b68CF1282a7770DecB650511126DF5142B',
    chainId: 42161
  },
  MasterHook: {
    address: '0x0bf4f1740E9809b88c9B0317654EB80c35CEe33E',
    chainId: 42161,
    blockNumber: 418295886,
    abi: masterhookAbi
  },
  GmxStage: {
    address: '0xB5E7CC3eD87F4f517351D50C639Fe9aB22b1D2Eb',
    chainId: 42161,
    blockNumber: 418295909,
    abi: gmxstageAbi
  },
  TokenRouter: {
    address: '0x0c69DB327925cd9367E39B7CB773Fcf97005a02c',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  ProxyUserRouter: {
    address: '0x8ea4425d1f26f1c715AF4020427480af9Fef20fF',
    chainId: 42161,
    blockNumber: 418295882,
    abi: proxyuserrouterAbi
  }
} as const
